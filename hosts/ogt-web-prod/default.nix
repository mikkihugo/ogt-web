{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ./networking.nix
    # OGT infrastructure modules
    ../../modules/secrets.nix
    ../../modules/database.nix
    ../../modules/storage.nix
    ../../modules/caddy-routes.nix
    # OGT application modules
    ../../modules/medusa.nix
    ../../modules/storefront.nix
    ../../modules/marketing-service.nix
    ../../modules/strapi.nix
    ../../modules/monitoring.nix
    # External modules
    inputs.sops-nix.nixosModules.sops
  ];

  # ==========================================================================
  # SYSTEM CONFIGURATION
  # ==========================================================================
  
  system.stateVersion = "24.11";
  time.timeZone = "UTC";
  zramSwap.enable = true;
  
  boot.tmp.cleanOnBoot = true;

  # Nix Configuration
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true; # Deduplicate files
  nix.settings.cores = 3; # Reserve 1 core (System has 4)
  nix.settings.max-jobs = 1; # Sequential builds to save RAM
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMr2NP6jp8cv7LngufhEP6nAlpF3rv5lnr1ngW3fy3C mhugo@portal-automation"
  ];

  # ==========================================================================
  # INFRASTRUCTURE (via ogt.* modules)
  # ==========================================================================
  
  ogt = {
    secrets = {
      enable = true;
      sopsFile = ../../secrets/secrets.yaml;
    };
    database.enable = true;
    storage.enable = true;
    caddy.enable = true;
    monitoring.enable = true;
  };

  # ==========================================================================
  # SERVICES
  # ==========================================================================
  
  services = {
    # SSH access
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };
    
    # Caddy email
    caddy.email = "support@orgasmtoy.com";
    
    # Application services
    medusa = {
      enable = true;
      port = 9000;
      databaseUrl = "postgres://medusa@localhost/medusa";
    };
    
    storefront = {
      enable = true;
      port = 3000;
      backendUrl = "https://admin.orgasmtoy.com";
    };
    
    marketing-service = {
      enable = true;
      port = 8080;
    };
    
    # Strapi - TODO: needs Nix package like medusa
    # strapi = {
    #   enable = true;
    #   port = 1337;
    #   databaseUrl = "postgres://strapi@localhost/strapi";
    # };
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
    sops
  ];
}
