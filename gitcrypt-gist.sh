#!/usr/bin/env bash
set -euo pipefail

REPO="ogt-web"
KEY_PATH="../.keys/${REPO}.git-crypt.key"

# Backup key to Gist
gist_backup() {
  GIST_URL=$(gh gist create "$KEY_PATH" --public=false --desc "$REPO git-crypt key backup" | tail -1)
  echo "Gist created: $GIST_URL"
}

# Retrieve key from Gist
gist_retrieve() {
  GIST_ID="$1"
  gh gist view "$GIST_ID" --raw > "$KEY_PATH"
  echo "Key retrieved to $KEY_PATH"
}

# Usage:
# To backup: ./gitcrypt-gist.sh backup
# To retrieve: ./gitcrypt-gist.sh retrieve <gist-id>

case "${1:-}" in
  backup)
    gist_backup
    ;;
  retrieve)
    gist_retrieve "$2"
    ;;
  *)
    echo "Usage: $0 backup | retrieve <gist-id>"
    exit 1
    ;;
esac
