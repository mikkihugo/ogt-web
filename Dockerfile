# Multi-stage Dockerfile for Magento 2 on Fly.io
# Build cache buster: 2025-11-30-v10-routes-fix
FROM php:8.3-fpm-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    icu-dev \
    libxml2-dev \
    libxslt-dev \
    libzip-dev \
    oniguruma-dev \
    openssh-client \
    rsync \
    socat \
    bind-tools \
    procps \
    mariadb \
    mariadb-client \
    unzip \
    zip \
    wget \
    redis \
    caddy \
    supervisor

# Create required users and groups for supervisord services
RUN addgroup -S caddy 2>/dev/null || true && \
    adduser -S -G caddy caddy 2>/dev/null || true && \
    addgroup -S redis 2>/dev/null || true && \
    adduser -S -G redis redis 2>/dev/null || true

# Install build dependencies for PHP extensions
RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    gcc \
    g++ \
    make \
    linux-headers

# Install PHP extensions required by Magento
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    bcmath \
    ftp \
    gd \
    intl \
    mbstring \
    pdo_mysql \
    soap \
    sockets \
    xsl \
    zip \
    && pecl install redis && docker-php-ext-enable redis \
    && apk del .build-deps

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy PHP configuration for Magento (memory_limit = 2G, etc.)
COPY docker/php/magento.ini /usr/local/etc/php/conf.d/99-magento.ini

# Set working directory
WORKDIR /var/www/html

# PHP-FPM listens on TCP 127.0.0.1:9000 (default) for Caddy fastcgi
# Note: error_log is a global directive, not pool-specific, so we don't set it here
RUN echo "clear_env = no" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "pm.status_path = /status" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "access.log = /dev/stdout" >> /usr/local/etc/php-fpm.d/www.conf

FROM base AS build

ARG COMPOSER_MAGENTO_USERNAME
ARG COMPOSER_MAGENTO_PASSWORD

# Configure composer auth
RUN composer config --global http-basic.repo.magento.com \
    "${COMPOSER_MAGENTO_USERNAME}" "${COMPOSER_MAGENTO_PASSWORD}"

# Install Magento Open Source with retry logic for transient network errors
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN for i in 1 2 3 4 5; do \
      echo "Attempt $i: Installing Magento..."; \
      composer create-project --repository-url=https://repo.magento.com/ \
        magento/project-community-edition /var/www/html/magento2 \
        && break || { rm -rf /var/www/html/magento2; sleep 30; }; \
    done \
    && ls -la /var/www/html/magento2/ \
    && test -f /var/www/html/magento2/bin/magento || (echo "ERROR: Magento bin/magento missing after 5 attempts!" && exit 1)

WORKDIR /var/www/html/magento2

# Copy custom theme and modules
COPY magento-theme /tmp/magento-theme

