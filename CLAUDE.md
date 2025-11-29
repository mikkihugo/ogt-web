# Claude Notes (ogt-web)

- Always run inside the Nix dev shell. Preferred: `direnv exec . <cmd>` or `nix develop --accept-flake-config --command <cmd>` when direnv isn’t active.
- Dev shell contents: PHP 8.3 + composer, MariaDB client, traefik, redis, git, kubectl/helm, flyctl. The shell sets `IN_NIX_SHELL=1` and prints a banner.
- Binary cache policy: do not use Cachix or FlakeHub. Use only cache.nixos.org or the FlakeCache substituter if it is configured.
- Auto-load: `.envrc` uses `use flake .` and requires `nix` to be present. Ensure the shell has `eval "$(direnv hook bash)"` and run `direnv allow` once.
- Secrets: keep a single secret in your manager (Infisical at `https://vault.singularity-engine.com/api`): `DOTENV_PRIVATE_KEY`. Encrypt your `.env` with `dotenvx encrypt --env-file .env --stdout > .env.encrypted`, commit `.env.encrypted`, and never commit `.env.keys`. If `.env.encrypted` exists and the key is missing, `.envrc`/Justfile try Infisical (interactive login or `INFISICAL_SERVICE_TOKEN`); fallback is gitignored `.env.private`. S3 media creds (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET`, `S3_REGION`, optional `S3_ENDPOINT`—use `https://storage.fly.io` for Fly Tigris) belong in `.env.encrypted` and Infisical, not GitHub secrets (only the Infisical service token lives in GH).
- Tasks: use `just` targets—they self-bootstrap the env (direnv if present, otherwise `nix develop`) and will wrap commands with `dotenvx run` when `.env.encrypted` is present. Example: `just build-container`, `just deploy-remote` (needs Fly auth/secrets), `just sync-media` (push `pub/media` to S3), `just restore-media` (pull from S3).
+ Secrets are managed exclusively via git-crypt and `.env.encrypted`. No dotenvx or Infisical required. Use the provided scripts for key management and secrets sync.

## Secrets & Key Management (Nix-native, CI-automated)

- All secrets are encrypted in `.env.encrypted` using `git-crypt`.
- The git-crypt key is backed up/restored via a private Gist using `./gitcrypt-gist.sh`.
- Secrets are injected into Fly.io or GitHub Actions using `./secrets-sync.sh fly .env.encrypted` or `./secrets-sync.sh gh .env.encrypted` (after unlocking with git-crypt).
- Both scripts are available in every Nix shell and referenced in `flake.nix`.
- All automation is Nix-native and CI-friendly.

See README.md for full workflow details.

If warnings appear about untrusted flake config, add `accept-flake-config = true` and `experimental-features = nix-command flakes` to the Nix config or pass `--accept-flake-config`.
