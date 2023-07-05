terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

resource "oci_containerengine_cluster" "oke_cluster" {
  compartment_id     = var.compartment_id
  kubernetes_version = "v1.26.2"
  name               = "K8s Cluster"
  vcn_id             = var.vcn_id
  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = var.public_subnet_id
  }
  options {
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }
    service_lb_subnet_ids = [var.public_subnet_id]
  }
}

resource "oci_containerengine_node_pool" "oke_node_pool" {
  cluster_id         = oci_containerengine_cluster.oke_cluster.id
  compartment_id     = var.compartment_id
  kubernetes_version = "v1.26.2"
  name               = "K8s Node Pool"
  node_config_details {
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.private_subnet_id
    }
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.private_subnet_id
    }
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.private_subnet_id
    }
    size = 2
  }
  node_shape = "VM.Standard.A1.Flex"
  node_shape_config {
    memory_in_gbs = 6
    ocpus         = 1
  }
  node_source_details {
    image_id    = var.oci_oke_image_id
    source_type = "image"
  }
  initial_node_labels {
    key   = "name"
    value = "k8s-cluster"
  }
  ssh_public_key = file(var.oci_ssh_public_key_path)
}

data "oci_containerengine_cluster_kube_config" "kube_config" {
  cluster_id = oci_containerengine_cluster.oke_cluster.id
}
