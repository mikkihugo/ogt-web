# Secrets module - Centralized sops-nix configuration
{ config, lib, ... }:

with lib;

{
  options.ogt.secrets = {
    enable = mkEnableOption "OGT secrets management via sops-nix";
  };

  config = mkIf config.ogt.secrets.enable {
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
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
        
        # MinIO
        "minio/root_user" = {};
        "minio/root_password" = {};
        
        # Gemini AI
        "gemini/api_key" = {};
        
        # Hetzner
        "hetzner/api_token" = {};
      };
    };
  };
}
