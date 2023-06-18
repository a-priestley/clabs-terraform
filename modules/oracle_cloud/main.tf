terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

provider "oci" {
  user_ocid        = var.oci_user_ocid
  fingerprint      = var.oci_fingerprint
  private_key_path = var.oci_private_key_path
  tenancy_ocid     = var.oci_tenancy_ocid
  region           = var.oci_region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

resource "oci_identity_compartment" "clabs_compartment" {
  compartment_id = var.oci_tenancy_ocid
  description    = "Compartment for Terraform resources."
  name           = "CLabsTerraformCompartment"
}

resource "oci_core_vcn" "clabs_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = oci_identity_compartment.clabs_compartment.id
  display_name   = "CLabsTerraformVCN"
  dns_label      = "clabstf"
}

resource "oci_core_internet_gateway" "clabs_internet_gateway" {
  compartment_id = oci_identity_compartment.clabs_compartment.id
  display_name   = "CLabs Terraform Internet Gateway"
  vcn_id         = oci_core_vcn.clabs_vcn.id
}

resource "oci_core_subnet" "clabs_public_subnet" {
  compartment_id             = oci_identity_compartment.clabs_compartment.id
  vcn_id                     = oci_core_vcn.clabs_vcn.id
  display_name               = "CLabsTerraformPublicSubnet"
  cidr_block                 = "10.0.1.0/24"
  dns_label                  = "clabstf"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_vcn.clabs_vcn.default_route_table_id
  dhcp_options_id            = oci_core_vcn.clabs_vcn.default_dhcp_options_id
  security_list_ids          = [oci_core_vcn.clabs_vcn.default_security_list_id]
}
