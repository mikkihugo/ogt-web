# Multi-stage Dockerfile for Magento 2 on Fly.io
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
    caddy

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

# Set working directory
WORKDIR /var/www/html

# PHP-FPM listens on unix socket for Caddy fastcgi
RUN echo "clear_env = no" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "pm.status_path = /status" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "access.log = /dev/stdout" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "error_log = /dev/stderr" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "listen = /run/php-fpm.sock" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "listen.owner = www-data" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "listen.group = www-data" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "listen.mode = 0660" >> /usr/local/etc/php-fpm.d/www.conf

FROM base AS build

ARG COMPOSER_MAGENTO_USERNAME
ARG COMPOSER_MAGENTO_PASSWORD

# Configure composer auth
RUN composer config --global http-basic.repo.magento.com \
    "${COMPOSER_MAGENTO_USERNAME}" "${COMPOSER_MAGENTO_PASSWORD}"

# Install Magento Open Source
RUN composer create-project --repository-url=https://repo.magento.com/ \
    magento/project-community-edition /var/www/html/magento2

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

# Copy start script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
