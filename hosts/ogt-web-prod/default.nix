{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ./networking.nix
    # OGT modules
    ../../modules/secrets.nix
    ../../modules/caddy-routes.nix
    ../../modules/medusa.nix
    ../../modules/storefront.nix
    ../../modules/marketing-service.nix
    ../../modules/strapi.nix
    # External modules
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
  # SECRETS (via ogt.secrets module)
  # ==========================================================================
  
  ogt.secrets.enable = true;

  # ==========================================================================
  # POSTGRESQL
  # ==========================================================================
  
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;
    
    ensureDatabases = [ "medusa" "strapi" "marketing" ];
    ensureUsers = [
      { name = "medusa"; ensureDBOwnership = true; }
      { name = "strapi"; ensureDBOwnership = true; }
      { name = "postgres"; }  # For marketing-service
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
    listenAddress = "127.0.0.1:9100";
    consoleAddress = "127.0.0.1:9101";
    rootCredentialsFile = config.sops.secrets."minio/root_password".path;
  };

  # ==========================================================================
  # CADDY (via ogt.caddy module)
  # ==========================================================================
  
  ogt.caddy.enable = true;
  services.caddy.email = "support@ownorgasm.com";

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
  
  services.strapi = {
    enable = true;
    port = 1337;
    databaseUrl = "postgres://strapi@localhost/strapi";
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
