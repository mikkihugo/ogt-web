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
    zip \
    mariadb \
    mariadb-client \
    mariadb-ctl

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

# Copy static frontend site (optional, maybe as a subfolder or replacement?)
# User asked for "opensource" (Magento), so we prioritize Magento.
# We can put momento2-site in pub/momento2 for reference/access
COPY momento2-site /var/www/html/magento2/pub/momento2

# Set proper permissions
RUN chown -R www:www /var/www/html/magento2

FROM base AS final

# Copy built site from build stage
COPY --from=build --chown=www:www /var/www/html/magento2 /var/www/html

# Expose port 8080 (Fly.io standard)
EXPOSE 8080

# Update Nginx to listen on 8080
RUN sed -i 's/listen 80/listen 8080/g' /etc/nginx/http.d/default.conf

# Create start script
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'set -e' >> /start.sh && \
    echo '# Initialize MariaDB if not present' >> /start.sh && \
    echo 'if [ ! -d "/var/lib/mysql/mysql" ]; then' >> /start.sh && \
    echo '  echo "Initializing MariaDB..."' >> /start.sh && \
    echo '  mysql_install_db --user=mysql --datadir=/var/lib/mysql' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '# Start MariaDB in background' >> /start.sh && \
    echo 'mysqld_safe --datadir=/var/lib/mysql &' >> /start.sh && \
    echo 'echo "Waiting for MariaDB to start..."' >> /start.sh && \
    echo 'sleep 10' >> /start.sh && \
    echo '# Create DB and User if needed' >> /start.sh && \
    echo 'mysql -e "CREATE DATABASE IF NOT EXISTS magento;"' >> /start.sh && \
    echo 'mysql -e "CREATE USER IF NOT EXISTS \`magento\`@\`localhost\` IDENTIFIED BY \"magento\";"' >> /start.sh && \
    echo 'mysql -e "GRANT ALL PRIVILEGES ON magento.* TO \`magento\`@\`localhost\`;"' >> /start.sh && \
    echo 'mysql -e "FLUSH PRIVILEGES;"' >> /start.sh && \
    echo '# Install Magento if env.php is missing' >> /start.sh && \
    echo 'if [ ! -f "/var/www/html/app/etc/env.php" ]; then' >> /start.sh && \
    echo '  echo "Installing Magento..."' >> /start.sh && \
    echo '  cd /var/www/html && bin/magento setup:install \' >> /start.sh && \
    echo '    --base-url=${MAGENTO_BASE_URL:-http://localhost:8080/} \' >> /start.sh && \
    echo '    --db-host=localhost \' >> /start.sh && \
    echo '    --db-name=magento \' >> /start.sh && \
    echo '    --db-user=magento \' >> /start.sh && \
    echo '    --db-password=magento \' >> /start.sh && \
    echo '    --admin-firstname=${ADMIN_FIRSTNAME:-Admin} \' >> /start.sh && \
    echo '    --admin-lastname=${ADMIN_LASTNAME:-User} \' >> /start.sh && \
    echo '    --admin-email=${ADMIN_EMAIL:-admin@example.com} \' >> /start.sh && \
    echo '    --admin-user=${ADMIN_USER:-admin} \' >> /start.sh && \
    echo '    --admin-password=${ADMIN_PASSWORD:-Admin123!} \' >> /start.sh && \
    echo '    --language=en_US --currency=USD --timezone=UTC --use-rewrites=1' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'php-fpm -D' >> /start.sh && \
    echo 'nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]
