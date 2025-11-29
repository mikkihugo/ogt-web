# Agent Guide (ogt-web)

- Environment: this repo is Nix-first. Always enter via `direnv` (`use flake .`) or run commands with `direnv exec . …` / `nix develop --accept-flake-config --command …` if direnv is unavailable.
- Binary cache policy: do not use Cachix or FlakeHub. Use only the default cache.nixos.org or the FlakeCache substituter if explicitly configured.
- Dev shell: `nix develop` exposes PHP 8.3, composer, MariaDB client, traefik, redis, git, kubectl/helm, flyctl. `IN_NIX_SHELL=1` is set inside.
- Auto-load: `.envrc` requires Nix and loads the flake devshell; ensure your shell has `eval "$(direnv hook bash)"` (or zsh/fish equivalent) and run `direnv allow`.
- Secrets: keep only one secret in your secret manager (Infisical at `https://vault.singularity-engine.com/api`): `DOTENV_PRIVATE_KEY`. Store encrypted env in `.env.encrypted` (created with `dotenvx encrypt --env-file .env --stdout > .env.encrypted`), commit that file, and never commit `.env.keys`. `.envrc`/`Justfile` will refuse to load until the key is present; they will auto-fetch it via Infisical (login or `INFISICAL_SERVICE_TOKEN`) or, as a fallback, you can place it in gitignored `.env.private`.
- Tasks: use the `Justfile` helpers (below) when outside the shell; they bootstrap the dev env automatically and load `.env.encrypted` via `dotenvx` when `DOTENV_PRIVATE_KEY` is set. Media helpers: `just sync-media` (push `pub/media` to S3) and `just restore-media` (pull from S3).
- Testing/Build: use `just build-container` to build the container via Nix; `just deploy-remote` runs `flyctl deploy --remote-only` (needs secrets and Fly auth).
- Scripts for secrets/key management (`gitcrypt-gist.sh`, `secrets-sync.sh`) are available in every Nix shell and referenced in `flake.nix`.
- To backup/restore the git-crypt key, use `./gitcrypt-gist.sh` and a private Gist.
- To inject secrets into Fly.io or GitHub, use `./secrets-sync.sh fly .env.encrypted` or `./secrets-sync.sh gh .env.encrypted` after unlocking with git-crypt.
- All automation is Nix-native and CI-friendly.

- Secrets are managed exclusively via git-crypt and `.env.encrypted`. No dotenvx or Infisical required. Use the provided scripts for key management and secrets sync.

**Architecture Policy:** All production container images must be AMD64 (x86_64). CI enforces this and will fail the build if the architecture is not correct.
