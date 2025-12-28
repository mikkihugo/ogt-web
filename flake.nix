# =============================================================================
# OGT-Web: Medusa.js E-commerce on Hetzner with Nix
# =============================================================================
#
# ARCHITECTURE:
# Medusa.js v2 headless e-commerce platform
# - TypeScript backend with PostgreSQL
# - REST & GraphQL APIs
# - Admin dashboard included
#
# USAGE:
#   nix develop                         # Enter development shell
#   yarn install                        # Install dependencies
#   yarn dev                            # Start dev server
#   yarn build                          # Build for production
#
#
# =============================================================================
{
  description = "OGT-Web: Medusa.js E-commerce on Hetzner with NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  outputs = { self, nixpkgs, flake-utils, sops-nix }:
    let
      # NixOS configuration for production server
      nixosConfigurations.ogt-web-prod = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit self nixpkgs sops-nix; inputs = { inherit sops-nix; }; };
        modules = [ ./hosts/ogt-web-prod ];
      };
    in
    {
      inherit nixosConfigurations;
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        # =====================================================================
        # DEVELOPMENT SHELL
        # =====================================================================
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Node.js runtime (Medusa requires Node 20+)
            nodejs_22
            nodePackages.typescript
            nodePackages.typescript-language-server
            nodePackages.prettier

            # Database
            (postgresql_18.withPackages (p: [
              p.postgis
              p.timescaledb
              p.pgvector
              p.pg_cron
            ]))

            # Deployment & DevOps
            hcloud
            terraform
            podman
            podman-compose

            # Secrets management
            git
            sops
            gh  # GitHub CLI for gist management

            # Utilities
            jq
            curl
            awscli2
            just
            actionlint
            statix
            deadnix

            # Go Development
            go
            gopls
            golangci-lint # Enterprise Go Linting (Antipatterns)
            gotestsum     # Proper Test Runner

            # Node for Admin
            nodejs_22

            nodePackages.eslint # Global ESLint
            oxlint              # Fast JS/TS Linter

            # Build System
            bazelisk
          ];

          shellHook = ''
            export IN_NIX_SHELL=1
            export NIX_SHELL_PROJECT="ogt-web"
            export GOPROXY=https://proxy.golang.org,direct

            # Corepack disabled to prevent read-only filesystem errors
            # corepack enable 2>/dev/null || true

            echo "🛒 OGT-Web Medusa.js Dev Shell (Node.js + NPM)"
            echo "Node $(node --version) | PostgreSQL 18 (GIS, Timescale, Vector, Trigram, Cron)"
            echo "Container Engine: Podman"
            echo ""
            echo "Commands:"
            echo "  just setup       # Initialize environment"
            echo "  just dev-infra   # Start infrastructure (Podman)"
            echo "  npm run dev      # Start development server"
            echo ""
            echo "Secrets are managed via sops-nix (age encrypted)."
            echo "  To edit: sops secrets/secrets.yaml"

            # Auto-setup sops age key from gist if not present
            if [ ! -f ~/.config/sops/age/keys.txt ]; then
              if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                AGE_KEY=$(gh gist view c2efe93258b7cef394aff1b6fd7c7860 --raw 2>/dev/null | grep "AGE-SECRET-KEY" | head -1)
                if [ -n "$AGE_KEY" ]; then
                  mkdir -p ~/.config/sops/age
                  echo "$AGE_KEY" > ~/.config/sops/age/keys.txt
                  chmod 600 ~/.config/sops/age/keys.txt
                  echo "🔓 sops age key configured from gist"
                fi
              fi
            fi
          '';
        };

        # =====================================================================
        # PACKAGES
        # =====================================================================
        packages = rec {
        # Storefront Builder (Standard NPM)
        storefront-next = pkgs.buildNpmPackage {
          name = "ogt-web-storefront";
          src = ./.;
          
          # NPM configuration - hash will be recalculated
          npmDepsHash = "sha256-0AwxfriB2atvVwy6/KMiuZ4uGUkTYrA5Epk5dyLW7RQ=";
          makeCacheWritable = true;
          npmFlags = [ "--legacy-peer-deps" ];
          dontNpmBuild = true;  # We handle build in buildPhase
          
          nativeBuildInputs = [ 
            pkgs.pkg-config 
            pkgs.python3
            pkgs.util-linux
            pkgs.nodePackages.node-gyp
          ];
          
          buildInputs = [
            pkgs.vips
            pkgs.glib
            pkgs.gcc
            pkgs.gnumake
          ];

          buildPhase = ''
            # Fix for sharp/node-gyp in Nix
            export PYTHON=${pkgs.python3}/bin/python3
            
            npm run build --workspace=apps/storefront-next
          '';

          installPhase = ''
            mkdir -p $out
            
            # Navigate to storefront
            cd apps/storefront-next
            
            # Copy Next.js standalone build
            cp -r .next/standalone/* $out/
            mkdir -p $out/.next/static
            cp -r .next/static $out/.next/static
            cp -r public $out/public 2>/dev/null || true
          '';
        };

        # Build Go Marketing Service
        marketing-service = pkgs.buildGoModule {
          pname = "marketing-service";
          version = "1.0.0";
          src = ./apps/marketing-service-go;
          vendorHash = "sha256-y8EArq0xwXxAzA5df1drkAbEzkwFEMXk5U4HJ67DDi4=";
        };

        # Medusa Backend (API only, no admin UI)
        medusa-backend = pkgs.buildNpmPackage {
          name = "ogt-web-medusa-backend";
          src = ./.;
          
          npmDepsHash = "sha256-0AwxfriB2atvVwy6/KMiuZ4uGUkTYrA5Epk5dyLW7RQ=";
          makeCacheWritable = true;
          npmFlags = [ "--legacy-peer-deps" ];
          dontNpmBuild = true;
          
          nativeBuildInputs = [ 
            pkgs.pkg-config 
            pkgs.python3
            pkgs.util-linux
            pkgs.nodePackages.node-gyp
          ];
          
          buildInputs = [
            pkgs.vips
            pkgs.glib
            pkgs.gcc
            pkgs.gnumake
          ];

          buildPhase = ''
            export PYTHON=${pkgs.python3}/bin/python3
            
            # Disable admin UI during build (reduces complexity, admin deployed separately)
            export MEDUSA_DISABLE_ADMIN=true
            export DATABASE_URL="postgres://mock:mock@localhost:5432/mock"
            export JWT_SECRET="build-time-secret"
            export COOKIE_SECRET="build-time-secret"
            export STRIPE_API_KEY="sk_test_mock"
            export NODE_ENV="production"
            
            npm run build --workspace=apps/medusa
          '';

          installPhase = ''
            mkdir -p $out
            cp -r apps/medusa/* $out/
            cp -r node_modules $out/node_modules
            cp package.json $out/
          '';
        };

        # Medusa Admin UI (built separately for Caddy static serving)
        medusa-admin = pkgs.buildNpmPackage {
          name = "ogt-web-medusa-admin";
          src = ./.;
          
          npmDepsHash = "sha256-0AwxfriB2atvVwy6/KMiuZ4uGUkTYrA5Epk5dyLW7RQ=";
          makeCacheWritable = true;
          npmFlags = [ "--legacy-peer-deps" ];
          dontNpmBuild = true;
          
          nativeBuildInputs = [ 
            pkgs.pkg-config 
            pkgs.python3
          ];

          buildPhase = ''
            export PYTHON=${pkgs.python3}/bin/python3
            export MEDUSA_BACKEND_URL="https://admin.ownorgasm.com"
            
            # Build admin only
            cd apps/medusa
            npx medusa build --admin-only
          '';

          installPhase = ''
            mkdir -p $out
            # Admin build output is in .medusa/admin
            cp -r apps/medusa/.medusa/admin/* $out/
          '';
        };

        };

        # =====================================================================
        # APPS (runnable scripts)
        # =====================================================================
        apps = {
          # Seed database with sample data
          seed = {
            type = "app";
            program = toString (pkgs.writeShellScript "seed" ''
              echo "Seeding Medusa database..."
              yarn seed
            '');
          };

          # Start Development Environment
          dev = {
            type = "app";
            program = toString (pkgs.writeShellScript "dev" ''
              export PATH="${pkgs.podman-compose}/bin:${pkgs.caddy}/bin:${pkgs.podman}/bin:$PATH"
              
              echo "📦 Starting Infrastructure (Postgres, Redis, MinIO)..."
              podman-compose -f infra/docker-compose.yml up -d postgres redis minio meilisearch

              echo "⏳ Waiting for DB..."
              sleep 3

              echo ""
              echo "✅ Infra Ready."
              echo "   - MinIO: http://localhost:9100 (Console: :9001)"
              echo "   - Admin: http://localhost:9000/app"
              echo "   - Storefront: http://localhost:3000 (Use Dev Switcher)"
              echo ""
              echo "🌐 Starting Caddy Proxy (Routing admin/api)..."
              caddy run --config Caddyfile.dev --adapter caddyfile
            '');
          };
        };
      }
    );
}
