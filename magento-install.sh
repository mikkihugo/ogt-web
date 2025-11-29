#!/usr/bin/env bash
set -euo pipefail

# Simple helper to create a Magento 2 project using composer inside the repo and run basic setup.
# This script expects environment variables to be set via git-crypt managed .env.encrypted only.

if [ -z "${COMPOSER_MAGENTO_USERNAME:-}" ] || [ -z "${COMPOSER_MAGENTO_PASSWORD:-}" ]; then
  echo "Please set COMPOSER_MAGENTO_USERNAME and COMPOSER_MAGENTO_PASSWORD (Magento repo keys) in .env.encrypted"
  exit 1
fi

echo "Starting Docker services..."
docker compose up -d --build

echo "Configuring composer auth for repo.magento.com inside the php container..."
docker compose exec php bash -lc "composer config --global http-basic.repo.magento.com '${COMPOSER_MAGENTO_USERNAME}' '${COMPOSER_MAGENTO_PASSWORD}' || true"

echo "Installing magento with composer (this may take a while)..."
docker compose exec php bash -lc "composer create-project --repository=https://repo.magento.com/ magento/project-community-edition magento2"

echo "Running Magento setup inside container..."
docker compose exec php bash -lc "cd magento2 && php bin/magento setup:install \
--base-url=${MAGENTO_BASE_URL:-http://localhost:8080} \
--db-host=db \
--db-name=${MYSQL_DATABASE:-magento} \
--db-user=${MYSQL_USER:-magento} \
--db-password=${MYSQL_PASSWORD:-magento} \
--admin-firstname=Admin --admin-lastname=User --admin-email=admin@example.com \
--admin-user=admin --admin-password=Admin123! \
--language=en_US --currency=USD --timezone=UTC --use-rewrites=1"

echo "Magento installed. You can access at ${MAGENTO_BASE_URL:-http://localhost:8080}"

