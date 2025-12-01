#!/bin/bash
# Build images on Hetzner, push to GHCR
# Usage: ./build-and-push.sh [tag]

set -e

REGISTRY="ghcr.io/mikkihugo/ogt"
TAG="${1:-latest}"
SERVER="root@157.180.79.108"

: "${GHCR_TOKEN:?Set GHCR_TOKEN environment variable for GHCR login}"

echo "==> Syncing source to Hetzner for build..."

# Sync source (excluding node_modules, .git)
rsync -avz --exclude 'node_modules' --exclude '.git' --exclude '.medusa' \
  ../ $SERVER:/tmp/ogt-build/

echo "==> Building and pushing images on Hetzner..."

# Build and push on server (Docker is already installed)
ssh $SERVER << ENDSSH
cd /tmp/ogt-build

# Login to GHCR (token from gh auth)
echo "$GHCR_TOKEN" | docker login ghcr.io -u mikkihugo --password-stdin

# Build Medusa
docker build -t ${REGISTRY}/medusa:${TAG} -f deploy/Dockerfile.medusa .

# Build Storefront
docker build -t ${REGISTRY}/storefront:${TAG} -f storefront/Dockerfile storefront/

# Push images
docker push ${REGISTRY}/medusa:${TAG}
docker push ${REGISTRY}/storefront:${TAG}

# Cleanup
rm -rf /tmp/ogt-build

echo "==> Done! Images pushed."
ENDSSH

echo "Images available at:"
echo "  - ${REGISTRY}/medusa:${TAG}"
echo "  - ${REGISTRY}/storefront:${TAG}"
