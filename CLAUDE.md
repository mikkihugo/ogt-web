# Claude Notes (ogt-web)

## Project Overview
Medusa.js v2 headless e-commerce backend for orgasmtoy.com (adult toy store with dropshipping).

## Development Setup
- Run inside the Nix dev shell: `direnv exec . <cmd>` or `nix develop --command <cmd>`
- Dev shell provides: Node.js 22, Yarn, PostgreSQL 16, flyctl, git-crypt
- Install deps: `yarn install`
- Dev server: `yarn dev`
- Build: `yarn build`

## Deployment
- **Auto-deploy**: Push a version tag (e.g., `git tag v1.0.0 && git push origin v1.0.0`)
- **Manual deploy**: `fly deploy` or trigger via GitHub Actions workflow_dispatch
- Fly.io builds the Dockerfile remotely

## Database
- Medusa requires PostgreSQL
- For production: Create a Fly Postgres cluster or use external DB
- DATABASE_URL format: `postgres://user:pass@host:5432/dbname`

## Secrets Management
- Secrets are managed via git-crypt and `.env.encrypted`
- The git-crypt key is backed up via private Gist (auto-unlocked in Nix shell)
- Use `fly secrets set KEY=value` for Fly.io runtime secrets

## Project Structure
```
src/
  admin/       # Admin dashboard customizations
  api/         # Custom API routes
  jobs/        # Background jobs
  links/       # Module linking
  modules/     # Custom modules
  scripts/     # Scripts (e.g., seed.ts)
  subscribers/ # Event subscribers
  workflows/   # Medusa workflows
```

## Key Files
- `medusa-config.ts` - Medusa configuration
- `fly.toml` - Fly.io deployment config
- `Dockerfile` - Container build
- `.github/workflows/deploy.yml` - CI/CD

## Archive Note
The original Magento 2 code is preserved in the `magento-archive` branch.
