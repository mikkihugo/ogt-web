variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "server_type" {
  description = "Hetzner server type (e.g., cpx11, cpx21, cpx31)"
  type        = string
  default     = "cpx21" # 2 vCPU, 4GB RAM, 80GB SSD
}

variable "server_image" {
  description = "Server image (OS)"
  type        = string
  default     = "ubuntu-24.04"
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1" # Nuremberg

  validation {
    condition = contains([
      "nbg1", "fsn1", "hel1", "ash", "hil"
    ], var.location)
    error_message = "Location must be one of: nbg1, fsn1, hel1, ash, hil"
  }
}

variable "volume_size" {
  description = "Size of persistent volume in GB"
  type        = number
  default     = 50
}

variable "enable_ipv6" {
  description = "Enable IPv6 on the server"
  type        = bool
  default     = true
}

variable "prevent_destroy" {
  description = "Prevent accidental destruction of the server"
  type        = bool
  default     = false
}

variable "allowed_ips" {
  description = "List of IP addresses/CIDR blocks allowed to access port 8080"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "docker_compose_version" {
  description = "Docker Compose version to install"
  type        = string
  default     = "v2.24.0"
}
