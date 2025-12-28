{ config, lib, self, ... }:

with lib;

let
  cfg = config.services.marketing-service;
  
  # Use the Go marketing service package from flake packages output
  # This is passed via specialArgs from the flake
  marketingPackage = self.packages.aarch64-linux.marketing-service;
in
{
  options.services.marketing-service = {
    enable = mkEnableOption "Go Marketing Service";
    
    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port for marketing service to listen on";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.marketing-service = {
      description = "OGT Marketing Service (Go)";
      after = [ "network.target" "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      
      environment = {
        PORT = toString cfg.port;
      };
      
      script = ''
        export DATABASE_URL="postgres://postgres:$(cat /run/secrets/postgres_password)@localhost:5432/marketing"
        exec ${marketingPackage}/bin/marketing-service
      '';
      
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        
        # Security hardening
        User = "marketing";
        Group = "marketing";
        DynamicUser = true;
      };
    };
  };
}
