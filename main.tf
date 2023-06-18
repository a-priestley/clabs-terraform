terraform {
  backend "s3" {
  }
}

module "oracle_cloud" {
  source               = "./modules/oracle_cloud"
  oci_user_ocid        = var.oci_user_ocid
  oci_private_key_path = var.oci_private_key_path
  oci_fingerprint      = var.oci_fingerprint
  oci_tenancy_ocid     = var.oci_tenancy_ocid
  oci_region           = var.oci_region
}

module "cloudflare" {
  source               = "./modules/cloudflare"
  cloudflare_api_token = var.cloudflare_api_token
}

#module "proxmox" {
#  source           = "./modules/proxmox"
#  proxmox_url      = var.proxmox_url
#  proxmox_user     = var.proxmox_user
#  proxmox_password = var.proxmox_password
#}
