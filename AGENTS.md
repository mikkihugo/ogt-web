# Agent Guide (ogt-web)

- Environment: this repo is Nix-first. Always enter via `direnv` (`use flake .`) or run commands with `direnv exec . …` / `nix develop --accept-flake-config --command …` if direnv is unavailable.
- Binary cache policy: do not use Cachix or FlakeHub. Use only the default cache.nixos.org or the FlakeCache substituter if explicitly configured.
- Dev shell: `nix develop` exposes PHP 8.3, composer, MariaDB client, traefik, redis, git, kubectl/helm, flyctl. `IN_NIX_SHELL=1` is set inside.
- Auto-load: `.envrc` requires Nix and loads the flake devshell; ensure your shell has `eval "$(direnv hook bash)"` (or zsh/fish equivalent) and run `direnv allow`.
- Secrets: keep only one secret in your secret manager (Infisical at `https://vault.singularity-engine.com/api`): `DOTENV_PRIVATE_KEY`. Store encrypted env in `.env.encrypted` (created with `dotenvx encrypt --env-file .env --stdout > .env.encrypted`), commit that file, and never commit `.env.keys`. `.envrc`/`Justfile` will refuse to load until the key is present; they will auto-fetch it via Infisical (login or `INFISICAL_SERVICE_TOKEN`) or, as a fallback, you can place it in gitignored `.env.private`.
- S3 media: put `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET`, `S3_REGION`, optional `S3_ENDPOINT` (set to `https://storage.fly.io` for Fly Tigris) into `.env.encrypted` and Infisical `/ogt-web` (env `prod`). CI and Just media sync use those; do not mirror into GitHub secrets—only the Infisical service token is in GH.
- Tasks: use the `Justfile` helpers (below) when outside the shell; they bootstrap the dev env automatically and load `.env.encrypted` via `dotenvx` when `DOTENV_PRIVATE_KEY` is set. Media helpers: `just sync-media` (push `pub/media` to S3) and `just restore-media` (pull from S3).
- Testing/Build: use `just build-container` to build the container via Nix; `just deploy-remote` runs `flyctl deploy --remote-only` (needs secrets and Fly auth).
