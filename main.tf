terraform {
  backend "s3" {
  }
}

module "oracle_cloud" {
  source               = "./oracle_cloud"
  oci_user_ocid        = var.oci_user_ocid
  oci_private_key_path = var.oci_private_key_path
  oci_fingerprint      = var.oci_fingerprint
  oci_tenancy_ocid     = var.oci_tenancy_ocid
  oci_region           = var.oci_region
}

module "cloudflare" {
  source             = "./cloudflare"
  cloudflare_email   = var.cloudflare_email
  cloudflare_api_key = var.cloudflare_api_key
}

module "proxmox" {
  source           = "./proxmox"
  proxmox_url      = var.proxmox_url
  proxmox_user     = var.proxmox_user
  proxmox_password = var.proxmox_password
}
