#!/usr/bin/env bash
set -euo pipefail

# Simple helper to create a Magento 2 project using composer inside the repo and run basic setup.
# This script expects environment variables to be set via git-crypt managed .env.encrypted only.
#
# SECURITY: This script requires strong admin credentials and will NOT use default values.

# Validate Magento composer credentials
if [ -z "${COMPOSER_MAGENTO_USERNAME:-}" ] || [ -z "${COMPOSER_MAGENTO_PASSWORD:-}" ]; then
  echo "ERROR: Please set COMPOSER_MAGENTO_USERNAME and COMPOSER_MAGENTO_PASSWORD in .env.encrypted"
  echo "Get credentials from: https://marketplace.magento.com/customer/accessKeys/"
  exit 1
fi

# Validate admin credentials are set and secure
if [ -z "${ADMIN_USER:-}" ]; then
  echo "ERROR: ADMIN_USER must be set in .env.encrypted"
  exit 1
fi

if [ "${ADMIN_USER}" = "admin" ]; then
  echo "ERROR: ADMIN_USER must not be the default value 'admin'"
  echo "Use a unique username for security"
  exit 1
fi

if [ -z "${ADMIN_PASSWORD:-}" ]; then
  echo "ERROR: ADMIN_PASSWORD must be set in .env.encrypted"
  exit 1
fi

if [ "${ADMIN_PASSWORD}" = "Admin123!" ] || [ "${ADMIN_PASSWORD}" = "admin" ]; then
  echo "ERROR: ADMIN_PASSWORD must not be a default or weak password"
  echo "Use a strong password (16+ characters, mixed case, numbers, symbols)"
  exit 1
fi

# Validate password strength (minimum 16 characters)
if [ ${#ADMIN_PASSWORD} -lt 16 ]; then
  echo "ERROR: ADMIN_PASSWORD must be at least 16 characters long"
  echo "Current length: ${#ADMIN_PASSWORD}"
  exit 1
fi

if [ -z "${ADMIN_EMAIL:-}" ]; then
  echo "ERROR: ADMIN_EMAIL must be set in .env.encrypted"
  exit 1
fi

# Validate email format (basic check)
if ! [[ "${ADMIN_EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "ERROR: ADMIN_EMAIL must be a valid email address"
  exit 1
fi

echo "✅ All required credentials validated"

echo "Starting Docker services..."
docker compose up -d --build

echo "Configuring composer auth for repo.magento.com inside the php container..."
docker compose exec php bash -lc "composer config --global http-basic.repo.magento.com '${COMPOSER_MAGENTO_USERNAME}' '${COMPOSER_MAGENTO_PASSWORD}' || true"

echo "Installing magento with composer (this may take a while)..."
docker compose exec php bash -lc "composer create-project --repository=https://repo.magento.com/ magento/project-community-edition magento2"

echo "Running Magento setup inside container..."
docker compose exec php bash -lc "cd magento2 && php bin/magento setup:install \
--base-url='${MAGENTO_BASE_URL:-http://localhost:8080}' \
--db-host=db \
--db-name='${MYSQL_DATABASE:-magento}' \
--db-user='${MYSQL_USER:-magento}' \
--db-password='${MYSQL_PASSWORD:-magento}' \
--admin-firstname='${ADMIN_FIRSTNAME:-Admin}' \
--admin-lastname='${ADMIN_LASTNAME:-User}' \
--admin-email='${ADMIN_EMAIL}' \
--admin-user='${ADMIN_USER}' \
--admin-password='${ADMIN_PASSWORD}' \
--language=en_US \
--currency=USD \
--timezone=UTC \
--use-rewrites=1 \
--cleanup-database"

echo ""
echo "✅ Magento installed successfully!"
echo ""
echo "Access your store at: ${MAGENTO_BASE_URL:-http://localhost:8080}"
echo "Admin URL: ${MAGENTO_BASE_URL:-http://localhost:8080}/admin"
echo "Admin User: ${ADMIN_USER}"
echo ""
echo "⚠️  IMPORTANT: Change the admin URL in production!"
echo "    Run: bin/magento setup:config:set --backend-frontname=<custom-path>"
echo ""

