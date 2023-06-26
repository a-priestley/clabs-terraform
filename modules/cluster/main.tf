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
    image_id    = "ocid1.image.oc1.ca-montreal-1.aaaaaaaaxowisy372o5y5bsrtkiaslxuezsuoh2dc3avn6sq2fikyan623qq"
    source_type = "image"
  }
  initial_node_labels {
    key   = "name"
    value = "k8s-cluster"
  }
  ssh_public_key = file(var.oci_ssh_public_key_path)
}

resource "oci_load_balancer_backend_set" "load_balancer_backend_set" {
  load_balancer_id = var.load_balancer_id
  name             = "load-balancer-backend-set"
  policy           = "ROUND_ROBIN"
  health_checker {
    interval_ms         = 30000
    port                = 8080
    protocol            = "HTTP"
    response_body_regex = ".*"
    url_path            = "/"
  }
}

resource "oci_load_balancer_backend" "load_balancer_backend_1" {
  load_balancer_id = var.load_balancer_id
  backendset_name  = oci_load_balancer_backend_set.load_balancer_backend_set.name
  ip_address       = oci_containerengine_node_pool.oke_node_pool.nodes[0].private_ip
  port             = 8080
}

resource "oci_load_balancer_backend" "load_balancer_backend_2" {
  load_balancer_id = var.load_balancer_id
  backendset_name  = oci_load_balancer_backend_set.load_balancer_backend_set.name
  ip_address       = oci_containerengine_node_pool.oke_node_pool.nodes[1].private_ip
  port             = 8080
}

resource "oci_load_balancer_listener" "load_balancer_listener" {
  load_balancer_id         = var.load_balancer_id
  name                     = "load-balancer-listener"
  default_backend_set_name = oci_load_balancer_backend_set.load_balancer_backend_set.name
  port                     = 22
  protocol                 = "TCP"
}

data "oci_containerengine_cluster_kube_config" "kube_config" {
  cluster_id = oci_containerengine_cluster.oke_cluster.id
}
