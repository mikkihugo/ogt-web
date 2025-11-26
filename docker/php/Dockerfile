FROM php:8.1-fpm

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    libicu-dev \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libxslt-dev \
    libpng-dev \
    default-mysql-client \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    && docker-php-ext-install pdo_mysql intl zip exif opcache

RUN pecl install xdebug || true
RUN docker-php-ext-enable xdebug || true

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/html
