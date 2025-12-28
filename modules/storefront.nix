{ config, lib, pkgs, self, ... }:

with lib;

let
  cfg = config.services.storefront;
  
  # Use the storefront-next package from flake packages output
  storefrontPackage = self.packages.aarch64-linux.storefront-next;
in
{
  options.services.storefront = {
    enable = mkEnableOption "Next.js Storefront";
    
    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for storefront to listen on";
    };
    
    backendUrl = mkOption {
      type = types.str;
      default = "https://admin.ownorgasm.com";
      description = "Medusa backend URL";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.storefront = {
      description = "OGT Next.js Storefront";
      after = [ "network.target" "medusa.service" ];
      wantedBy = [ "multi-user.target" ];
      
      environment = {
        NODE_ENV = "production";
        PORT = toString cfg.port;
        HOSTNAME = "0.0.0.0";
        NEXT_PUBLIC_MEDUSA_BACKEND_URL = cfg.backendUrl;
      };
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nodejs_22}/bin/node ${storefrontPackage}/server.js";
        WorkingDirectory = "${storefrontPackage}";
        Restart = "on-failure";
        RestartSec = 5;
        
        # Security hardening
        User = "storefront";
        Group = "storefront";
        DynamicUser = true;
      };
    };
  };
}
