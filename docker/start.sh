#!/bin/bash
set -euo pipefail

echo "Starting ogt-web (hyperconverged: MariaDB + Redis + PHP-FPM + Caddy)..."

# 0. Start Redis (local only)
echo "Starting Redis..."
redis-server --daemonize yes --port 6379 --loglevel warning

# 1. Network & Cluster Discovery (Fly.io DNS)
# Even if Galera is disabled, we check DNS to ensure the environment is healthy
echo "Discovery: Checking Fly.io internal DNS..."
if [ -n "${FLY_APP_NAME:-}" ]; then
    MY_IP=$(hostname -i || echo "unknown")
    PEERS=$(dig +short AAAA "${FLY_APP_NAME}.internal" || echo "")
    PEER_COUNT=$(echo "$PEERS" | wc -w)
    echo "  > My IP: $MY_IP"
    echo "  > Peers found ($PEER_COUNT):" 
    echo "$PEERS" | sed 's/^/    - /'
else
    echo "  > Not running on Fly.io (FLY_APP_NAME unset)."
fi

# 2. Initialize MariaDB
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo "Initializing MariaDB data directory..."
  mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# Configuration: Prepare for future Clustering
# To enable Galera: set ENABLE_GALERA=true in fly.toml
ENABLE_GALERA=${ENABLE_GALERA:-false}

if [ "$ENABLE_GALERA" = "true" ]; then
    echo "Configuring MariaDB for Galera Cluster..."
    WSREP_ON="ON"
    SKIP_NETWORKING="OFF"
    BIND_ADDRESS="::"
    WSREP_PROVIDER="/usr/lib/libgalera_smm.so" # Path varies by distro
    # TODO: Add cluster address generation logic here
else
    echo "Configuring MariaDB as Standalone (Galera Disabled)..."
    WSREP_ON="OFF"
    SKIP_NETWORKING="ON"
    BIND_ADDRESS="127.0.0.1"
    WSREP_PROVIDER="none"
fi

cat > /etc/my.cnf.d/runtime.cnf <<EOF
[mysqld]
skip-networking=${SKIP_NETWORKING}
socket=/run/mysqld/mysqld.sock
bind-address=${BIND_ADDRESS}
log_error=/dev/stderr
wsrep_on=${WSREP_ON}
wsrep_provider=${WSREP_PROVIDER}
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

# Security: Require strong passwords, no defaults in production
if [ -z "${DB_PASSWORD:-}" ]; then
  echo "ERROR: DB_PASSWORD must be set (minimum 16 characters)" >&2
  exit 1
fi

