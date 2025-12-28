# Database module - PostgreSQL + Redis configuration
{ config, lib, pkgs, ... }:

with lib;

{
  options.ogt.database = {
    enable = mkEnableOption "OGT database services (PostgreSQL + Redis)";
    
    databases = mkOption {
      type = types.listOf types.str;
      default = [ "medusa" "strapi" "marketing" ];
      description = "Databases to create";
    };
  };

  config = mkIf config.ogt.database.enable {
    services = {
      # PostgreSQL 18
      postgresql = {
        enable = true;
        package = pkgs.postgresql_18;
        
        ensureDatabases = config.ogt.database.databases;
        ensureUsers = map (db: { name = db; ensureDBOwnership = true; }) config.ogt.database.databases
          ++ [{ name = "postgres"; }];
        
        authentication = pkgs.lib.mkOverride 10 ''
          local all all trust
          host all all 127.0.0.1/32 md5
          host all all ::1/128 md5
        '';
      };
      
      # Redis
      redis.servers.default = {
        enable = true;
        port = 6379;
        bind = "127.0.0.1";
      };
    };
  };
}
