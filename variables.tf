variable "project_name" {
  description = "The name with which to identify the project scope"
  type        = string
}

variable "cloudflare_api_token" {
  description = "API Token for the Cloudflare account"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID for the domain leased from Cloudflare"
  type        = string
}

variable "oci_user_ocid" {
  description = "The OCID of the Oracle Cloud user"
  type        = string
}

variable "oci_private_key_path" {
  description = "Path to the private key for the Oracle Cloud user"
  type        = string
}

variable "oci_ssh_public_key_path" {
  description = "Path to the public key for the Oracle Cloud user"
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

variable "email" {
  description = "General purpose email address for alerts"
  type        = string
}
