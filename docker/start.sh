#!/bin/sh
set -eu

echo "Starting ogt-web (hyperconverged: MariaDB + Redis + OpenSearch + PHP-FPM + Caddy)..."

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command '$1' not found in PATH" >&2
    exit 1
  fi
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: Required file '$1' not found" >&2
    exit 1
  fi
}

# Sanity: ensure key binaries and configs exist before proceeding
require_cmd supervisord
require_cmd redis-server
require_cmd mysqld_safe
require_cmd mysql_install_db
require_cmd mysqladmin
require_cmd mysql
require_cmd redis-cli
require_file /etc/supervisord.conf
require_file /etc/caddy/Caddyfile
require_file /opt/opensearch/bin/opensearch

# 0. Start Redis (local only)
echo "Starting Redis..."
redis-server --daemonize yes --port 6379 --loglevel warning

# 0b. Start OpenSearch (required for Magento 2.4+ catalog search)
echo "Starting OpenSearch..."
# Ensure OpenSearch directories have correct ownership
# Create persistent data directory on the volume mount
mkdir -p /var/lib/mysql/opensearch
chown -R opensearch:opensearch /var/lib/mysql/opensearch /var/log/opensearch
# Set OPENSEARCH_JAVA_HOME to use Alpine's OpenJDK (bundled JDK is glibc-based, removed in Dockerfile)
export OPENSEARCH_JAVA_HOME=/usr/lib/jvm/java-17-openjdk
# Start OpenSearch as the opensearch user
su -s /bin/sh opensearch -c "OPENSEARCH_JAVA_HOME=/usr/lib/jvm/java-17-openjdk /opt/opensearch/bin/opensearch -d -p /tmp/opensearch.pid" 2>&1 | head -20 &

# Wait for OpenSearch to be ready
echo "Waiting for OpenSearch..."
OS_COUNTER=0
OS_MAX=60
OS_READY=0
while [ "$OS_COUNTER" -lt "$OS_MAX" ]; do
  if curl -s -o /dev/null http://127.0.0.1:9200; then
    echo "OpenSearch is ready! (after $OS_COUNTER iterations)"
    OS_READY=1
    break
  fi
  OS_COUNTER=$((OS_COUNTER + 1))
  echo "  waiting for OpenSearch... ($OS_COUNTER/$OS_MAX)"
  sleep 2
done

