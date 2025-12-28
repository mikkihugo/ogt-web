# =============================================================================
# OGT-Web Justfile (Enterprise Standards)
# =============================================================================

# Default: Validation suite
default: ci

# --- Quality Gates ---

# Run comprehensive CI pipeline (Lint, Typecheck, Test, Build)
ci: typecheck lint test build

# Run all linters (ESLint, Actionlint, Go Vet)
lint:
    @echo "Running Actionlint..."
    actionlint
    @echo "Running ESLint (Medusa)..."
    cd apps/medusa && yarn lint
    @echo "Running ESLint (Storefront)..."
    cd apps/storefront-next && yarn lint
    @echo "Running Go Vet..."
    cd apps/marketing-service-go && go vet ./...

# Run Tests
test:
    @echo "Testing Go Service..."
    cd apps/marketing-service-go && go test ./...

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
    docker-compose -f infra/docker-compose.yml up -d postgres redis minio meilisearch

# Clean build artifacts
clean:
    rm -rf result
    rm -rf apps/medusa/.turbo apps/medusa/dist
    rm -rf apps/storefront-next/.next apps/storefront-next/.turbo

