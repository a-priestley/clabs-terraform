terraform {
  backend "s3" {
  }
}

module "networking" {
  source           = "./modules/networking"
  project_name     = var.project_name
  oci_region       = var.oci_region
  oci_tenancy_ocid = var.oci_tenancy_ocid
}

module "cluster" {
  source                  = "./modules/cluster"
  public_subnet_id        = module.networking.public_subnet_id
  private_subnet_id       = module.networking.private_subnet_id
  vcn_id                  = module.networking.vcn_id
  compartment_id          = module.networking.compartment_id
  oci_ssh_public_key_path = var.oci_ssh_public_key_path
  oci_oke_image_id        = var.oci_oke_image_id
}

module "ssl" {
  source               = "./modules/ssl"
  letsencrypt_email    = var.email
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  kube_config          = module.cluster.kube_config
}

module "wireguard" {
  source                         = "./modules/wireguard"
  kube_config                    = module.cluster.kube_config
  compartment_id                 = module.networking.compartment_id
  cloudflare_api_token           = var.cloudflare_api_token
  cloudflare_zone_id             = var.cloudflare_zone_id
  wireguard_port                 = var.wireguard_port
  wireguard_peers                = var.wireguard_peers
  wireguard_keepalive_peers      = var.wireguard_keepalive_peers
  wireguard_site2site_peer       = var.wireguard_site2site_peer
  wireguard_site2site_allowedips = var.wireguard_site2site_allowedips
}
