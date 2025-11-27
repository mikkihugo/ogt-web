# =============================================================================
# FlakeCache Magneto-Web - Nix Flake Configuration
# =============================================================================
#
# ARCHITECTURE:
# This flake builds a LAYERED container image using dockerTools.buildLayeredImage
# which provides optimal layer caching - only changed layers need to rebuild.
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
#   nix build .#container        # Build layered container
#   nix build .#container-stream # Build streamable container (for large images)
#   nix develop                  # Enter development shell
#
# =============================================================================
{
  description = "Magento 2 Hyper-converged Deployment on Fly.io with FlakeCache";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

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
          mariadb-client
        ];

        # =====================================================================
        # Service binaries
        # =====================================================================
        servicePkgs = with pkgs; [
          traefik
          redis
        ];

      in
      {
        # =====================================================================
        # PACKAGES
        # =====================================================================
        packages = {
          # -------------------------------------------------------------------
          # Layered Container Image (RECOMMENDED)
          # Uses buildLayeredImage for optimal layer caching
          # Each Nix store path becomes a separate layer
          # -------------------------------------------------------------------
          container = pkgs.dockerTools.buildLayeredImage {
            name = "ogt-app";
            tag = "latest";

            # Maximum 125 layers (Docker limit), Nix optimizes automatically
            maxLayers = 100;

            contents = runtimePkgs ++ servicePkgs ++ [
              php
              php.packages.composer
              exporters
            ];

            extraCommands = ''
              # Create required directories
              mkdir -p var/www/html
              mkdir -p var/lib/mysql
              mkdir -p etc/my.cnf.d
              mkdir -p etc/traefik
              mkdir -p etc/php/conf.d
              mkdir -p usr/local/bin
              mkdir -p run
              mkdir -p tmp
              chmod 1777 tmp
            '';

            config = {
              Cmd = [ "/start.sh" ];
              Env = [
                "PATH=${pkgs.lib.makeBinPath (runtimePkgs ++ servicePkgs ++ [ php php.packages.composer exporters ])}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
                "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ php pkgs.openssl pkgs.icu pkgs.zlib ]}"
                "PHP_FPM_PM=dynamic"
                "PHP_FPM_PM_MAX_CHILDREN=50"
              ];
              ExposedPorts."8080/tcp" = { };
              WorkingDir = "/var/www/html";
            };
          };

          # Default package
          default = self.packages.${system}.container;

          # -------------------------------------------------------------------
          # Streamable Container (for very large images)
          # Streams layers directly without loading full image into memory
          # -------------------------------------------------------------------
          container-stream = pkgs.dockerTools.streamLayeredImage {
            name = "ogt-app";
            tag = "latest";
            maxLayers = 100;
            contents = runtimePkgs ++ servicePkgs ++ [
              php
              php.packages.composer
              exporters
            ];
            config = {
              Cmd = [ "/start.sh" ];
              Env = [
                "PATH=${pkgs.lib.makeBinPath (runtimePkgs ++ servicePkgs ++ [ php php.packages.composer exporters ])}"
              ];
              ExposedPorts."8080/tcp" = { };
              WorkingDir = "/var/www/html";
            };
          };

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
            kubectl
            kubernetes-helm
            flyctl
          ];

          shellHook = ''
            echo ""
            echo "=== Magneto-Web Development Shell ==="
            echo "PHP: $(php --version | head -1)"
            echo "Composer: $(composer --version 2>/dev/null | head -1)"
            echo ""
            echo "Build commands:"
            echo "  nix build .#container         # Build layered image"
            echo "  nix build .#container-stream  # Build streamable image"
            echo ""
            echo "Load to Docker:"
            echo "  docker load < result"
            echo ""
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
              echo "Done! Image: ogt-app:latest"
            '');
          };
        };
      }
    );
}
