#!/bin/bash
set -euo pipefail

echo "Starting ogt-web (hyperconverged: MariaDB + Redis + PHP-FPM + Caddy)..."

# 0. Start Redis (local only)
echo "Starting Redis..."
redis-server --daemonize yes --port 6379 --loglevel warning

# 1. Initialize MariaDB (unix socket only, no network exposure)
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo "Initializing MariaDB data directory..."
  mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

cat > /etc/my.cnf.d/runtime.cnf <<EOF
[mysqld]
skip-networking=ON
socket=/run/mysqld/mysqld.sock
bind-address=127.0.0.1
log_error=/dev/stderr
wsrep_on=OFF
EOF

echo "Starting MariaDB..."
mysqld_safe --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock &

echo "Waiting for MariaDB..."
for i in {1..60}; do
  if mysqladmin --socket=/run/mysqld/mysqld.sock ping --silent; then
    echo "MariaDB is up!"
    break
  fi
  sleep 2
done

# 2. Magento setup (idempotent)
echo "Checking Magento database..."
sleep 2

DB_NAME=${DB_NAME:-magento}
DB_USER=${DB_USER:-magento}
DB_PASSWORD=${DB_PASSWORD:-magento}
EXPORTER_PASSWORD=${EXPORTER_PASSWORD:-exporterpass}

mysql --socket=/run/mysqld/mysqld.sock -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
mysql --socket=/run/mysqld/mysqld.sock -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
mysql --socket=/run/mysqld/mysqld.sock -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql --socket=/run/mysqld/mysqld.sock -e "CREATE USER IF NOT EXISTS 'exporter'@'localhost' IDENTIFIED BY '${EXPORTER_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;"
mysql --socket=/run/mysqld/mysqld.sock -e "GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';"
mysql --socket=/run/mysqld/mysqld.sock -e "FLUSH PRIVILEGES;"

cat > /etc/.mysqld_exporter.cnf <<EOF
[client]
user=exporter
password=${EXPORTER_PASSWORD}
socket=/run/mysqld/mysqld.sock
EOF

if [ ! -f "/var/www/html/app/etc/env.php" ]; then
  echo "Installing Magento (one-time bootstrap)..."
  ADMIN_USER=${ADMIN_USER:-}
  ADMIN_PASSWORD=${ADMIN_PASSWORD:-}
  ADMIN_EMAIL=${ADMIN_EMAIL:-}

  if [ -z "${ADMIN_USER}" ] || [ "${ADMIN_USER}" = "admin" ]; then
    echo "ADMIN_USER must be set to a non-default value (export ADMIN_USER)." >&2
    exit 1
  fi
  if [ -z "${ADMIN_PASSWORD}" ] || [ "${ADMIN_PASSWORD}" = "Admin123!" ]; then
    echo "ADMIN_PASSWORD must be set to a strong value (export ADMIN_PASSWORD)." >&2
    exit 1
  fi
  if [ -z "${ADMIN_EMAIL}" ]; then
    echo "ADMIN_EMAIL must be set (export ADMIN_EMAIL)." >&2
    exit 1
  fi

  cd /var/www/html && bin/magento setup:install \
    --base-url=${MAGENTO_BASE_URL:-http://localhost:8080/} \
    --db-host=localhost \
    --db-name=${DB_NAME} \
    --db-user=${DB_USER} \
    --db-password=${DB_PASSWORD} \
    --admin-firstname=${ADMIN_FIRSTNAME:-Admin} \
    --admin-lastname=${ADMIN_LASTNAME:-User} \
    --admin-email=${ADMIN_EMAIL} \
    --admin-user=${ADMIN_USER} \
    --admin-password=${ADMIN_PASSWORD} \
    --session-save=redis \
    --session-save-redis-host=localhost \
    --session-save-redis-port=6379 \
    --cache-backend=redis \
    --cache-backend-redis-server=localhost \
    --cache-backend-redis-port=6379 \
    --language=en_US --currency=USD --timezone=UTC --use-rewrites=1
fi

# 3. Telemetry exporters
echo "Starting Prometheus exporters..."
mysqld_exporter --config.my-cnf /etc/.mysqld_exporter.cnf --web.listen-address=":9104" &
redis_exporter --redis.addr localhost:6379 --web.listen-address=":9121" &
php-fpm_exporter server --phpfpm.scrape-uri unix:///run/php-fpm.sock --web.listen-address=":9253" &

# 4. Web tier: PHP-FPM + Caddy (FastCGI)
echo "Starting PHP-FPM..."
mkdir -p /run/php-fpm
php-fpm -D

echo "Starting Caddy..."
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
