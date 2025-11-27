# Copilot Instructions for magneto-web

## Architecture Overview
This project is a **"Hyper-converged" Magento 2 deployment** on Fly.io.
- **Single Container:** Runs Nginx, PHP-FPM, and MariaDB (Galera) in one image.
- **Clustering:** MariaDB instances form a Galera cluster automatically using Fly.io internal DNS.
- **Frontend:** Includes a static site prototype (`momento2-site`) and a Magento theme (`magento-theme`).

## Critical Workflows

### Deployment
- **Platform:** Fly.io (App: `magneto-orgasmtoy`, Region: `arn` + `fra`).
- **Command:** `fly deploy --remote-only` (triggered via GitHub Actions).
- **Scaling:** `fly scale count <1|3|5>` (Odd numbers recommended for Quorum).
- **Volumes:** Each node requires a persistent volume mounted at `/var/lib/mysql`.

### Database & Clustering
- **Engine:** MariaDB with Galera Cluster.
- **Quorum:** Always scale in odd numbers (1, 3, 5) to prevent "split-brain" scenarios.
- **Discovery:** `docker/start.sh` uses `dig` to find peers via `$FLY_APP_NAME.internal`.
- **Bootstrapping:**
  - First node (no peers): Starts with `wsrep_cluster_address="gcomm://"`.
  - Subsequent nodes: Join via `wsrep_cluster_address="gcomm://[peer_ip]"`.
- **Credentials:** Default user `magento` / password `magento` (internal only).

### Build Process
- **Dockerfile:** Multi-stage build.
  - Installs system deps (including `galera`, `rsync`, `socat`).
  - Installs Magento via Composer.
  - Copies `docker/start.sh` as the entrypoint.
- **Secrets:** Adobe Commerce keys (`COMPOSER_MAGENTO_USERNAME`/`PASSWORD`) are passed as build args.

## Project Structure
- `docker/` - Infrastructure config (Nginx, MariaDB, `start.sh`).
- `magento-theme/` - Custom Magento modules (Stripe, Klarna).
- `momento2-site/` - Static HTML/JS prototype site.
- `fly.toml` - Fly.io configuration (ports, mounts, env vars).
- `.github/workflows/` - CI/CD pipelines.

## Conventions
- **"All-in-One" Rule:** Do not suggest splitting DB into a separate app unless explicitly asked. The project prioritizes cost/simplicity.
- **Startup Logic:** All boot logic (DB init, Magento install, service start) lives in `docker/start.sh`. Modify this file for startup changes.
- **Branding:** The public brand is "orgasmtoy". Internal project name is "momento".

## Technical Constraints & "Gotchas"
### Fly.io & Galera
- **Networking:** Galera traffic flows over Fly's private IPv6 network (6PN). No ports (`4567`, `4568`, `4444`) need to be exposed in `fly.toml`.
- **Discovery:** Peers are discovered via `dig AAAA <app-name>.internal`.
- **Split Brain:** If the entire cluster stops, the first node to start attempts to bootstrap. If multiple start simultaneously, a split-brain may occur.
  - *Fix:* SSH into one node and run `galera_new_cluster` if stuck.
- **SST Method:** Uses `rsync` (blocking). New nodes will pause the donor node briefly while copying data.

### Magento Clustering
- **Sessions:** Currently default to **files** (`var/session`).
  - *Impact:* Scaling to 2+ nodes will break user sessions (logouts) unless sticky sessions are perfect or storage is moved to DB/Redis.
  - *Recommendation:* Use `--session-save=db` in `start.sh` for true stateless scaling without Redis.
- **Cache:** `var/cache` is local. Cache invalidation on one node won't affect others.

