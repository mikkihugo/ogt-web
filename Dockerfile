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
    mariadb-client \
    unzip \
    zip \
    wget \
    redis

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

# Install Traefik
RUN wget -qO- https://github.com/traefik/traefik/releases/download/v3.0.0/traefik_v3.0.0_linux_amd64.tar.gz | tar -xz -C /usr/local/bin/ traefik && \
    chmod +x /usr/local/bin/traefik

# Copy Traefik configuration
COPY docker/traefik/ /etc/traefik/

# Copy PHP-FPM configuration
RUN echo "clear_env = no" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "pm.status_path = /status" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "access.log = /dev/stdout" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "error_log = /dev/stderr" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "listen = 127.0.0.1:9000" >> /usr/local/etc/php-fpm.d/www.conf

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

# Install Prometheus exporters
RUN wget -qO /tmp/php-fpm_exporter.tar.gz https://github.com/hipages/php-fpm_exporter/releases/download/v1.2.0/php-fpm_exporter_1.2.0_linux_amd64.tar.gz && \
    tar -xzf /tmp/php-fpm_exporter.tar.gz -C /usr/local/bin/ php-fpm_exporter && \
    wget -qO /tmp/mysqld_exporter.tar.gz https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.1/mysqld_exporter-0.15.1.linux-amd64.tar.gz && \
    tar -xzf /tmp/mysqld_exporter.tar.gz --strip-components=1 -C /usr/local/bin/ && \
    wget -qO /tmp/redis_exporter.tar.gz https://github.com/oliver006/redis_exporter/releases/download/v1.54.0/redis_exporter-v1.54.0.linux-amd64.tar.gz && \
    tar -xzf /tmp/redis_exporter.tar.gz --strip-components=1 -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/php-fpm_exporter /usr/local/bin/mysqld_exporter /usr/local/bin/redis_exporter && \
    rm -f /tmp/*.tar.gz

# Expose port 8080 (Fly.io standard)
EXPOSE 8080

# Copy Galera configuration
COPY docker/mariadb/galera.cnf /etc/my.cnf.d/galera.cnf

# Copy start script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
