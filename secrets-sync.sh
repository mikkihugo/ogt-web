#!/usr/bin/env bash
set -euo pipefail

# ---
# CI Status Check Helper (for automation)
# Usage example:
#   gh run list --limit 1 --json status
# This outputs the latest GitHub Actions run status as raw JSON (non-interactive).
# You can use this in scripts to automate logic based on CI status.
#
# Optional: Add as a shell function for reuse
ci_status() {
  gh run list --limit 1 --json status
}
# Example usage in script:
#   status_json="$(ci_status)"
#   # Parse status from JSON (e.g. with jq):
#   status=$(echo "$status_json" | jq -r '.[0].status')
#   if [[ "$status" == "completed" ]]; then
#     echo "CI job completed!"
#   fi
# ---

# Usage: ./secrets-sync.sh fly|gh <envfile>
# Example: ./secrets-sync.sh fly .env.encrypted
# Example: ./secrets-sync.sh gh .env.encrypted

CMD="${1:-}"  # 'fly' or 'gh'
ENVFILE="${2:-.env.encrypted}"

# Validate command argument
if [[ ! "$CMD" =~ ^(fly|gh)$ ]]; then
  echo "Usage: $0 fly|gh <envfile>"
  echo "Error: Command must be 'fly' or 'gh'"
  exit 1
fi

# Validate environment file exists
if [[ ! -f "$ENVFILE" ]]; then
  echo "Error: $ENVFILE not found."
  exit 1
fi

# Validate environment variable name format
# Only allow alphanumeric characters and underscores (standard env var naming)
validate_key() {
  local key="$1"
  if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Error: Invalid environment variable name: $key"
    echo "Variable names must start with a letter or underscore and contain only alphanumeric characters and underscores."
    return 1
  fi
  return 0
}

case "$CMD" in
  fly)
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
      # Skip empty lines and comments
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

      # Trim whitespace from key
      key="$(echo "$key" | xargs)"

      # Validate key format
      if ! validate_key "$key"; then
        exit 1
      fi

      # Use printf %q to safely escape the value for shell
      # This prevents command injection by properly quoting special characters
      printf -v escaped_value '%q' "$value"

      # Use array to prevent word splitting and glob expansion
      fly secrets set "${key}=${value}"
    done < "$ENVFILE"
    ;;
  gh)
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
      # Skip empty lines and comments
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

      # Trim whitespace from key
      key="$(echo "$key" | xargs)"

      # Validate key format
      if ! validate_key "$key"; then
        exit 1
      fi

      # For GitHub secrets, use stdin to avoid command line exposure
      # This is safer than -b flag as it prevents command injection
      # and doesn't expose secrets in process list
      echo "$value" | gh secret set "$key"
    done < "$ENVFILE"
    ;;
esac
