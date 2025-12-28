terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

variable "hcloud_token" {
  sensitive = true
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_server" "ogt_web" {
  name        = "ogt-web-prod"
  image       = "ubuntu-24.04"
  server_type = "cax21" # ARM64, 4 vCPU, 8GB RAM, ~6 EUR/mo
  location    = "hel1"  # Helsinki (Green energy)
  
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  user_data = <<EOF
#!/bin/bash
apt-get update
apt-get install -y curl git
# Install Nix
curl -L https://nixos.org/nix/install | sh -s -- --daemon
EOF
}

output "ip_address" {
  value = hcloud_server.ogt_web.ipv4_address
}
