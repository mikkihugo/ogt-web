{ lib, ... }: 
{
  networking = {
    hostName = "ogt-web-prod";
    nameservers = [ "8.8.8.8" "1.1.1.1" ];
    
    defaultGateway = "172.31.1.1";
    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };
    
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce false;
    
    interfaces.eth0 = {
      ipv4.addresses = [{ address = "77.42.66.89"; prefixLength = 32; }];
      ipv6.addresses = [
        { address = "2a01:4f9:c013:8d07::1"; prefixLength = 64; }
        { address = "fe80::9000:6ff:feee:ecbb"; prefixLength = 64; }
      ];
      ipv4.routes = [{ address = "172.31.1.1"; prefixLength = 32; }];
      ipv6.routes = [{ address = "fe80::1"; prefixLength = 128; }];
    };
    
    # Firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };
  
  services.udev.extraRules = ''
    ATTR{address}=="92:00:06:ee:ec:bb", NAME="eth0"
  '';
}
