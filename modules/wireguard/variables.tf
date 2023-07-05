variable "kube_config" {
  type = string
}

variable "cloudflare_api_token" {
  description = "The API token for your Cloudflare account"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID for the domain leased from Cloudflare"
  type        = string
}

variable "wireguard_port" {
  type = number
}

variable "wireguard_peers" {
  type = string
}

variable "wireguard_keepalive_peers" {
  type = string
}

variable "wireguard_site2site_peer" {
  type = string
}
variable "wireguard_site2site_allowedips" {
  type = string
}

variable "compartment_id" {
  description = "The compartment ID"
  type        = string
}