# Install Theme
RUN mkdir -p app/design/frontend/Msgnet/msgnet2 \
    && cp -r /tmp/magento-theme/* app/design/frontend/Msgnet/msgnet2/ \
    && rm -rf app/design/frontend/Msgnet/msgnet2/Klarna_Checkout \
    && rm -rf app/design/frontend/Msgnet/msgnet2/Stripe_Checkout

# Install Modules
RUN mkdir -p app/code/Klarna/Checkout \
    && cp -r /tmp/magento-theme/Klarna_Checkout/* app/code/Klarna/Checkout/

RUN mkdir -p app/code/Stripe/Checkout \
    && cp -r /tmp/magento-theme/Stripe_Checkout/* app/code/Stripe/Checkout/

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html/magento2

FROM base AS final

# Copy built site from build stage
COPY --from=build --chown=www-data:www-data /var/www/html/magento2 /var/www/html

# Install OpenSearch (required for Magento 2.4+ catalog search)
# Using OpenSearch 2.x which is compatible with Magento 2.4.6+
RUN apk add --no-cache openjdk17-jre-headless && \
    mkdir -p /opt/opensearch && \
    curl -fsSL -o /tmp/opensearch.tar.gz \
      https://artifacts.opensearch.org/releases/bundle/opensearch/2.11.1/opensearch-2.11.1-linux-x64.tar.gz && \
    tar -xzf /tmp/opensearch.tar.gz --strip-components=1 -C /opt/opensearch && \
    rm -f /tmp/opensearch.tar.gz && \
    adduser -D -h /opt/opensearch opensearch && \
    chown -R opensearch:opensearch /opt/opensearch && \
    mkdir -p /var/lib/opensearch /var/log/opensearch && \
    chown -R opensearch:opensearch /var/lib/opensearch /var/log/opensearch

# Remove bundled JDK (glibc-based, incompatible with Alpine musl) and symlink to Alpine's OpenJDK
# The opensearch-env script checks for /opt/opensearch/jdk first, so we create a symlink
RUN rm -rf /opt/opensearch/jdk && \
    ln -s /usr/lib/jvm/java-17-openjdk /opt/opensearch/jdk

# Set OPENSEARCH_JAVA_HOME and JAVA_HOME to use Alpine's OpenJDK
ENV OPENSEARCH_JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk

# Configure OpenSearch for single-node, low-memory operation
# OpenSearch config - data path will be updated at runtime to persistent storage
RUN echo "discovery.type: single-node" >> /opt/opensearch/config/opensearch.yml && \
    echo "plugins.security.disabled: true" >> /opt/opensearch/config/opensearch.yml && \
    echo "network.host: 127.0.0.1" >> /opt/opensearch/config/opensearch.yml && \
    echo "http.port: 9200" >> /opt/opensearch/config/opensearch.yml && \
    echo "path.data: /var/lib/mysql/opensearch" >> /opt/opensearch/config/opensearch.yml && \
    echo "path.logs: /var/log/opensearch" >> /opt/opensearch/config/opensearch.yml

# Set OpenSearch JVM heap to 512MB (low memory mode)
RUN sed -i 's/-Xms1g/-Xms512m/' /opt/opensearch/config/jvm.options && \
    sed -i 's/-Xmx1g/-Xmx512m/' /opt/opensearch/config/jvm.options

# Install Prometheus exporters with correct versions
RUN curl -fsSL -o /tmp/php-fpm_exporter.tar.gz \
      https://github.com/hipages/php-fpm_exporter/releases/download/v2.2.0/php-fpm_exporter_2.2.0_linux_amd64.tar.gz && \
    tar -xzf /tmp/php-fpm_exporter.tar.gz -C /usr/local/bin/ php-fpm_exporter && \
    curl -fsSL -o /tmp/mysqld_exporter.tar.gz \
      https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.1/mysqld_exporter-0.15.1.linux-amd64.tar.gz && \
    tar -xzf /tmp/mysqld_exporter.tar.gz --strip-components=1 -C /usr/local/bin/ mysqld_exporter-0.15.1.linux-amd64/mysqld_exporter && \
    curl -fsSL -o /tmp/redis_exporter.tar.gz \
      https://github.com/oliver006/redis_exporter/releases/download/v1.54.0/redis_exporter-v1.54.0.linux-amd64.tar.gz && \
    tar -xzf /tmp/redis_exporter.tar.gz --strip-components=1 -C /usr/local/bin/ redis_exporter-v1.54.0.linux-amd64/redis_exporter && \
    chmod +x /usr/local/bin/*_exporter && \
    rm -f /tmp/*.tar.gz

# Expose port 8080 (Fly.io standard)
EXPOSE 8080

# Copy MySQL runtime configuration
COPY docker/mariadb/galera.cnf /etc/my.cnf.d/galera.cnf

# Copy Caddy configuration
COPY docker/caddy /etc/caddy

# Copy supervisord configuration
COPY docker/supervisord.conf /etc/supervisord.conf

# Create directories required by services
RUN mkdir -p /run/php-fpm /run/mysqld && \
    chown www-data:www-data /run/php-fpm && \
    chown mysql:mysql /run/mysqld

# Copy start script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
