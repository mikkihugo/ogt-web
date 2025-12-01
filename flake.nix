# =============================================================================
# OGT-Web: Medusa.js E-commerce on Fly.io with Nix
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
#   fly deploy                          # Deploy to Fly.io
#
# =============================================================================
{
  description = "OGT-Web: Medusa.js E-commerce on Fly.io";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # =====================================================================
        # DEVELOPMENT SHELL
        # =====================================================================
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Node.js runtime (Medusa requires Node 20+)
            nodejs_22
            yarn
            nodePackages.typescript
            nodePackages.typescript-language-server

            # Database
            postgresql_16

            # Deployment & DevOps
            flyctl
            docker

            # Secrets management
            git
            git-crypt
            gh  # GitHub CLI for gist management

            # Utilities
            jq
            curl
            awscli2
          ];

          shellHook = ''
            export IN_NIX_SHELL=1
            export NIX_SHELL_PROJECT="ogt-web"

            # Enable Corepack for Yarn
            corepack enable 2>/dev/null || true

            echo "🛒 OGT-Web Medusa.js Dev Shell"
            echo "Node.js $(node --version) | Yarn $(yarn --version 2>/dev/null || echo 'corepack') | PostgreSQL 16"
            echo ""
            echo "Commands:"
            echo "  yarn install     # Install dependencies"
            echo "  yarn dev         # Start development server"
            echo "  yarn build       # Build for production"
            echo "  fly deploy       # Deploy to Fly.io"
            echo ""
            echo "Secrets are managed via git-crypt and .env.encrypted only."

            # Auto-unlock git-crypt using private gist if gh is authenticated
            if command -v gh >/dev/null 2>&1 && command -v git-crypt >/dev/null 2>&1; then
              if gh auth status >/dev/null 2>&1; then
                KEY_TMP="$(mktemp)"
                if gh gist view ee80dfac1a1d7857909abc51294f8959 --raw > "$KEY_TMP" 2>/dev/null; then
                  chmod 600 "$KEY_TMP"
                  base64 -d "$KEY_TMP" > "$KEY_TMP.dec" 2>/dev/null && mv "$KEY_TMP.dec" "$KEY_TMP"
                  if git-crypt unlock "$KEY_TMP" >/dev/null 2>&1; then
                    echo "🔓 git-crypt unlocked from gist key"
                  fi
                  rm -f "$KEY_TMP" "$KEY_TMP.dec" 2>/dev/null || true
                fi
              fi
            fi
          '';
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
        };
      }
    );
}
