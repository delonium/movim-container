# Top-level build arguments

ARG BASE_IMAGE=docker.io/debian:trixie-slim
ARG S6_OVERLAY_VERSION=3.2.3.0

# Automatically set target architecture

ARG TARGETARCH

# Platform-independent s6-overlay stage

FROM ${BASE_IMAGE} AS movim-s6-noarch

ARG S6_OVERLAY_VERSION
ARG S6_OVERLAY_NOARCH_SHA256=b720f9d9340efc8bb07528b9743813c836e4b02f8693d90241f047998b4c53cf

RUN export DEBIAN_FRONTEND=noninteractive && \
 apt-get update && \
 apt-get install -y --no-install-recommends xz-utils

ADD --checksum=sha256:${S6_OVERLAY_NOARCH_SHA256} \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && rm -f /tmp/s6-overlay-noarch.tar.xz

# Set entrypoint for main build stage
ENTRYPOINT ["/init"]

# amd64 s6-overlay stage

FROM movim-s6-noarch AS movim-s6-amd64

ARG S6_OVERLAY_VERSION
ARG S6_OVERLAY_AMD64_SHA256=a93f02882c6ed46b21e7adb5c0add86154f01236c93cd82c7d682722e8840563

ADD --checksum=sha256:${S6_OVERLAY_AMD64_SHA256} \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz \
    && rm -f /tmp/s6-overlay-x86_64.tar.xz

# arm64 s6-overlay stage

FROM movim-s6-noarch AS movim-s6-arm64

ARG S6_OVERLAY_VERSION
ARG S6_OVERLAY_ARM64_SHA256=0952056ff913482163cc30e35b2e944b507ba1025d78f5becbb89367bf344581

ADD --checksum=sha256:${S6_OVERLAY_ARM64_SHA256} \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-aarch64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-aarch64.tar.xz \
    && rm -f /tmp/s6-overlay-aarch64.tar.xz

# Main build stage

FROM movim-s6-${TARGETARCH}

RUN export DEBIAN_FRONTEND=noninteractive \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
 composer \
 php \
 php-common \
 php-zip \
 php-curl \
 php-mbstring \
 php-imagick \
 php-gd \
 php-pgsql \
 php-xml \
 php-bcmath \
 php-fpm \
 nginx \
 gettext-base \
 ssl-cert \
 && apt-get autoremove -y \
 && apt-get clean

# s6

COPY ./container/s6-overlay/s6-rc.d/movim-migrations/ /etc/s6-overlay/s6-rc.d/movim-migrations/
COPY ./container/s6-overlay/s6-rc.d/movim-daemon/ /etc/s6-overlay/s6-rc.d/movim-daemon/
COPY ./container/s6-overlay/s6-rc.d/php-fpm/ /etc/s6-overlay/s6-rc.d/php-fpm/
COPY ./container/s6-overlay/s6-rc.d/nginx/ /etc/s6-overlay/s6-rc.d/nginx/
COPY ./container/s6-overlay/s6-rc.d/render-configs/ /etc/s6-overlay/s6-rc.d/render-configs/
COPY ./container/s6-overlay/s6-rc.d/chown-data/ /etc/s6-overlay/s6-rc.d/chown-data/
COPY ./container/s6-overlay/s6-rc.d/tail-log/ /etc/s6-overlay/s6-rc.d/tail-log/
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/movim-migrations
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/movim-daemon
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/php-fpm
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/nginx
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/render-configs
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/chown-data
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/tail-log

# Scripts

COPY --chmod=0500 ./container/scripts/render-configs.sh /bin/render-configs.sh
COPY --chmod=0500 ./container/scripts/chown-data.sh /bin/chown-data.sh

# Webserver configuration

ENV NGINX_CONF_TEMPLATE=/etc/templates/nginx/movim.conf
COPY ./container/nginx/movim.conf.template ${NGINX_CONF_TEMPLATE}

COPY ./container/nginx/mode/production.conf /etc/nginx/snippets/production.conf
COPY ./container/nginx/mode/testing.conf /etc/nginx/snippets/testing.conf

# PHP configuration

ENV PHP_FPM_CONF_TEMPLATE=/etc/templates/php/movim-fpm.conf
COPY ./container/php/movim-fpm.conf.template ${PHP_FPM_CONF_TEMPLATE}

ENV PHP_CONF_TEMPLATE=/etc/templates/php/movim.ini
COPY ./container/php/movim.ini.template ${PHP_CONF_TEMPLATE}

RUN ln -s $(find /usr/sbin -name "php-fpm*") /usr/bin/php-fpm

# Movim configuration

ENV DAEMON_DEBUG=false \
    DAEMON_VERBOSE=false \
    DB_PORT=5432 \
    DB_DRIVER=pgsql \
    DB_DATABASE=movim \
    DB_USERNAME=movim \
    CHOWN_DATA=1 \
    PHP_MEMORY_LIMIT=256M \
    PHP_UPLOAD_MAX_FILESIZE=100M \
    PHP_POST_MAX_SIZE=100M \
    PHP_OPCACHE_MEMORY=256 \
    NGINX_CLIENT_MAX_BODY_SIZE=100M \
    PHP_FPM_PM_MAX_CHILDREN=20 \
    PHP_FPM_PM_START_SERVERS=2 \
    PHP_FPM_PM_MIN_SPARE_SERVERS=1 \
    PHP_FPM_PM_MAX_SPARE_SERVERS=3 \
    PHP_FPM_PM_MAX_REQUESTS=500

# Movim files

WORKDIR /var/www/movim

ARG MOVIM_TAG
ADD --chown=www-data https://github.com/movim/movim.git#${MOVIM_TAG} .

RUN composer install

RUN install -o www-data -d \
 # Create local directories
 cache \
 log \
 public/cache \
 public/images \
 public/emojis \
 # Create picture proxy cache storage path
 /var/cache/picture_proxy \
 # Chown the working directory
 && chown -R www-data: .

# s6-overlay will drop privileges

USER root
