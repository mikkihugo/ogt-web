{
  description = "Magento 2 Hyper-converged Deployment on Fly.io";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.dockerTools.buildImage {
          name = "magneto-orgasmtoy";
          tag = "latest";
          fromImage = null;
          
          config = {
            Cmd = [ "/start.sh" ];
            Env = [
              "PATH=${pkgs.lib.makeBinPath [
                pkgs.busybox
                pkgs.php83
                pkgs.php83Packages.composer
                pkgs.mariadb
                pkgs.traefik
                pkgs.redis
              ]}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
              "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
                pkgs.php83
                pkgs.mariadb
                pkgs.openssl
                pkgs.icu
              ]}"
            ];
            ExposedPorts."8080/tcp" = { };
            WorkingDir = "/var/www/html";
          };

          contents = with pkgs; [
            busybox
            php83
            php83Packages.composer
            mariadb
            traefik
            redis
            bind
            procps
            rsync
            socat
            unzip
            zip
          ];

          extraCommands = ''
            mkdir -p var/www/html
            mkdir -p var/lib/mysql
            mkdir -p etc/my.cnf.d
            mkdir -p etc/nginx
            mkdir -p etc/php/conf.d
            mkdir -p usr/local/bin
          '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            php83
            php83Packages.composer
            mariadb
            traefik
            redis
            git
          ];
        };
      }
    );
}
