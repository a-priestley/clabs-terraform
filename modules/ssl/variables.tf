variable "letsencrypt_email" {
  description = "The email address to register with Let's Encrypt"
  type        = string
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

variable "kube_config" {
  type = string
}

variable "compartment_id" {
  type = string
}
