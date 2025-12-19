FROM php:8.5-apache

ENV TTRSS_PHP_EXECUTABLE=/usr/local/bin/php
ENV TTRSS_PLUGINS="auth_internal, cache_starred_images"
ENV TTRSS_DAEMON_UPDATE_LOGIN_LIMIT=0
ENV TTRSS_DAEMON_UNSUCCESSFUL_DAYS_LIMIT=0
ENV TTRSS_SESSION_COOKIE_LIFETIME=2592000
ENV TZ=Europe/Berlin

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    libfreetype6-dev \
    libicu-dev \
    libjpeg-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libpq-dev \
    libwebp-dev \
    libxml2-dev \
    libxpm-dev \
    libzip-dev \
    && rm -rf /var/lib/apt/lists/*

# letsencrypt certs (required for planet.debianforum.de)
ADD https://letsencrypt.org/certs/2024/r12.pem /usr/local/share/ca-certificates/letsencryptR12.pem
ADD https://letsencrypt.org/certs/2024/r13.pem /usr/local/share/ca-certificates/letsencryptR13.pem
RUN openssl x509 -in /usr/local/share/ca-certificates/letsencryptR12.pem -inform PEM -out /usr/local/share/ca-certificates/letsencryptR12.crt \
    && openssl x509 -in /usr/local/share/ca-certificates/letsencryptR13.pem -inform PEM -out /usr/local/share/ca-certificates/letsencryptR13.crt \
    && update-ca-certificates

RUN docker-php-ext-configure gd --enable-gd --with-webp --with-jpeg --with-xpm --with-freetype \
    && docker-php-ext-install exif gd intl pcntl pgsql pdo_pgsql zip

RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
RUN echo 'date.timezone="Europe/Berlin"' > /usr/local/etc/php/conf.d/timezone.ini \
    && echo 'curl.cainfo="/etc/ssl/certs/ca-certificates.crt"' > /usr/local/etc/php/conf.d/curl_cainfo.ini

RUN apt-get update && apt-get install -y --no-install-recommends busybox-static
RUN mkdir -p /var/spool/cron/crontabs
RUN echo '*/5 * * * * php /var/www/html/update.php --feeds' > /var/spool/cron/crontabs/www-data
COPY cron.sh /
RUN chmod 755 /cron.sh

COPY ttrss/ /var/www/html/
RUN echo 'Require all denied' > /var/www/html/.git/.htaccess

RUN git clone https://github.com/tt-rss/tt-rss-plugin-googlereaderkeys.git /var/www/html/plugins.local/googlereaderkeys/

RUN mkdir /var/www/html/cache/feed-icons \
    /var/www/html/cache/starred-images \
    /var/www/html/cache/starred-images.status-files

RUN chown -R www-data:www-data /var/www/html/
RUN for d in cache lock feed-icons; do chmod -R u=rwX,g=rX,o=rX /var/www/html/$d; done

VOLUME /var/www/html/cache/feed-icons
