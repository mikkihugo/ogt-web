# Caddy Routes module - Centralized reverse proxy configuration
{ config, lib, ... }:

with lib;

{
  options.ogt.caddy = {
    enable = mkEnableOption "OGT Caddy reverse proxy routes";
    
    domain = mkOption {
      type = types.str;
      default = "ownorgasm.com";
      description = "Primary domain for the platform";
    };
  };

  config = mkIf config.ogt.caddy.enable {
    services.caddy = {
      enable = true;
      
      virtualHosts = {
        # Main storefront
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
        
        # Medusa Admin/API
        "admin.ownorgasm.com" = {
          extraConfig = ''
            reverse_proxy localhost:9000
          '';
        };
        
        # Marketing Service API
        "api.ownorgasm.com" = {
          extraConfig = ''
            reverse_proxy localhost:8080
          '';
        };
        

      };
    };
  };
}
