set shell := ["bash", "-euo", "pipefail", "-c"]

ensure_env := '''
ensure_env() {
  local cmd=( "$@" )

  # Secrets are managed exclusively via git-crypt and .env.encrypted. No dotenvx or Infisical required.

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
