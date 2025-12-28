{ config, lib, pkgs, self, ... }:

with lib;

let
  cfg = config.services.medusa;
  
  # Use the medusa package from flake packages output
  medusaPackage = self.packages.aarch64-linux.medusa or null;
in
{
  options.services.medusa = {
    enable = mkEnableOption "Medusa e-commerce backend";
    
    port = mkOption {
      type = types.port;
      default = 9000;
      description = "Port for Medusa to listen on";
    };
    
    databaseUrl = mkOption {
      type = types.str;
      default = "postgres://medusa@localhost/medusa";
      description = "PostgreSQL connection URL";
    };
    
    redisUrl = mkOption {
      type = types.str;
      default = "redis://localhost:6379";
      description = "Redis connection URL";
    };
  };

  config = mkIf cfg.enable {
    # Medusa requires npm to run - use a wrapper script
    systemd.services.medusa = {
      description = "Medusa E-commerce Backend";
      after = [ "network.target" "postgresql.service" "redis-default.service" ];
      wantedBy = [ "multi-user.target" ];
      
      environment = {
        NODE_ENV = "production";
        PORT = toString cfg.port;
        DATABASE_URL = cfg.databaseUrl;
        REDIS_URL = cfg.redisUrl;
        STORE_CORS = "https://ownorgasm.com,https://www.ownorgasm.com";
        ADMIN_CORS = "https://admin.ownorgasm.com";
        AUTH_CORS = "https://ownorgasm.com,https://admin.ownorgasm.com";
        MEDUSA_BACKEND_URL = "https://admin.ownorgasm.com";
      };
      
      serviceConfig = {
        Type = "simple";
        # For now, Medusa needs to be cloned and built on the server
        # TODO: Create proper Nix package for Medusa
        ExecStart = "${pkgs.nodejs_22}/bin/npx medusa start";
        WorkingDirectory = "/var/lib/medusa";
        Restart = "on-failure";
        RestartSec = 5;
        
        # Security hardening
        User = "medusa";
        Group = "medusa";
        DynamicUser = true;
        StateDirectory = "medusa";
        
        # Secrets via sops-nix
        EnvironmentFile = [
          config.sops.secrets."medusa/jwt_secret".path
          config.sops.secrets."medusa/cookie_secret".path
          config.sops.secrets."stripe/api_key".path
        ];
      };
    };
  };
}
