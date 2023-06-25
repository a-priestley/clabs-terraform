terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

provider "oci" {
  #user_ocid        = var.oci_user_ocid
  #fingerprint      = var.oci_fingerprint
  #private_key_path = var.oci_private_key_path
  #tenancy_ocid     = var.oci_tenancy_ocid
  region              = var.oci_region
  #auth                = "SecurityToken"
  #config_file_profile = "DEFAULT"
}

resource "oci_identity_compartment" "identity_compartment" {
  compartment_id = var.oci_tenancy_ocid
  description    = "Compartment for Terraform resources."
  name           = "${var.project_name}"
}

module "vcn" {
  source                       = "oracle-terraform-modules/vcn/oci"
  compartment_id               = oci_identity_compartment.identity_compartment.id
  region                       = var.oci_region
  internet_gateway_route_rules = null
  local_peering_gateways       = null
  nat_gateway_route_rules      = null
  vcn_name                     = "TerraformVCN"
  vcn_dns_label                = "${var.project_name}tf"
  vcn_cidrs                    = ["10.0.0.0/16"]
  create_internet_gateway      = true
  create_nat_gateway           = true
  create_service_gateway       = true
}

resource "oci_core_security_list" "private_subnet_sl" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  vcn_id         = module.vcn.vcn_id

  display_name = "Private Subnet Security List"
  egress_security_rules {
    stateless        = false
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  ingress_security_rules {
    stateless   = false
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    protocol    = "all"
  }
}

resource "oci_core_security_list" "public_subnet_sl" {
  compartment_id = oci_identity_compartment.identity_compartment.id
  vcn_id         = module.vcn.vcn_id

  display_name = "Public Subnet Security List"

  egress_security_rules {
    stateless        = false
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  ingress_security_rules {
    stateless   = false
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    protocol    = "all"
  }

  ingress_security_rules {
    stateless   = false
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_subnet" "public_subnet" {
  compartment_id             = oci_identity_compartment.identity_compartment.id
  vcn_id                     = module.vcn.vcn_id
  display_name               = "Public Subnet"
  cidr_block                 = "10.0.0.0/24"
  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
  route_table_id             = module.vcn.ig_route_id
  security_list_ids          = [oci_core_security_list.public_subnet_sl.id]
}

resource "oci_core_subnet" "private_subnet" {
  compartment_id             = oci_identity_compartment.identity_compartment.id
  vcn_id                     = module.vcn.vcn_id
  display_name               = "Private Subnet"
  cidr_block                 = "10.0.1.0/24"
  dns_label                  = "private"
  prohibit_public_ip_on_vnic = true
  route_table_id             = module.vcn.nat_route_id
  security_list_ids          = [oci_core_security_list.private_subnet_sl.id]
}

resource "oci_load_balancer_load_balancer" "load_balancer" {
  shape          = "flexible"
  compartment_id = oci_identity_compartment.identity_compartment.id
  display_name   = "Load Balancer"
  is_private     = false

  subnet_ids = [
    oci_core_subnet.public_subnet.id
  ]

  shape_details {
    maximum_bandwidth_in_mbps = 10
    minimum_bandwidth_in_mbps = 10
  }
}

