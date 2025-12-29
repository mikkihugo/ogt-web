# Caddy Routes module - Centralized reverse proxy configuration
{ config, lib, self, ... }:

with lib;


  let
    medusaAdmin = self.packages.aarch64-linux.medusa-admin;
  in

  {
    options.ogt.caddy = {
      enable = mkEnableOption "OGT Caddy reverse proxy routes";
      
      domain = mkOption {
        type = types.str;
        default = "orgasmtoy.com";
        description = "Primary domain for the platform";
      };
    };

    config = mkIf config.ogt.caddy.enable {
      services.caddy = {
        enable = true;
        
        virtualHosts = {
          # Main storefront (orgasmtoy.com)
          "orgasmtoy.com" = {
            extraConfig = ''
              reverse_proxy localhost:3000
            '';
          };
          
          "www.orgasmtoy.com" = {
            extraConfig = ''
              redir https://orgasmtoy.com{uri} permanent
            '';
          };

          # Blog Redirect (ownorgasm.com -> orgasmtoy.com/blog)
          "ownorgasm.com" = {
            extraConfig = ''
              redir https://orgasmtoy.com/blog permanent
            '';
          };
          
          "www.ownorgasm.com" = {
            extraConfig = ''
              redir https://orgasmtoy.com/blog permanent
            '';
          };
          
          # Medusa Admin/API (PRIMARY)
          "admin.ownorgasm.com" = {
            extraConfig = ''
              root * ${medusaAdmin}

              handle_path /app/* {
                file_server
                try_files {path} {path}/ /index.html
              }

              handle /app {
                redir /app/ permanent
              }

              handle {
                reverse_proxy localhost:9000
              }
            '';
          };

          # Admin Redirect
          "admin.orgasmtoy.com" = {
            extraConfig = ''
              redir https://admin.ownorgasm.com{uri} permanent
            '';
          };
      };
      };
    };
  }
