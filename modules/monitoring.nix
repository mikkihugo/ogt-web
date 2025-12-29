{ config, lib, pkgs, ... }:

with lib;

{
  options.ogt.monitoring = {
    enable = mkEnableOption "OGT Monitoring Stack (Prometheus + Exporters)";
  };

  config = mkIf config.ogt.monitoring.enable {
    
    # ==========================================================================
    # PROMETHEUS (The Brain)
    # ==========================================================================
    services.prometheus = {
      enable = true;
      port = 9090;
      
      scrapeConfigs = [
        # Self-Monitoring & Node Stats
        {
          job_name = "node";
          static_configs = [{ targets = [ "localhost:9100" ]; }];
        }
        
        # Blackbox (Reachability/SSL)
        {
          job_name = "blackbox";
          metrics_path = "/probe";
          params = { module = [ "http_2xx" ]; };
          static_configs = [{
            targets = [
              "https://ownorgasm.com"
              "https://www.ownorgasm.com"
              "https://admin.ownorgasm.com"
            ];
          }];
          relabel_configs = [
            { source_labels = [ "__address__" ]; target_label = "__param_target"; }
            { source_labels = [ "__param_target" ]; target_label = "instance"; }
            { target_label = "__address__"; replacement = "localhost:9115"; }
          ];
        }
        
        # Domain Exporter (WHOIS Expiry)
        {
          job_name = "domain";
          metrics_path = "/metrics";
          static_configs = [{
            targets = [ "localhost:9222" ];
          }];
        }
      ];
    };

    # ==========================================================================
    # EXPORTERS (The Sensors)
    # ==========================================================================

    # 1. Node Exporter (System Resources)
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      port = 9100;
    };

    # 2. Blackbox Exporter (HTTP/DNS/SSL Checks)
    services.prometheus.exporters.blackbox = {
      enable = true;
      port = 9115;
      configFile = pkgs.writeText "blackbox.yml" ''
        modules:
          http_2xx:
            prober: http
            timeout: 5s
            http:
              valid_status_codes: [] # Defaults to 2xx
              method: GET
              no_follow_redirects: false
              fail_if_ssl: false
              fail_if_not_ssl: true
              tls_config:
                insecure_skip_verify: false
          dns_google:
            prober: dns
            dns:
              query_name: "ownorgasm.com"
              query_type: "A"
      '';
    };
    
    # 3. Domain Exporter (WHOIS Expiry)
    # Note: Using standard package, running as simple systemd service if module missing
    systemd.services.prometheus-domain-exporter = {
      description = "Prometheus Domain Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.prometheus-domain-exporter}/bin/domain_exporter --bind :9222";
        Restart = "always";
        User = "nobody";
      };
    };
  };
}
