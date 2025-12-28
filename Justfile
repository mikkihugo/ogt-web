# =============================================================================
# OGT-Web Justfile (Enterprise Standards)
# =============================================================================

# Default: Validation suite
default: ci

# Install Dependencies
install:
    npm install --legacy-peer-deps

# --- Quality Gates ---

# Run comprehensive CI pipeline (Lint, Typecheck, Test, Build)
ci: typecheck lint test build

# Run all linters (ESLint, Actionlint, Go Vet, Nix)
lint:
    @echo "Running Actionlint..."
    actionlint
    @echo "Running Nix Linters (Statix & Deadnix)..."
    statix check flake.nix
    deadnix flake.nix
    @echo "Running TypeScript Check (Medusa)..."
    cd apps/medusa && npm run check
    @echo "Running ESLint (Storefront)..."
    cd apps/storefront-next && npm run lint
    @echo "Running Go Lint (golangci-lint)..."
    cd apps/marketing-service-go && golangci-lint run ./...

# Run Tests
test:
    @echo "Testing Go Service (gotestsum)..."
    cd apps/marketing-service-go && gotestsum -- ./...

# Run Type Checking (Strict)
typecheck:
    @echo "Typechecking Medusa..."
    cd apps/medusa && npx tsc --noEmit --strict
    @echo "Typechecking Storefront..."
    cd apps/storefront-next && npx tsc --noEmit

# Format all codebases
fmt:
    @echo "Formatting with Prettier..."
    nix develop --command bash -c "prettier --write ."
    @echo "Formatting Go..."
    cd apps/marketing-service-go && go fmt ./...

# Check formatting (CI mode)
fmt-check:
    nix develop --command bash -c "prettier --check ."

# --- Agent / Fast Feedback Loop ---

# Fast Verification (Typecheck only - < 10s)
check: typecheck

# Full Environment Setup (Safe - No Data Loss)
# Usage: just setup
setup: clean dev-infra
    @echo "⏳ Waiting for DB to be healthy..."
    sleep 5
    @echo "Running Migrations..."
    cd apps/medusa && npm run medusa db:migrate
    @echo "Seeding Database..."
    cd apps/medusa && npm run medusa exec ./src/scripts/seed.ts
    @echo "✅ Setup Complete!"

# Reset Database Only (Safe Drop/Create)
# NOTE: Drops 'medusa' database but keeps server running
db-reset:
    @echo "⚠️  Resetting 'medusa' database..."
    # Terminate connections
    podman-compose -f infra/docker-compose.yml exec -T postgres psql -U medusa -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'medusa' AND pid <> pg_backend_pid();"
    # Drop and Recreate
    podman-compose -f infra/docker-compose.yml exec -T postgres dropdb -U medusa --if-exists medusa
    podman-compose -f infra/docker-compose.yml exec -T postgres createdb -U medusa medusa
    @echo "⏳ Waiting for DB..."
    sleep 2
    # Migrate & Seed
    cd apps/medusa && npm run medusa db:migrate
    cd apps/medusa && npm run medusa exec ./src/scripts/seed.ts
    @echo "✅ Database Reset Complete"

# --- Build & Deploy ---

# Build all applications via Nix
build:
    @echo "Building Marketing Service (Go)..."
    nix build .#marketing-service
    @echo "Building Storefront (Next.js)..."
    nix build .#storefront-next

# --- Infrastructure ---

# Start local dev stack
dev-infra:
    podman-compose -f infra/docker-compose.yml up -d postgres redis minio meilisearch

# Clean build artifacts
clean:
    rm -rf result
    rm -rf apps/medusa/.turbo apps/medusa/dist
    rm -rf apps/storefront-next/.next apps/storefront-next/.turbo

# --- CI Monitoring ---

# Watch live logs of the latest run (Interactive)
watch:
    gh run watch

# Poll status every 30s (Non-interactive)
monitor:
    @echo "Monitoring latest run (Ctrl+C to stop)..."
    @while true; do \
        RUN=$(gh run list --limit 1 --json databaseId,status,conclusion,startedAt --jq '.[0]'); \
        ID=$(echo $$RUN | jq -r .databaseId); \
        STATUS=$(echo $$RUN | jq -r .status); \
        RESULT=$(echo $$RUN | jq -r .conclusion); \
        TIME=$(echo $$RUN | jq -r .startedAt); \
        echo "[$(date +%T)] Run $$ID: $$STATUS ($$RESULT) - Started: $$TIME"; \
        if [ "$$STATUS" = "completed" ]; then \
            echo "✅ Run completed with result: $$RESULT"; \
            break; \
        fi; \
        sleep 30; \
    done