if [ "$OS_READY" -ne 1 ]; then
  echo "WARNING: OpenSearch failed to start within 120 seconds, continuing anyway..."
  # Check if it's running
  if [ -f /tmp/opensearch.pid ]; then
    echo "  OpenSearch PID: $(cat /tmp/opensearch.pid)"
  fi
  # Show any logs
  tail -20 /var/log/opensearch/*.log 2>/dev/null || true
fi

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

# Fix permissions on data directory (Fly.io mounts as root)
chown -R mysql:mysql /var/lib/mysql

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# Configuration: Prepare for future Clustering
# To enable Galera: set ENABLE_GALERA=true in fly.toml
ENABLE_GALERA=${ENABLE_GALERA:-false}

if [ "$ENABLE_GALERA" = "true" ]; then
    echo "Configuring MariaDB for Galera Cluster..."
    WSREP_ON="ON"
    BIND_ADDRESS="::"
    WSREP_PROVIDER="/usr/lib/libgalera_smm.so" # Path varies by distro
    # TODO: Add cluster address generation logic here
else
    echo "Configuring MariaDB as Standalone (Galera Disabled)..."
    WSREP_ON="OFF"
    # Bind to localhost only - PHP PDO needs TCP connection on 127.0.0.1
    BIND_ADDRESS="127.0.0.1"
    WSREP_PROVIDER="none"
fi

# Note: We do NOT use skip-networking because PHP/PDO needs TCP connection
# Remove any skip-networking from Alpine's default config
sed -i '/skip-networking/d' /etc/my.cnf.d/*.cnf 2>/dev/null || true
sed -i '/skip-networking/d' /etc/my.cnf 2>/dev/null || true
sed -i '/skip-networking/d' /etc/mysql/*.cnf 2>/dev/null || true

cat > /etc/my.cnf.d/runtime.cnf <<EOF
[mysqld]
socket=/run/mysqld/mysqld.sock
bind-address=${BIND_ADDRESS}
port=3306
skip-networking=0
wsrep_on=${WSREP_ON}
wsrep_provider=${WSREP_PROVIDER}
EOF

echo "Starting MariaDB..."
# Use mariadbd directly instead of mysqld_safe to ensure proper options handling
mariadbd --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock --port=3306 --bind-address=${BIND_ADDRESS} &

echo "Waiting for MariaDB socket..."
COUNTER=0
MAX_TRIES=60
MARIADB_UP=0
while [ "$COUNTER" -lt "$MAX_TRIES" ]; do
  if [ -S "/run/mysqld/mysqld.sock" ]; then
    if mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
      echo "MariaDB socket is ready! (after $COUNTER iterations)"
      MARIADB_UP=1
      break
    fi
  fi
  COUNTER=$((COUNTER + 1))
  echo "  waiting for socket... ($COUNTER/$MAX_TRIES)"
  sleep 2
done

if [ "$MARIADB_UP" -ne 1 ]; then
  echo "ERROR: MariaDB failed to start within 120 seconds"
  exit 1
fi

# Wait for TCP port 3306 to be ready (PHP PDO uses TCP)
echo "Waiting for MariaDB TCP port 3306..."
TCP_COUNTER=0
TCP_MAX=30
TCP_READY=0
while [ "$TCP_COUNTER" -lt "$TCP_MAX" ]; do
  # Use mysqladmin via TCP to verify TCP connectivity
  if mysqladmin --host=127.0.0.1 --port=3306 ping >/dev/null 2>&1; then
    echo "MariaDB TCP port 3306 is ready! (after $TCP_COUNTER iterations)"
    TCP_READY=1
    break
  fi
  TCP_COUNTER=$((TCP_COUNTER + 1))
  echo "  waiting for TCP port... ($TCP_COUNTER/$TCP_MAX)"
  sleep 1
done

if [ "$TCP_READY" -ne 1 ]; then
  echo "ERROR: MariaDB TCP port 3306 failed to open within 30 seconds"
  # Debug: show what's listening
  echo "Debug: netstat output:"
  netstat -tlnp 2>/dev/null || ss -tlnp 2>/dev/null || echo "(no netstat/ss available)"
  exit 1
fi

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

# Setup web root: Use Magento files from the image directly
# Only persist var/ and pub/media/ directories on the volume
PERSISTENT_VAR="/var/lib/mysql/magento_var"
PERSISTENT_MEDIA="/var/lib/mysql/magento_media"
WEB_ROOT="/var/www/html"

echo "Setting up Magento persistence directories..."

# Create persistent directories if they don't exist
mkdir -p "${PERSISTENT_VAR}" "${PERSISTENT_MEDIA}"
chown www-data:www-data "${PERSISTENT_VAR}" "${PERSISTENT_MEDIA}"

# Create Redis persistence directory
REDIS_DIR="/var/lib/mysql/redis"
mkdir -p "${REDIS_DIR}"
chown redis:redis "${REDIS_DIR}"
echo "  redis/ -> ${REDIS_DIR}"
# Note: OpenSearch persistence directory is created earlier in the bootstrap phase

# If var/ in webroot is a directory (not symlink), move contents to persistent location
if [ -d "${WEB_ROOT}/var" ] && [ ! -L "${WEB_ROOT}/var" ]; then
    # First time: move any existing var contents
    if [ -d "${WEB_ROOT}/var" ]; then
        cp -a "${WEB_ROOT}/var/." "${PERSISTENT_VAR}/" 2>/dev/null || true
        rm -rf "${WEB_ROOT}/var"
    fi
fi
ln -sfn "${PERSISTENT_VAR}" "${WEB_ROOT}/var"
echo "  var/ -> ${PERSISTENT_VAR}"

# Same for pub/media/
if [ -d "${WEB_ROOT}/pub/media" ] && [ ! -L "${WEB_ROOT}/pub/media" ]; then
    if [ -d "${WEB_ROOT}/pub/media" ]; then
        cp -a "${WEB_ROOT}/pub/media/." "${PERSISTENT_MEDIA}/" 2>/dev/null || true
        rm -rf "${WEB_ROOT}/pub/media"
    fi
fi
mkdir -p "${WEB_ROOT}/pub"
ln -sfn "${PERSISTENT_MEDIA}" "${WEB_ROOT}/pub/media"
echo "  pub/media/ -> ${PERSISTENT_MEDIA}"

# Only fix ownership on the symlinked persistent directories
# (webroot files already have correct ownership from Docker build)
chown -R www-data:www-data "${PERSISTENT_VAR}" "${PERSISTENT_MEDIA}"
echo "Magento persistence configured."

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

# Check if Magento needs installation (for background setup task)
MAGENTO_NEEDS_INSTALL=0
if [ ! -f "/var/www/html/app/etc/env.php" ]; then
  MAGENTO_NEEDS_INSTALL=1
  echo "Magento installation needed - will run in background after supervisord starts"
fi

# Export the variables needed by the background installer
export DB_NAME DB_USER DB_PASSWORD
export ADMIN_USER ADMIN_PASSWORD ADMIN_EMAIL
export ADMIN_FIRSTNAME ADMIN_LASTNAME MAGENTO_BASE_URL

# 3. Stop bootstrap services (supervisor will restart them)
echo "Stopping bootstrap services..."
mysqladmin --socket=/run/mysqld/mysqld.sock shutdown
redis-cli shutdown

# Create the Magento setup script for background execution
cat > /tmp/magento-setup.sh <<'EOFSETUP'
#!/bin/sh
set -eu

# Wait for services to be ready
echo "[magento-setup] Waiting for MariaDB..."
sleep 10
MAX_WAIT=60
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
  if mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
    echo "[magento-setup] MariaDB is ready"
    break
  fi
  COUNTER=$((COUNTER + 1))
  sleep 2
done

echo "[magento-setup] Waiting for OpenSearch..."
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
  if curl -s -o /dev/null http://127.0.0.1:9200; then
    echo "[magento-setup] OpenSearch is ready"
    break
  fi
  COUNTER=$((COUNTER + 1))
  sleep 2
done

echo "[magento-setup] Waiting for Redis..."
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
  if redis-cli ping >/dev/null 2>&1; then
    echo "[magento-setup] Redis is ready"
    break
  fi
  COUNTER=$((COUNTER + 1))
  sleep 2
done

DB_NAME=${DB_NAME:-magento}
DB_USER=${DB_USER:-magento}
DB_PASSWORD=${DB_PASSWORD:-}
ADMIN_USER=${ADMIN_USER:-}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-}
ADMIN_EMAIL=${ADMIN_EMAIL:-}

# Security: Validate admin credentials
if [ -z "${ADMIN_USER}" ]; then
  echo "[magento-setup] ERROR: ADMIN_USER must be set" >&2
  exit 1
fi

if [ "${ADMIN_USER}" = "admin" ]; then
  echo "[magento-setup] ERROR: ADMIN_USER must not be 'admin'" >&2
  exit 1
fi

if [ -z "${ADMIN_PASSWORD}" ]; then
  echo "[magento-setup] ERROR: ADMIN_PASSWORD must be set" >&2
  exit 1
fi

if [ ${#ADMIN_PASSWORD} -lt 16 ]; then
  echo "[magento-setup] ERROR: ADMIN_PASSWORD must be at least 16 characters" >&2
  exit 1
fi

if [ -z "${ADMIN_EMAIL}" ]; then
  echo "[magento-setup] ERROR: ADMIN_EMAIL must be set" >&2
  exit 1
fi

case "${ADMIN_EMAIL}" in
  *@*.*) ;;
  *) echo "[magento-setup] ERROR: ADMIN_EMAIL must be valid" >&2; exit 1 ;;
esac

echo "[magento-setup] Installing Magento (one-time bootstrap)..."

# Clean up any partial installation from previous failed attempts
echo "[magento-setup] Cleaning up any partial database..."
mysql --socket=/run/mysqld/mysqld.sock -e "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || true
mysql --socket=/run/mysqld/mysqld.sock -e "CREATE DATABASE ${DB_NAME};"
mysql --socket=/run/mysqld/mysqld.sock -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql --socket=/run/mysqld/mysqld.sock -e "FLUSH PRIVILEGES;"

cd /var/www/html && bin/magento setup:install \
  --base-url=${MAGENTO_BASE_URL:-http://localhost:8080/} \
  --db-host=127.0.0.1 \
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
  --search-engine=opensearch \
  --opensearch-host=localhost \
  --opensearch-port=9200 \
  --language=en_US --currency=USD --timezone=UTC --use-rewrites=1

echo "[magento-setup] Magento installation completed successfully!"

echo "[magento-setup] Running DI compile..."
cd /var/www/html && bin/magento setup:di:compile

echo "[magento-setup] DI compile completed!"
EOFSETUP
chmod +x /tmp/magento-setup.sh

# 4. Handover to Supervisor
echo "Starting Supervisor..."
mkdir -p /run/php-fpm

# Start Magento setup in background if needed (after supervisor starts)
if [ "$MAGENTO_NEEDS_INSTALL" = "1" ]; then
  (
    sleep 5  # Give supervisor time to start all services
    /tmp/magento-setup.sh 2>&1 | tee /var/log/magento-setup.log
  ) &
fi

exec supervisord -c /etc/supervisord.conf
