{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.strapi;
in
{
  options.services.strapi = {
    enable = mkEnableOption "Strapi CMS";
    
    port = mkOption {
      type = types.port;
      default = 1337;
      description = "Port for Strapi to listen on";
    };
    
    databaseUrl = mkOption {
      type = types.str;
      default = "postgres://strapi@localhost/strapi";
      description = "PostgreSQL connection URL";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.strapi = {
      description = "Strapi CMS";
      after = [ "network.target" "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      
      environment = {
        NODE_ENV = "production";
        PORT = toString cfg.port;
        HOST = "0.0.0.0";
        DATABASE_URL = cfg.databaseUrl;
        APP_KEYS = "toBeModified1,toBeModified2";
        API_TOKEN_SALT = "toBeModified";
        ADMIN_JWT_SECRET = "toBeModified";
        TRANSFER_TOKEN_SALT = "toBeModified";
        JWT_SECRET = "toBeModified";
      };
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nodejs_22}/bin/npm run start";
        WorkingDirectory = "/var/lib/strapi";
        Restart = "on-failure";
        RestartSec = 5;
        
        # Security hardening
        User = "strapi";
        Group = "strapi";
        DynamicUser = true;
        StateDirectory = "strapi";
      };
    };
  };
}
