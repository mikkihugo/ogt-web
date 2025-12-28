{ config, lib, pkgs, self, ... }:

with lib;

let
  cfg = config.services.medusa;
  
  # Use the backend-only medusa package (no admin UI)
  medusaPackage = self.packages.aarch64-linux.medusa-backend;
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
        HOME = "/var/lib/medusa";
        npm_config_cache = "/var/lib/medusa/.npm";
      };
      
      # Use the pre-built medusa package
      script = ''
        cd ${medusaPackage}
        exec ${pkgs.nodejs_22}/bin/node node_modules/@medusajs/medusa/dist/index.js start
      '';
      
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = "/var/lib/medusa";
        Restart = "on-failure";
        RestartSec = 5;
        
        # Security hardening
        User = "medusa";
        Group = "medusa";
        DynamicUser = true;
        StateDirectory = "medusa";
        CacheDirectory = "medusa";
        
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
