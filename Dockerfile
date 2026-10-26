FROM php:8.3-apache-bookworm

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public \
    COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /var/www/html

# A imagem base já fornece mbstring, SQLite e as extensões XML do PHPUnit.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libicu-dev \
        libzip-dev \
        unzip \
    && docker-php-ext-install -j"$(nproc)" intl mysqli zip \
    && pecl install pcov-1.0.12 \
    && docker-php-ext-enable pcov \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN a2enmod rewrite \
    && sed -ri "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" \
        /etc/apache2/sites-available/000-default.conf

# Mantém o cache das dependências quando apenas o código da aplicação muda.
COPY composer.json composer.lock ./
RUN composer install --no-interaction --prefer-dist --no-progress --no-autoloader --no-scripts

COPY docker/php/desenvolvimento.ini ${PHP_INI_DIR}/conf.d/zz-desenvolvimento.ini
COPY docker/php/ambiente.php ${PHP_INI_DIR}/ambiente.php
COPY . .

RUN composer dump-autoload --optimize --no-interaction \
    && composer check-platform-reqs \
    && mkdir -p build writable/cache writable/debugbar writable/logs writable/session writable/uploads \
    && chown -R www-data:www-data writable build \
    && chmod -R u+rwX writable build

EXPOSE 80

# Bash preserva os nomes com pontos usados nas configurações do CodeIgniter.
ENTRYPOINT ["/bin/bash", "/usr/local/bin/docker-php-entrypoint"]

CMD ["apache2-foreground"]
