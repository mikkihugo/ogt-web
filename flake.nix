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
# 4. Application layer: Magento code + theme (changes frequently)
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
        # Static busybox for container entrypoint (no dynamic linker needed)
        # Copy the actual binary to /bin/busybox to avoid broken symlinks
        # =====================================================================
        staticBusyboxBin = pkgs.runCommand "busybox-bin" {} ''
          mkdir -p $out/bin
          cp ${pkgs.pkgsStatic.busybox}/bin/busybox $out/bin/busybox
          chmod +x $out/bin/busybox
          # Also create ash symlink (don't create /bin/sh - bash provides that)
          ln -s busybox $out/bin/ash
        '';
        staticBusybox = pkgs.pkgsStatic.busybox;

        # Create a root filesystem layer with /bin/ at the actual root
        # This is needed because nix2container copyToRoot places things under /nix/store
        fhsLayer = pkgs.runCommand "fhs-layer" {} ''
          mkdir -p $out/bin
          mkdir -p $out/lib64
          # Copy static busybox directly to /bin/
          cp ${pkgs.pkgsStatic.busybox}/bin/busybox $out/bin/busybox
          chmod +x $out/bin/busybox
          ln -s busybox $out/bin/ash
          # Create start.sh script that uses busybox ash
          echo '#!/bin/busybox ash' > $out/bin/start.sh
          tail -n +2 ${./docker/start.sh} >> $out/bin/start.sh
          chmod +x $out/bin/start.sh
          # Copy glibc dynamic linker for other binaries
          ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $out/lib64/ld-linux-x86-64.so.2
        '';

        # =====================================================================
        # Runtime dependencies
        # =====================================================================
        runtimePkgs = with pkgs; [
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
        # Create start.sh script with static busybox shebang (no dynamic linker needed)
        startScript = pkgs.runCommand "start-script" {} ''
          mkdir -p $out/bin
          # Use static busybox ash as interpreter - works without /lib64/ld-linux
          echo '#!${staticBusybox}/bin/ash' > $out/bin/start.sh
          # Append the rest of the script (skip the original shebang line)
          tail -n +2 ${./docker/start.sh} >> $out/bin/start.sh
          chmod +x $out/bin/start.sh
        '';

        # FHS compatibility symlinks (required for /bin/bash shebang to work)
        fhsCompat = pkgs.runCommand "fhs-compat" {} ''
          mkdir -p $out/lib64
          ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $out/lib64/ld-linux-x86-64.so.2
        '';

        # Merge all runtime dependencies
        # Note: busybox and start.sh are provided by fhsLayer which places them at /bin/ root
        rootEnv = pkgs.buildEnv {
          name = "root";
          paths = runtimePkgs ++ servicePkgs ++ [
            php
            php.packages.composer
            exporters
            caddyConfig
            supervisordConfig
            magentoTheme
            # startScript and staticBusyboxBin removed - provided by fhsLayer at actual /bin/
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

        # Pre-install Magento core if Composer credentials are available
        magentoCore = let
          hasCreds = (builtins.getEnv "COMPOSER_MAGENTO_USERNAME" != null && builtins.getEnv "COMPOSER_MAGENTO_USERNAME" != "") &&
                     (builtins.getEnv "COMPOSER_MAGENTO_PASSWORD" != null && builtins.getEnv "COMPOSER_MAGENTO_PASSWORD" != "");
        in
          if hasCreds then
            pkgs.runCommand "magento-core" {
              COMPOSER_MAGENTO_USERNAME = builtins.getEnv "COMPOSER_MAGENTO_USERNAME";
              COMPOSER_MAGENTO_PASSWORD = builtins.getEnv "COMPOSER_MAGENTO_PASSWORD";
              nativeBuildInputs = [ php php.packages.composer ];
            } ''
              mkdir -p $out/var/www/html

              # Configure Composer auth
              export HOME=$TMPDIR
              composer config --global http-basic.repo.magento.com \
                "$COMPOSER_MAGENTO_USERNAME" "$COMPOSER_MAGENTO_PASSWORD"

              # Install Magento in the output directory
              cd $out/var/www/html
              composer create-project --repository-url=https://repo.magento.com/ \
                magento/project-community-edition . --no-interaction

              # Install custom theme and modules
              if [ -d "${magentoTheme}/tmp/magento-theme" ]; then
                # Theme
                mkdir -p app/design/frontend/Msgnet/msgnet2
                cp -r ${magentoTheme}/tmp/magento-theme/* app/design/frontend/Msgnet/msgnet2/
                rm -rf app/design/frontend/Msgnet/msgnet2/Klarna_Checkout
                rm -rf app/design/frontend/Msgnet/msgnet2/Stripe_Checkout

                # Modules
                mkdir -p app/code/Klarna/Checkout
                cp -r ${magentoTheme}/tmp/magento-theme/Klarna_Checkout/* app/code/Klarna/Checkout/

                mkdir -p app/code/Stripe/Checkout
                cp -r ${magentoTheme}/tmp/magento-theme/Stripe_Checkout/* app/code/Stripe/Checkout/
              fi

              # Set proper permissions
              chown -R www-data:www-data $out/var/www/html
            ''
          else
            pkgs.runCommand "magento-core-dummy" {} ''
              mkdir -p $out
              echo "Magento core not prebuilt - no Composer credentials" > $out/README.txt
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
          # Enforce x86_64-linux for Fly image builds to prevent accidental arm pushes
          container = assert pkgs.stdenv.hostPlatform.system == "x86_64-linux";
            n2c.buildImage {
            name = "registry.fly.io/ogt-web";
            # Use an explicit amd64 suffix to avoid tag collisions with local arm builds
            tag = "v8-fhs";
            # Use multiple layers for better caching
            maxLayers = 100;
            # fhsLayer provides /bin/busybox at the actual root filesystem
            copyToRoot = [ rootEnv magentoCore fhsLayer ];
            config = {
              # Use full nix store paths - copyToRoot does NOT strip the prefix
              Cmd = [ "${fhsLayer}/bin/busybox" "ash" "${fhsLayer}/bin/start.sh" ];
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
