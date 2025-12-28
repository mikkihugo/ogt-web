#!/bin/bash
# Deploy script for Hetzner VPS
# Usage: ./deploy.sh [tag]
#
# Workflow:
# 1. Build locally: ./build-and-push.sh [tag]
# 2. Deploy to Hetzner: ./deploy.sh [tag]

set -e

SERVER="root@77.42.66.89"
DEPLOY_DIR="/opt/ogt"
TAG="${1:-latest}"

echo "==> Deploying to Hetzner (tag: ${TAG})..."

# Create deploy directory on server
ssh $SERVER "mkdir -p $DEPLOY_DIR"

# Sync only deploy configs (no source code needed!)
rsync -avz \
  docker-compose.yml \
  Caddyfile \
  .env.example \
  $SERVER:$DEPLOY_DIR/

# Pull and start on server
ssh $SERVER << ENDSSH
cd /opt/ogt

# Copy .env if not exists
if [ ! -f .env ]; then
  cp .env.example .env
  echo "WARNING: Created .env from example - please edit with real secrets!"
fi

# Set image tag
export TAG=${TAG}

# Pull latest images
docker compose pull

# Start/restart containers
docker compose up -d

# Run Medusa migrations
docker compose exec -T medusa yarn medusa db:migrate

# Create admin user (will fail silently if already exists)
docker compose exec -T medusa yarn medusa user -e "\${MEDUSA_ADMIN_EMAIL:-mhugo@ownorgasm.com}" -p "\${MEDUSA_ADMIN_PASSWORD}" || true

echo "==> Deployment complete!"
docker compose ps
ENDSSH
