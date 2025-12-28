# Storage module - MinIO S3-compatible object storage
{ config, lib, ... }:

with lib;

{
  options.ogt.storage = {
    enable = mkEnableOption "OGT object storage (MinIO)";
    
    listenPort = mkOption {
      type = types.port;
      default = 9100;
      description = "MinIO API port";
    };
    
    consolePort = mkOption {
      type = types.port;
      default = 9101;
      description = "MinIO console port";
    };
  };

  config = mkIf config.ogt.storage.enable {
    services.minio = {
      enable = true;
      listenAddress = "127.0.0.1:${toString config.ogt.storage.listenPort}";
      consoleAddress = "127.0.0.1:${toString config.ogt.storage.consolePort}";
      rootCredentialsFile = config.sops.secrets."minio/root_password".path;
    };
  };
}
