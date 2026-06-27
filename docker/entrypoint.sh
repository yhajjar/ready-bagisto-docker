#!/bin/sh
set -eu

APP_DIR="/var/www/html/bagisto"
ENV_FILE="${APP_DIR}/.env"

if [ -f "${ENV_FILE}" ]; then
    set -a
    # shellcheck disable=SC1090
    . "${ENV_FILE}"
    set +a
fi

DB_HOST="${DB_HOST:-mysql}"
DB_PORT="${DB_PORT:-3306}"
DB_DATABASE="${DB_DATABASE:-bagisto}"
DB_USERNAME="${DB_USERNAME:-root}"
DB_PASSWORD="${DB_PASSWORD:-root}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-${DB_PASSWORD}}"

wait_for_mysql() {
    echo "Waiting for MySQL at ${DB_HOST}:${DB_PORT}..."
    until mysqladmin ping \
        -h"${DB_HOST}" \
        -P"${DB_PORT}" \
        -u"${DB_USERNAME}" \
        -p"${DB_PASSWORD}" \
        --skip-ssl \
        --silent >/dev/null 2>&1; do
        sleep 2
    done
}

create_database() {
    db_name="$1"
    mysql \
        -h"${DB_HOST}" \
        -P"${DB_PORT}" \
        -u root \
        -p"${MYSQL_ROOT_PASSWORD}" \
        --skip-ssl \
        -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
}

bagisto_installed() {
    table_count="$(mysql \
        -N -s \
        -h"${DB_HOST}" \
        -P"${DB_PORT}" \
        -u root \
        -p"${MYSQL_ROOT_PASSWORD}" \
        --skip-ssl \
        -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_DATABASE}' AND table_name='core_config';")"

    [ "${table_count}" != "0" ]
}

initialize_bagisto() {
    cd "${APP_DIR}"
    php artisan optimize:clear >/dev/null 2>&1 || true

    if bagisto_installed; then
        echo "Bagisto is already installed."
        return 0
    fi

    echo "Running first-time Bagisto install..."
    php artisan bagisto:install --skip-env-check --skip-admin-creation
    php artisan db:seed --class='Webkul\Installer\Database\Seeders\ProductTableSeeder'
}

if [ "${1:-}" = "php-fpm" ] || [ "${1:-}" = "php-fpm8.3" ]; then
    wait_for_mysql
    create_database "${DB_DATABASE}"
    create_database "bagisto_testing"
    initialize_bagisto
fi

exec docker-php-entrypoint "$@"
