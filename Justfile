set shell := ["bash", "-euo", "pipefail", "-c"]

ensure_env := '''
ensure_env() {
  local cmd=( "$@" )

  # If an encrypted env is present, require DOTENV_PRIVATE_KEY (kept in Infisical) and load via dotenvx
  if [ -f .env.encrypted ]; then
    if ! command -v dotenvx >/dev/null 2>&1; then
      echo "dotenvx is required to load .env.encrypted (install via nix dev shell)." >&2
      exit 1
    fi
    if [ -z "${DOTENV_PRIVATE_KEY:-}" ] && [ -f .env.private ]; then
      # shellcheck disable=SC1091
      source .env.private
    fi
    if [ -z "${DOTENV_PRIVATE_KEY:-}" ] && command -v infisical >/dev/null 2>&1; then
      INFISICAL_API_URL=${INFISICAL_API_URL:-https://vault.singularity-engine.com/api}
      TOKEN_ARGS=()
      if [ -n "${INFISICAL_SERVICE_TOKEN:-}" ]; then
        TOKEN_ARGS=(--token "${INFISICAL_SERVICE_TOKEN}")
      fi
      DOTENV_PRIVATE_KEY=$(INFISICAL_API_URL="$INFISICAL_API_URL" infisical secrets get DOTENV_PRIVATE_KEY --env prod --path /ogt-web --plain --silent "${TOKEN_ARGS[@]}" 2>/dev/null | head -n1 || true)
      export DOTENV_PRIVATE_KEY
    fi
    if [ -z "${DOTENV_PRIVATE_KEY:-}" ]; then
      echo "Login to Infisical (infisical login --domain https://vault.singularity-engine.com) or set INFISICAL_SERVICE_TOKEN; optional: place DOTENV_PRIVATE_KEY in gitignored .env.private." >&2
      exit 1
    fi
    cmd=(dotenvx run --env-file .env.encrypted -- "${cmd[@]}")
  fi

  if command -v direnv >/dev/null 2>&1; then
    direnv allow .
    direnv exec . "${cmd[@]}"
  elif command -v nix >/dev/null 2>&1; then
    nix --extra-experimental-features "nix-command flakes" develop --accept-flake-config . -c "${cmd[@]}"
  else
    echo "direnv or nix is required to work on ogt-web." >&2
    exit 1
  fi
}
'''

default:
  @just --list

dev:
  {{ensure_env}}
  ensure_env "${SHELL:-bash}"

build-container:
  {{ensure_env}}
  ensure_env nix build .#container

load-container:
  {{ensure_env}}
  ensure_env bash -c 'nix build .#container && docker load < result'

deploy-remote:
  {{ensure_env}}
  ensure_env flyctl deploy --remote-only \
    --build-arg COMPOSER_MAGENTO_USERNAME="${COMPOSER_MAGENTO_USERNAME:-}" \
    --build-arg COMPOSER_MAGENTO_PASSWORD="${COMPOSER_MAGENTO_PASSWORD:-}"

logs:
  {{ensure_env}}
  ensure_env flyctl logs --tail 200

sync-media:
  {{ensure_env}}
  ensure_env nix run .#sync-media

restore-media:
  {{ensure_env}}
  ensure_env nix run .#restore-media
