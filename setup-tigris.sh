#!/usr/bin/env bash
set -euo pipefail

echo "🐯 Setting up Fly Tigris Storage for orgasmtoy.com"
echo "=================================================="
echo ""

# Check if flyctl is available
if ! command -v flyctl >/dev/null 2>&1; then
  echo "❌ Error: flyctl not found. Run: nix develop --accept-flake-config"
  exit 1
fi

# Check if logged in
if ! flyctl auth whoami >/dev/null 2>&1; then
  echo "Not logged in to Fly.io. Authenticating..."
  flyctl auth login
fi

echo "✅ Authenticated with Fly.io"
echo ""

# Create Tigris bucket
BUCKET_NAME="orgasmtoy-media"
echo "Creating Tigris bucket: $BUCKET_NAME"
echo ""

if flyctl storage create --name "$BUCKET_NAME" 2>&1 | grep -q "already exists"; then
  echo "⚠️  Bucket already exists, using existing bucket"
else
  echo "✅ Bucket created successfully"
fi

echo ""
echo "Getting S3 credentials..."
echo ""

# Get credentials
CREDS=$(flyctl storage credentials show "$BUCKET_NAME" 2>/dev/null || flyctl storage credentials create "$BUCKET_NAME")

echo "✅ Credentials retrieved"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 ADD THESE TO .env.encrypted:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$CREDS" | grep -E "AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|BUCKET_NAME|AWS_REGION|AWS_ENDPOINT_URL_S3"
echo ""
echo "S3_BUCKET=$BUCKET_NAME"
echo "S3_ENDPOINT=https://fly.storage.tigris.dev"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Next steps:"
echo "1. Copy the credentials above"
echo "2. Edit .env.encrypted and replace the AWS/S3 placeholders"
echo "3. Run: git-crypt init && git-crypt lock"
echo "4. Commit the encrypted file"
echo ""

