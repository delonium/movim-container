#!/bin/bash

if (( CHOWN_DATA == 1 )); then
    DATA_DIRS="log cache public/cache public/images public/emojis"

    for DATA_DIR in ${DATA_DIRS}; do
        if [[ "$(stat -c %u /var/www/movim/${DATA_DIR})" != "$(id -u www-data)" ]]; then
            echo Changing ownership for data directory: ${DATA_DIR}
            chown -R www-data: /var/www/movim/${DATA_DIR}
        fi
    done
fi
