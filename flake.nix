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
  description = "OGT-Web: Medusa.js E-commerce on Hetzner with Docker";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  outputs = { self, nixpkgs, flake-utils, nix2container }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        nix2containerPkgs = nix2container.packages.${system};
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
            docker
            docker-compose

            # Secrets management
            git
            git-crypt
            gh  # GitHub CLI for gist management

            # Utilities
            jq
            curl
            jq
            curl
            awscli2

            # Go Development
            go
            gopls

            # Node for Admin
            nodejs_20
            pnpm

            # Build System
            bazelisk
          ];

          shellHook = ''
            export IN_NIX_SHELL=1
            export NIX_SHELL_PROJECT="ogt-web"
            export GOPROXY=https://proxy.golang.org,direct

            # Corepack disabled to prevent read-only filesystem errors
            # corepack enable 2>/dev/null || true

            echo "🛒 OGT-Web Medusa.js Dev Shell"
            echo "Node.js $(node --version) | Yarn $(yarn --version 2>/dev/null || echo 'corepack') | PostgreSQL 18 (GIS, Timescale, Vector, Trigram, Cron)"
            echo ""
            echo "Commands:"
            echo "  yarn install     # Install dependencies"
            echo "  yarn dev         # Start development server"
            echo "  yarn build       # Build for production"
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
        # PACKAGES
        # =====================================================================
        packages = {
          dockerImage = nix2containerPkgs.nix2container.buildImage {
            name = "ogt-web-backend";
            tag = "latest";
            config = {
              Cmd = [ "yarn" "start" ];
              Env = [
                "NODE_ENV=production"
                "PORT=9000"
              ];
              ExposedPorts = {
                "9000/tcp" = {};
              };
              WorkingDir = "/app";
            };
            maxLayers = 120;
            layers = [
              (nix2containerPkgs.nix2container.buildLayer {
                deps = with pkgs; [ nodejs_20 yarn bashInteractive ];
              })
              (nix2containerPkgs.nix2container.buildLayer {
                 # Copy the entire Medusa app to /app
                 copyToRoot = [
                   (pkgs.runCommand "medusa-source" {} ''
                     mkdir -p $out/app
                     cp -r ${./apps/medusa}/* $out/app/
                   '')
                 ];
              })
            ];
            # Basic implementation for now - just the runtime environment
            # Real application code adding requires more structure.
          };

          chatwootImage = nix2containerPkgs.nix2container.pullImage {
            imageName = "chatwoot/chatwoot";
            imageDigest = "sha256:ce7f650dcda73ad81e96023a5eb9825750e3de67c103d75496b1d28b825fb2ab";
            sha256 = "sha256-e8NLJvxasUnGrKY4StepxtT7CevQmS6B8Lf8/edn23w="; 
          };

          caddyImage = nix2containerPkgs.nix2container.buildImage {
            name = "ogt-web-proxy";
            tag = "latest";
            config = {
              Cmd = [ "caddy" "run" "--config" "/etc/caddy/Caddyfile" "--adapter" "caddyfile" ];
              ExposedPorts = {
                "80/tcp" = {};
                "443/tcp" = {};
              };
            };
            layers = [
              (nix2containerPkgs.nix2container.buildLayer {
                deps = with pkgs; [ caddy ];
              })
              (nix2containerPkgs.nix2container.buildLayer {
                copyToRoot = [
                  (pkgs.runCommand "caddy-config" {} ''
                    mkdir -p $out/etc/caddy
                    cp ${./Caddyfile} $out/etc/caddy/Caddyfile
                  '')
                ];
              })
            ];
          };

          unifiedImage = nix2containerPkgs.nix2container.buildImage {
              name = "unified-platform";
              tag = "latest";
              copyToRoot = [ 
                (pkgs.buildEnv {
                  name = "root";
                  paths = [ self.packages.${system}.marketing-service self.packages.${system}.storefront-next pkgs.cacert ];
                  pathsToLink = [ "/bin" "/etc/ssl/certs" ];
                })
              ];
              config = {
                # Multi-process container or just one entrypoint?
                # For unified image, we might want a supervisor, but for now let's default to the Go service
                Cmd = [ "/bin/marketing-service" ]; 
                Env = [ "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt" ];
              };
            };

          # 1. Build Go Marketing Service
          marketing-service = pkgs.buildGoModule {
            pname = "marketing-service";
            version = "1.0.0";
            src = ./apps/marketing-service-go;
            vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          };

          # 2. Build Next.js Storefront (Static/Standalone)
          storefront-next = pkgs.buildNpmPackage {
            pname = "storefront-next";
            version = "1.0.0";
            src = ./apps/storefront-next;
            # Dummy hash for now, update after first failure
            npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; 
            # Bypass build for scaffold if lockfile missing
            dontNpmBuild = true; 
            installPhase = "cp -r . $out";
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
              export PATH="${pkgs.docker-compose}/bin:${pkgs.caddy}/bin:${pkgs.docker}/bin:$PATH"
              
              echo "📦 Starting Infrastructure (Postgres, Redis, MinIO)..."
              docker-compose -f infra/docker-compose.yml up -d postgres redis minio meilisearch

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
