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
COPY ./container/s6-overlay/s6-rc.d/tail-log/ /etc/s6-overlay/s6-rc.d/tail-log/
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/movim-migrations
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/movim-daemon
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/php-fpm
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/nginx
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/tail-log

# Webserver configuration

COPY ./container/nginx/movim.conf /etc/nginx/sites-available/movim
COPY ./container/nginx/mode/production.conf /etc/nginx/snippets/production.conf
COPY ./container/nginx/mode/testing.conf /etc/nginx/snippets/testing.conf

# Unprivileged configuration

RUN usermod -a -G ssl-cert www-data \
    && chown -R www-data: /var/log/nginx /etc/nginx \
    && sed -i '/user www-data;/d' /etc/nginx/nginx.conf \
    && sed -i 's,/run/nginx.pid,/tmp/nginx.pid,' /etc/nginx/nginx.conf \
    && sed -i '/^http {/a \
        proxy_temp_path /tmp/proxy_temp;\n \
        client_body_temp_path /tmp/client_temp;\n \
        fastcgi_temp_path /tmp/fastcgi_temp;\n \
        uwsgi_temp_path /tmp/uwsgi_temp;\n \
        scgi_temp_path /tmp/scgi_temp;\n \
    ' /etc/nginx/nginx.conf \
    && FPM_CONF=$(find /etc/php -type f -name php-fpm.conf) \
    && sed -i 's,error_log = .*,error_log = /proc/self/fd/2,' ${FPM_CONF}

# PHP configuration

COPY ./container/movim-fpm.conf /etc/php/pool.d/movim.conf
RUN FPM_POOL=$(find /etc/php -type d -name pool.d -not -path /etc/php/pool.d) \
    && rm -f ${FPM_POOL}/* \
    && ln -s /etc/php/pool.d/movim.conf ${FPM_POOL}/movim.conf

COPY ./container/movim.ini /etc/php/conf.d/movim.ini
RUN AVAILABLE_MODULES=$(find /etc/php -type d -name mods-available) \
    && ln -s /etc/php/conf.d/movim.ini ${AVAILABLE_MODULES}/movim.ini \
    && phpenmod movim

RUN ln -s $(find /usr/sbin -name "php-fpm*") /usr/bin/php-fpm

# Movim configuration

ENV DAEMON_DEBUG=false \
    DAEMON_VERBOSE=false \
    DB_PORT=5432 \
    DB_DRIVER=pgsql \
    DB_DATABASE=movim \
    DB_USERNAME=movim

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
 /var/cache/picture_proxy

# Run s6 as unprivileged user

USER www-data
