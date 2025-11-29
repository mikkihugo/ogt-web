# =============================================================================
# FlakeCache ogt-web - Nix Flake Configuration
# =============================================================================
#
# ARCHITECTURE:
# This flake builds a LAYERED container image using nix2container
# which streams layers directly to registry - no docker daemon needed.
#
# LAYER STRUCTURE:
# 1. Base layer: busybox, coreutils (rarely changes)
# 2. Runtime layer: PHP, Composer, MariaDB client (changes with updates)
# 3. Services layer: Traefik, Redis, exporters (rarely changes)
# 4. Application layer: Magento code (changes frequently)
#
# FLAKECACHE INTEGRATION:
# - Runners with FLAKECACHE_RUNNER=true get pre-cached /nix
# - nix-daemon enforces signature verification (require-sigs=true)
# - Builds are reproducible and content-addressed
#
# USAGE:
#   nix run .#container.copyToRegistry  # Build and push to registry
#   nix build .#container               # Build container (for local testing)
#   nix develop                         # Enter development shell
#
# =============================================================================
{
  description = "OGT-Web: Magento 2 E-commerce on Fly.io with Nix + FlakeCache";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };

  # FlakeCache binary cache configuration
  # This enables pulling pre-built derivations from cache
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      # FlakeCache substituter (when available):
      # "https://c.flakecache.com"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      # FlakeCache public key:
      # "c.flakecache.com-1:WbJFKuGbfVpBRT8FyqLrJ+EvGL6YdUrqgyj+X/FVy0I="
    ];
  };

  outputs = { self, nixpkgs, flake-utils, nix2container }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        n2c = nix2container.packages.${system}.nix2container;

        # Paths to non-repo scripts
        gitcryptGistScript = ./gitcrypt-gist.sh;
        secretsSyncScript = ./secrets-sync.sh;
        # =====================================================================
        # PHP with Magento-required extensions
        # =====================================================================
        php = pkgs.php83.buildEnv {
          extensions = { enabled, all }: enabled ++ (with all; [
            bcmath
            gd
            intl
            mbstring
            pdo_mysql
            soap
            sockets
            xsl
            zip
            redis
            opcache
          ]);
          extraConfig = ''
            memory_limit = 2G
            max_execution_time = 1800
            zlib.output_compression = On
            opcache.enable = 1
            opcache.memory_consumption = 512
            opcache.max_accelerated_files = 100000
          '';
        };

        # =====================================================================
        # Prometheus Exporters - installed via Nix (no manual downloads!)
        # This replaces the fragile curl/wget downloads in the Dockerfile
        # =====================================================================
        exporters = pkgs.symlinkJoin {
          name = "prometheus-exporters";
          paths = [
            pkgs.prometheus-php-fpm-exporter
            pkgs.prometheus-mysqld-exporter
            pkgs.prometheus-redis-exporter
          ];
        };

        # =====================================================================
        # Runtime dependencies
        # =====================================================================
        runtimePkgs = with pkgs; [
          busybox
          coreutils
          bash
          gnugrep
          gnused
          gawk
          findutils
          procps
          rsync
          socat
          curl
          bind
          unzip
          zip
          mariadb  # Full MariaDB server (includes mysql_install_db, mysqld_safe)
          python3Packages.supervisor
        ];

        # =====================================================================
        # Service binaries
        # =====================================================================
        servicePkgs = with pkgs; [
          caddy
          redis
        ];

        # =====================================================================
        # Container root filesystem
        # =====================================================================
        # writeShellScriptBin creates a derivation with the script at $out/bin/start.sh
        startScript = pkgs.writeShellScriptBin "start.sh" (builtins.readFile ./docker/start.sh);

        # buildEnv creates a unified filesystem by symlinking paths together.
        # This follows the official nix2container pattern (see examples/bash.nix).
        #
        # When we want tools in /, we use symlinks to avoid duplicating files
        # between / and /nix/store. This preserves library dependencies while
        # providing executables at standard paths like /bin.
        #
        # pathsToLink = ["/bin"] tells buildEnv to symlink ALL /bin directories
        # from the input paths into a single /bin in the output derivation.
        # So startScript's /bin/start.sh becomes accessible at /bin/start.sh
        # in the container root.
        #
        # Reference: https://github.com/nlewo/nix2container/blob/master/examples/bash.nix
        rootWithEntrypoint = pkgs.buildEnv {
          name = "root";
          paths = runtimePkgs ++ servicePkgs ++ [
            php
            php.packages.composer
            exporters
            startScript  # Provides /bin/start.sh
            caddyConfig
            supervisordConfig
            magentoTheme
          ];
          pathsToLink = [ "/bin" "/lib" "/share" "/etc" "/tmp" ];
        };

        caddyConfig = pkgs.runCommand "caddy-config" {} ''
          mkdir -p $out/etc/caddy
          cp -r ${./docker/caddy}/* $out/etc/caddy/
        '';

        supervisordConfig = pkgs.writeTextDir "etc/supervisord.conf" (builtins.readFile ./docker/supervisord.conf);

        # Conditionally install Magento theme only if Composer keys are present
        magentoTheme = pkgs.runCommand "magento-theme" {
          COMPOSER_MAGENTO_USERNAME = if builtins.getEnv "COMPOSER_MAGENTO_USERNAME" != null then builtins.getEnv "COMPOSER_MAGENTO_USERNAME" else "";
          COMPOSER_MAGENTO_PASSWORD = if builtins.getEnv "COMPOSER_MAGENTO_PASSWORD" != null then builtins.getEnv "COMPOSER_MAGENTO_PASSWORD" else "";
        } ''
          if [ -n "$COMPOSER_MAGENTO_USERNAME" ] && [ -n "$COMPOSER_MAGENTO_PASSWORD" ]; then
            mkdir -p $out/tmp/magento-theme
            cp -r ${./magento-theme}/* $out/tmp/magento-theme/
          else
            mkdir -p $out/tmp/magento-theme
            echo "Dummy Magento theme (no secrets)" > $out/tmp/magento-theme/README.txt
          fi
        '';

      in
      {
        # =====================================================================
        # PACKAGES
        # =====================================================================
        packages = {
          # -------------------------------------------------------------------
          # nix2container Image (RECOMMENDED)
          # Streams layers directly to registry - no docker daemon needed
          # -------------------------------------------------------------------
          # IMPORTANT: nix2container config follows the OCI image spec exactly.
          # Field names MUST be capitalized (Cmd, Env, ExposedPorts, WorkingDir).
          # Do NOT use lowercase (cmd, env) or Docker-style (entrypoint) - these will fail.
          #
          # Use Cmd (not entrypoint) for the container command. Both set the default
          # command, but nix2container uses OCI spec naming.
          #
          # Reference: https://github.com/nlewo/nix2container/blob/master/examples/nginx.nix
          container = n2c.buildImage {
            name = "registry.fly.io/ogt-web";
            tag = builtins.substring 0 8 (self.rev or "dev");
            maxLayers = 100;
            copyToRoot = rootWithEntrypoint;
            config = {
              # Default command - executes /bin/start.sh from rootWithEntrypoint
              Cmd = [ "/bin/start.sh" ];
              # Environment variables (OCI spec capitalization)
              Env = [
                "PATH=${pkgs.lib.makeBinPath (runtimePkgs ++ servicePkgs ++ [ php php.packages.composer exporters ])}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
                "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ php pkgs.openssl pkgs.icu pkgs.zlib ]}"
                "PHP_FPM_PM=dynamic"
                "PHP_FPM_PM_MAX_CHILDREN=50"
              ];
              # Exposed ports (OCI spec capitalization)
              ExposedPorts = {
                "8080/tcp" = {};
              };
              # Working directory (OCI spec capitalization)
              WorkingDir = "/var/www/html";
            };
          };

          # Default package
          default = self.packages.${system}.container;

          # Individual components (for debugging/testing)
          inherit php exporters;
        };

        # =====================================================================
        # DEVELOPMENT SHELL
        # =====================================================================
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            php
            php.packages.composer
            mariadb-client
            traefik
            redis
            git
            git-crypt
            gh  # GitHub CLI for gist management
            kubectl
            kubernetes-helm
            flyctl
            awscli2
            podman
            skopeo
            shadow  # provides newuidmap/newgidmap for rootless containers
          ];

          shellHook = ''
            export IN_NIX_SHELL=1
            export NIX_SHELL_PROJECT="ogt-web"
            echo "🐳 OGT-Web Nix Shell"
            echo "PHP 8.3 | Composer | MySQL 10.11 | Caddy | Flyctl"
            echo ""
            echo "Commands:"
            echo "  nix build .#container   # Build Docker image"
            echo "  git push origin master  # Deploy"
            echo "  fly logs --follow       # Monitor"
            echo ""
            echo "Secrets are managed via git-crypt and .env.encrypted only."
          '';
        };

        # =====================================================================
        # APPS (runnable scripts)
        # =====================================================================
        apps = {
          # Build and load to local Docker
          load-container = {
            type = "app";
            program = toString (pkgs.writeShellScript "load-container" ''
              echo "Building layered container..."
              nix build .#container
              echo "Loading to Docker..."
              docker load < result
              echo "Done! Image: ogt-web:latest"
            '');
          };

          sync-media = {
            type = "app";
            program = "${pkgs.writeShellApplication {
              name = "sync-media";
              runtimeInputs = [ pkgs.awscli2 ];
              text = ''
                set -euo pipefail
                : "''${S3_BUCKET:?Set S3_BUCKET (bucket name)}"
                SRC=''${1:-pub/media}
                DEST="s3://''${S3_BUCKET%/}/media/"

                args=()
                if [ -n "''${S3_REGION:-}" ]; then
                  args+=(--region "''${S3_REGION}")
                fi
                if [ -n "''${S3_ENDPOINT:-}" ]; then
                  args+=(--endpoint-url "''${S3_ENDPOINT}")
                fi

                aws s3 sync "$SRC" "$DEST" --delete "''${args[@]}"
              '';
            }}/bin/sync-media";
          };

          restore-media = {
            type = "app";
            program = "${pkgs.writeShellApplication {
              name = "restore-media";
              runtimeInputs = [ pkgs.awscli2 ];
              text = ''
                set -euo pipefail
                : "''${S3_BUCKET:?Set S3_BUCKET (bucket name)}"
                SRC="s3://''${S3_BUCKET%/}/media/"
                DEST=''${1:-pub/media}

                args=()
                if [ -n "''${S3_REGION:-}" ]; then
                  args+=(--region "''${S3_REGION}")
                fi
                if [ -n "''${S3_ENDPOINT:-}" ]; then
                  args+=(--endpoint-url "''${S3_ENDPOINT}")
                fi

                aws s3 sync "$SRC" "$DEST" "''${args[@]}"
              '';
            }}/bin/restore-media";
          };
        };

        # Non-repo scripts for secrets and key management
        scripts = {
          gitcryptGist = ./gitcrypt-gist.sh;
          secretsSync = ./secrets-sync.sh;
        };
      }
    );
}
