{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ./networking.nix
    ../../modules/medusa.nix
    ../../modules/storefront.nix
    ../../modules/marketing-service.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # ==========================================================================
  # SYSTEM CONFIGURATION
  # ==========================================================================
  
  system.stateVersion = "24.11";
  
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  
  time.timeZone = "UTC";
  
  # SSH access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };
  
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMr2NP6jp8cv7LngufhEP6nAlpF3rv5lnr1ngW3fy3C mhugo@portal-automation"
  ];

  # ==========================================================================
  # SECRETS (sops-nix)
  # ==========================================================================
  
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    
    secrets = {
      "postgres/password" = {};
      "medusa/jwt_secret" = {};
      "medusa/cookie_secret" = {};
      "stripe/api_key" = {};
      "stripe/webhook_secret" = {};
      "minio/secret_key" = {};
    };
  };

  # ==========================================================================
  # POSTGRESQL
  # ==========================================================================
  
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;
    
    ensureDatabases = [ "medusa" "strapi" ];
    ensureUsers = [
      { name = "medusa"; ensureDBOwnership = true; }
      { name = "strapi"; ensureDBOwnership = true; }
    ];
    
    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host all all 127.0.0.1/32 md5
      host all all ::1/128 md5
    '';
  };

  # ==========================================================================
  # REDIS
  # ==========================================================================
  
  services.redis.servers.default = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1";
  };

  # ==========================================================================
  # MINIO (S3-compatible storage)
  # ==========================================================================
  
  services.minio = {
    enable = true;
    listenAddress = "127.0.0.1:9000";
    consoleAddress = "127.0.0.1:9001";
    rootCredentialsFile = config.sops.secrets."minio/secret_key".path;
  };

  # ==========================================================================
  # CADDY (Reverse Proxy with automatic HTTPS)
  # ==========================================================================
  
  services.caddy = {
    enable = true;
    email = "support@ownorgasm.com";
    
    virtualHosts = {
      "ownorgasm.com" = {
        extraConfig = ''
          reverse_proxy localhost:3000
        '';
      };
      
      "www.ownorgasm.com" = {
        extraConfig = ''
          redir https://ownorgasm.com{uri} permanent
        '';
      };
      
      "admin.ownorgasm.com" = {
        extraConfig = ''
          reverse_proxy localhost:9000
        '';
      };
      
      "minio.ownorgasm.com" = {
        extraConfig = ''
          reverse_proxy localhost:9100
        '';
      };
    };
  };

  # ==========================================================================
  # APPLICATION SERVICES
  # ==========================================================================
  
  services.medusa = {
    enable = true;
    port = 9000;
    databaseUrl = "postgres://medusa@localhost/medusa";
  };
  
  services.storefront = {
    enable = true;
    port = 3000;
    backendUrl = "https://admin.ownorgasm.com";
  };
  
  services.marketing-service = {
    enable = true;
    port = 8080;
  };

  # ==========================================================================
  # PACKAGES
  # ==========================================================================
  
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    jq
  ];
}
