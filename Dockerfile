# main image
FROM php:8.3-fpm

# installing main dependencies
RUN apt-get update && apt-get install -y \
    git \
    ffmpeg \
    procps \
    default-mysql-client

# installing unzip dependencies
RUN apt-get install -y \
    libzip-dev \
    zlib1g-dev \
    unzip

# gd extension configure and install
RUN apt-get install -y \
    libfreetype6-dev \
    libicu-dev \
    libgmp-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && docker-php-ext-install gd

# imagick extension configure and install
RUN apt-get install -y libmagickwand-dev \
    && pecl install imagick \
    && docker-php-ext-enable imagick

# intl extension configure and install
RUN docker-php-ext-configure intl && docker-php-ext-install intl

# other extensions install
RUN docker-php-ext-install bcmath calendar exif gmp mysqli pdo pdo_mysql zip

# installing composer
COPY --from=composer:2.7 /usr/bin/composer /usr/local/bin/composer

# installing node js
COPY --from=node:23 /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node:23 /usr/local/bin/node /usr/local/bin/node
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

# installing global node dependencies
RUN npm install -g npx
RUN npm install -g laravel-echo-server

# arguments
ARG container_project_path

# copy php-fpm pool configuration
COPY ./.configs/nginx/pools/www.cnf /usr/local/etc/php-fpm.d/www.conf

# install bagisto directly into the image so compose platforms can boot it without host-side scripts
RUN mkdir -p ${container_project_path} && \
    git clone --branch v2.3.6 --depth 1 https://github.com/bagisto/bagisto.git ${container_project_path}bagisto

WORKDIR ${container_project_path}bagisto

RUN composer install --no-interaction --prefer-dist --optimize-autoloader

COPY ./.configs/.env ${container_project_path}bagisto/.env
COPY ./.configs/.env.testing ${container_project_path}bagisto/.env.testing
COPY ./docker/entrypoint.sh /usr/local/bin/bagisto-entrypoint.sh

RUN chmod +x /usr/local/bin/bagisto-entrypoint.sh && \
    mkdir -p /var/www/.composer && \
    chown -R www-data:www-data ${container_project_path} /var/www/.composer && \
    chmod -R 775 ${container_project_path}

ENTRYPOINT ["/usr/local/bin/bagisto-entrypoint.sh"]
CMD ["php-fpm"]
