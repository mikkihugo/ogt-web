#!/bin/bash
set -e

echo "Starting ogt-web (Galera + Web + Redis)..."

# 0. Start Redis
echo "Starting Redis..."
redis-server --daemonize yes --port 6379 --loglevel warning

# 1. Initialize MariaDB Data Directory
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# 2. Galera Configuration & Discovery
# Only if we are in Fly (check env var or something, but we can assume yes for now)
# We need to set the node address and cluster address
# Fly uses IPv6 for internal networking.
# We need to find our own IP and peer IPs.

MY_IP=$(hostname -i | awk '{print $1}') # Take the first one if multiple
echo "My IP: $MY_IP"

# Update Galera Config with Node Address
echo "[mysqld]" > /etc/my.cnf.d/galera_runtime.cnf
echo "wsrep_node_address=[$MY_IP]" >> /etc/my.cnf.d/galera_runtime.cnf

# Peer Discovery
# We use the Fly internal DNS name: $FLY_APP_NAME.internal
if [ -n "$FLY_APP_NAME" ]; then
    echo "Discovering peers for $FLY_APP_NAME..."
    # Get all AAAA records, remove own IP
    # We use 'dig' from bind-tools
    PEERS=$(dig +short AAAA ${FLY_APP_NAME}.internal | grep -v "$MY_IP" | paste -s -d, -)
    
    if [ -z "$PEERS" ]; then
        echo "No peers found. Bootstrapping primary component..."
        # gcomm:// means "I am the first/primary"
        WSREP_CLUSTER_ADDRESS="gcomm://"
    else
        echo "Found peers: $PEERS. Joining cluster..."
        # Galera handles IPv6, but sometimes needs brackets. 
        # For now, we try without brackets in the list, as some versions are picky.
        # If it fails, we might need to format as [ip1],[ip2]
        WSREP_CLUSTER_ADDRESS="gcomm://$PEERS" 
    fi
    
    echo "wsrep_cluster_address=$WSREP_CLUSTER_ADDRESS" >> /etc/my.cnf.d/galera_runtime.cnf
else
    echo "FLY_APP_NAME not set. Assuming localhost/standalone."
    echo "wsrep_on=OFF" >> /etc/my.cnf.d/galera_runtime.cnf
fi

# 3. Start MariaDB
echo "Starting MariaDB..."
# We use mysqld_safe. It will pick up configs from /etc/my.cnf.d/
mysqld_safe --datadir=/var/lib/mysql &
MYSQL_PID=$!

# Wait for MariaDB to be ready
echo "Waiting for MariaDB..."
for i in {1..60}; do
    if mysqladmin ping -h localhost --silent; then
        echo "MariaDB is up!"
        break
    fi
    sleep 2
done

# 4. Magento Setup (Idempotent)
echo "Checking Magento Database..."
# Wait a bit more for cluster sync if needed
sleep 5

mysql -e "CREATE DATABASE IF NOT EXISTS magento;"
mysql -e "CREATE USER IF NOT EXISTS 'magento'@'localhost' IDENTIFIED BY 'magento';"
mysql -e "GRANT ALL PRIVILEGES ON magento.* TO 'magento'@'localhost';"
mysql -e "CREATE USER IF NOT EXISTS 'exporter'@'localhost' IDENTIFIED BY 'exporterpass' WITH MAX_USER_CONNECTIONS 3;"
mysql -e "GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Create MySQL config for exporter
cat > /etc/.mysqld_exporter.cnf <<EOF
[client]
user=exporter
password=exporterpass
EOF

if [ ! -f "/var/www/html/app/etc/env.php" ]; then
    echo "Installing Magento..."
    cd /var/www/html && bin/magento setup:install \
        --base-url=${MAGENTO_BASE_URL:-http://localhost:8080/} \
        --db-host=localhost \
        --db-name=magento \
        --db-user=magento \
        --db-password=magento \
        --admin-firstname=${ADMIN_FIRSTNAME:-Admin} \
        --admin-lastname=${ADMIN_LASTNAME:-User} \
        --admin-email=${ADMIN_EMAIL:-admin@example.com} \
        --admin-user=${ADMIN_USER:-admin} \
        --admin-password=${ADMIN_PASSWORD:-Admin123!} \
        --session-save=redis \
        --session-save-redis-host=localhost \
        --session-save-redis-port=6379 \
        --cache-backend=redis \
        --cache-backend-redis-server=localhost \
        --cache-backend-redis-port=6379 \
        --language=en_US --currency=USD --timezone=UTC --use-rewrites=1
fi

# 5. Start Prometheus Exporters for Telemetry
echo "Starting Prometheus exporters..."
mysqld_exporter --config.my-cnf /etc/.mysqld_exporter.cnf --web.listen-address=":9104" &
redis_exporter --redis.addr localhost:6379 --web.listen-address=":9121" &
php-fpm_exporter server --phpfpm.scrape-uri tcp://127.0.0.1:9000/status --web.listen-address=":9253" &

# 6. Start Web Services
echo "Starting PHP-FPM..."
php-fpm -D

echo "Starting Traefik..."
exec traefik --configFile=/etc/traefik/traefik.yml
