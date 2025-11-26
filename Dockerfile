# Multi-stage Dockerfile for Magento 2 on Fly.io
FROM php:8.1-fpm-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    freetype-dev \
    git \
    icu-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libxml2-dev \
    libxslt-dev \
    libzip-dev \
    oniguruma-dev \
    openssh-client \
    rsync \
    unzip \
    zip

# Install PHP extensions required by Magento
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    bcmath \
    gd \
    intl \
    mbstring \
    pdo_mysql \
    soap \
    xsl \
    zip \
    sockets

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Install Nginx
RUN apk add --no-cache nginx

# Copy Nginx configuration
COPY docker/nginx/default.conf /etc/nginx/http.d/default.conf

# Copy PHP-FPM configuration
RUN echo "clear_env = no" >> /usr/local/etc/php-fpm.d/www.conf

# Create nginx user
RUN adduser -D -u 1000 -g 'www' www \
    && mkdir -p /var/www/html \
    && chown -R www:www /var/www/html

FROM base AS build

# Copy momento2 site (static site version for Fly.io)
COPY momento2-site /var/www/html/

# Set proper permissions
RUN chown -R www:www /var/www/html

FROM base AS final

# Copy built site from build stage
COPY --from=build --chown=www:www /var/www/html /var/www/html

# Expose port 8080 (Fly.io standard)
EXPOSE 8080

# Update Nginx to listen on 8080
RUN sed -i 's/listen 80/listen 8080/g' /etc/nginx/http.d/default.conf

# Create start script
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'php-fpm -D' >> /start.sh && \
    echo 'nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]