if [ ${#DB_PASSWORD} -lt 16 ]; then
  echo "ERROR: DB_PASSWORD must be at least 16 characters long" >&2
  exit 1
fi

if [ "${DB_PASSWORD}" = "magento" ]; then
  echo "ERROR: DB_PASSWORD must not be the default value 'magento'" >&2
  exit 1
fi

if [ -z "${EXPORTER_PASSWORD:-}" ]; then
  echo "ERROR: EXPORTER_PASSWORD must be set (minimum 16 characters)" >&2
  exit 1
fi

if [ ${#EXPORTER_PASSWORD} -lt 16 ]; then
  echo "ERROR: EXPORTER_PASSWORD must be at least 16 characters long" >&2
  exit 1
fi

if [ "${EXPORTER_PASSWORD}" = "exporterpass" ]; then
  echo "ERROR: EXPORTER_PASSWORD must not be the default value 'exporterpass'" >&2
  exit 1
fi

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

# Security: Restrict permissions on MySQL exporter config (contains password)
chmod 600 /etc/.mysqld_exporter.cnf
chown nobody:nobody /etc/.mysqld_exporter.cnf

# Setup persistent web root in /var/lib/mysql/www (single volume hack)
# We must step out of /var/www/html (WORKDIR) before replacing it
cd /

PERSISTENT_WEB="/var/lib/mysql/www"

# Ensure parent dir is traversable by www-data
chmod 711 /var/lib/mysql

if [ ! -d "$PERSISTENT_WEB" ]; then
    echo "Creating persistent web root at $PERSISTENT_WEB..."
    mkdir -p "$PERSISTENT_WEB"
    chown www-data:www-data "$PERSISTENT_WEB"
fi

# Check if Magento is prebuilt in /var/www/html
if [ -f "/var/www/html/bin/magento" ] && [ ! -L "/var/www/html" ]; then
    echo "Magento prebuilt found. Copying to persistent storage..."
    if [ ! -f "$PERSISTENT_WEB/bin/magento" ]; then
        cp -r /var/www/html/* "$PERSISTENT_WEB/"
        chown -R www-data:www-data "$PERSISTENT_WEB"
    fi
fi

if [ ! -L "/var/www/html" ]; then
    echo "Symlinking /var/www/html to $PERSISTENT_WEB..."
    # Remove existing directory (empty or ephemeral)
    rm -rf /var/www/html
    ln -s "$PERSISTENT_WEB" /var/www/html
fi

# 3. Install Magento code if missing (Runtime Bootstrap)
if [ ! -f "/var/www/html/bin/magento" ]; then
  echo "Magento source not found. Installing via Composer..."
  
  mkdir -p /var/www/html
  cd /var/www/html

  # Configure auth
  if [ -n "${COMPOSER_MAGENTO_USERNAME:-}" ] && [ -n "${COMPOSER_MAGENTO_PASSWORD:-}" ]; then
      composer config --global http-basic.repo.magento.com \
          "${COMPOSER_MAGENTO_USERNAME}" "${COMPOSER_MAGENTO_PASSWORD}"
  else
      echo "ERROR: COMPOSER_MAGENTO_USERNAME/PASSWORD not set!"
      exit 1
  fi

  # Install Magento Open Source
  # Use --ignore-platform-reqs if needed, but we have PHP extensions installed via Nix
  composer create-project --repository-url=https://repo.magento.com/ \
      magento/project-community-edition .

  # Theme & Modules are now installed at build time in Nix
fi

if [ ! -f "/var/www/html/app/etc/env.php" ]; then
  echo "Installing Magento (one-time bootstrap)..."
  ADMIN_USER=${ADMIN_USER:-}
  ADMIN_PASSWORD=${ADMIN_PASSWORD:-}
  ADMIN_EMAIL=${ADMIN_EMAIL:-}

  # Security: Validate admin credentials
  if [ -z "${ADMIN_USER}" ]; then
    echo "ERROR: ADMIN_USER must be set (export ADMIN_USER)" >&2
    exit 1
  fi

  if [ "${ADMIN_USER}" = "admin" ]; then
    echo "ERROR: ADMIN_USER must not be the default value 'admin'" >&2
    exit 1
  fi

  if [ -z "${ADMIN_PASSWORD}" ]; then
    echo "ERROR: ADMIN_PASSWORD must be set (minimum 16 characters)" >&2
    exit 1
  fi

  if [ ${#ADMIN_PASSWORD} -lt 16 ]; then
    echo "ERROR: ADMIN_PASSWORD must be at least 16 characters long" >&2
    exit 1
  fi

  if [ "${ADMIN_PASSWORD}" = "Admin123!" ]; then
    echo "ERROR: ADMIN_PASSWORD must not be the default value 'Admin123!'" >&2
    exit 1
  fi

  # Basic email format validation
  if [ -z "${ADMIN_EMAIL}" ]; then
    echo "ERROR: ADMIN_EMAIL must be set (export ADMIN_EMAIL)" >&2
    exit 1
  fi

  if [[ ! "${ADMIN_EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "ERROR: ADMIN_EMAIL must be a valid email address" >&2
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

# 3. Stop bootstrap services
echo "Stopping bootstrap services..."
mysqladmin --socket=/run/mysqld/mysqld.sock shutdown
redis-cli shutdown

# 4. Handover to Supervisor
echo "Starting Supervisor..."
mkdir -p /run/php-fpm
exec supervisord -c /etc/supervisord.conf
