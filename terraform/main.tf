terraform {
  required_version = ">= 1.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }

  # Optional: Use remote state backend
  # backend "s3" {
  #   bucket = "ogt-web-terraform-state"
  #   key    = "hetzner/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "hcloud" {
  token = var.hcloud_token
}

# SSH Key for server access
resource "hcloud_ssh_key" "default" {
  name       = "ogt-web-${var.environment}"
  public_key = var.ssh_public_key
}

# Firewall rules
resource "hcloud_firewall" "ogt_web" {
  name = "ogt-web-${var.environment}"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "8080"
    source_ips = var.allowed_ips
  }
}

# Server instance
resource "hcloud_server" "ogt_web" {
  name        = "ogt-web-${var.environment}"
  image       = var.server_image
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.ogt_web.id]

  labels = {
    environment = var.environment
    app         = "ogt-web"
    managed_by   = "terraform"
  }

  # User data script to install Docker and setup
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    docker_compose_version = var.docker_compose_version
  })

  # Public network
  public_net {
    ipv4_enabled = true
    ipv6_enabled = var.enable_ipv6
  }

  # Lifecycle: prevent accidental deletion
  lifecycle {
    prevent_destroy = var.prevent_destroy
  }
}

# Volume for persistent data (Magento data, MySQL)
resource "hcloud_volume" "magento_data" {
  name     = "magento-data-${var.environment}"
  size     = var.volume_size
  location = var.location
  format   = "ext4"

  labels = {
    environment = var.environment
    app         = "ogt-web"
  }
}

# Attach volume to server
resource "hcloud_volume_attachment" "magento_data" {
  volume_id = hcloud_volume.magento_data.id
  server_id = hcloud_server.ogt_web.id
  automount = true
}

# Outputs
output "server_ipv4" {
  value       = hcloud_server.ogt_web.ipv4_address
  description = "IPv4 address of the server"
}

output "server_ipv6" {
  value       = var.enable_ipv6 ? hcloud_server.ogt_web.ipv6_address : null
  description = "IPv6 address of the server"
}

output "server_id" {
  value       = hcloud_server.ogt_web.id
  description = "Server ID"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/id_rsa root@${hcloud_server.ogt_web.ipv4_address}"
  description = "SSH command to connect to the server"
}
