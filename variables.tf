#variable "proxmox_url" {
#  description = "URL of the Proxmox server"
#  type        = string
#}
#
#variable "proxmox_user" {
#  description = "User for the Proxmox server"
#  type        = string
#}
#
#variable "proxmox_password" {
#  description = "Password for the Proxmox user"
#  type        = string
#  sensitive   = true
#}

variable "cloudflare_api_token" {
  description = "API Token for the Cloudflare account"
  type        = string
  sensitive   = true
}

variable "oci_user_ocid" {
  description = "The OCID of the Oracle Cloud user"
  type        = string
}

variable "oci_private_key_path" {
  description = "Path to the private key for the Oracle Cloud user"
  type        = string
}

variable "oci_fingerprint" {
  description = "The fingerprint for the private key"
  type        = string
}

variable "oci_tenancy_ocid" {
  description = "The OCID of the Oracle Cloud tenancy"
  type        = string
}

variable "oci_region" {
  description = "The region for Oracle Cloud resources"
  type        = string
}
