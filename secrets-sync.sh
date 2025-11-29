#!/usr/bin/env bash
set -euo pipefail

# Usage: ./secrets-sync.sh fly|gh <envfile>
# Example: ./secrets-sync.sh fly .env.encrypted
# Example: ./secrets-sync.sh gh .env.encrypted

CMD="${1:-}"  # 'fly' or 'gh'
ENVFILE="${2:-.env.encrypted}"

if [[ ! -f "$ENVFILE" ]]; then
  echo "Error: $ENVFILE not found."
  exit 1
fi

case "$CMD" in
  fly)
    while IFS='=' read -r key value; do
      [[ -z "$key" || "$key" =~ ^# ]] && continue
      fly secrets set "$key"="$value"
    done < "$ENVFILE"
    ;;
  gh)
    while IFS='=' read -r key value; do
      [[ -z "$key" || "$key" =~ ^# ]] && continue
      gh secret set "$key" -b"$value"
    done < "$ENVFILE"
    ;;
  *)
    echo "Usage: $0 fly|gh <envfile>"
    exit 1
    ;;
esac
