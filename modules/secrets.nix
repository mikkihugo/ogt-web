# Secrets module - Centralized sops-nix configuration
{ config, lib, ... }:

with lib;

{
  options.ogt.secrets = {
    enable = mkEnableOption "OGT secrets management via sops-nix";
    
    sopsFile = mkOption {
      type = types.path;
      description = "Path to the sops secrets file";
    };
  };

  config = mkIf config.ogt.secrets.enable {
    sops = {
      defaultSopsFile = config.ogt.secrets.sopsFile;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      
      secrets = {
        # Database
        "postgres/password" = {};
        
        # Medusa
        "medusa/jwt_secret" = {};
        "medusa/cookie_secret" = {};
        
        # Stripe
        "stripe/api_key" = {};
        "stripe/webhook_secret" = {};
        
        # MinIO (matching secrets.yaml structure)
        "minio/access_key" = {};
        "minio/secret_key" = {};
        
        # Gemini AI
        "gemini/api_key" = {};
        
        # Hetzner
        "hetzner/api_token" = {};
      };
    };
  };
}
