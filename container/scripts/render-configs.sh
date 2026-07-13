#!/bin/bash

# Convenience variables

if [[ -n "${MOVIM_UPLOAD_MAX_FILESIZE}" ]]; then
    # These variables must match.
    export PHP_UPLOAD_MAX_FILESIZE=${MOVIM_UPLOAD_MAX_FILESIZE}
    export PHP_POST_MAX_SIZE=${MOVIM_UPLOAD_MAX_FILESIZE}
    export NGINX_CLIENT_MAX_BODY_SIZE=${MOVIM_UPLOAD_MAX_FILESIZE}
fi

# Render php-fpm settings

FPM_POOL=$(find /etc/php -type d -name pool.d -not -path /etc/php/pool.d)
rm -f ${FPM_POOL}/*

install -d /etc/php/pool.d
envsubst < ${PHP_FPM_CONF_TEMPLATE} > /etc/php/pool.d/movim.conf
ln -s /etc/php/pool.d/movim.conf ${FPM_POOL}/movim.conf

# Render php settings

AVAILABLE_MODULES=$(find /etc/php -type d -name mods-available)

install -d /etc/php/conf.d
envsubst < ${PHP_CONF_TEMPLATE} > /etc/php/conf.d/movim.ini
ln -s /etc/php/conf.d/movim.ini ${AVAILABLE_MODULES}/movim.ini
phpenmod movim

# Render nginx configuration

if [[ -v TESTING_MODE ]]; then
    export CONTAINER_MODE=testing
else
    export CONTAINER_MODE=production
fi

SUBST_VARS='${CONTAINER_MODE},${NGINX_CLIENT_MAX_BODY_SIZE}'
envsubst "${SUBST_VARS}" < ${NGINX_CONF_TEMPLATE} > /etc/nginx/sites-available/default

# Render Movim .env file

if [[ -v TESTING_MODE ]]; then
    export DAEMON_URL=${DAEMON_URL:-https://127.0.0.1:8443/}
    export DAEMON_DEBUG=${DAEMON_DEBUG:-true}
    export DAEMON_VERBOSE=${DAEMON_VERBOSE:-true}
fi

if [[ ! -v DB_HOST ]]; then
    echo "The DB_HOST environment variable must be set." 1>&2
    exit 1
fi

if [[ ! -v DB_PASSWORD ]]; then
    echo "The DB_PASSWORD environment variable must be set." 1>&2
    exit 1
fi

if [[ ! -v DAEMON_URL ]]; then
    echo "The DAEMON_URL environment variable must be set." 1>&2
    exit 1
fi

cat <<EOF > /var/www/movim/.env
DB_DRIVER=${DB_DRIVER}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_DATABASE=${DB_DATABASE}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
DAEMON_URL=${DAEMON_URL}
DAEMON_DEBUG=${DAEMON_DEBUG}
DAEMON_VERBOSE=${DAEMON_VERBOSE}

DAEMON_PORT=8080
DAEMON_INTERFACE=127.0.0.1
EOF

chown www-data: /var/www/movim/.env
