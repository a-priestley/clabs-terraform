terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    oci = {
      source = "oracle/oci"
    }
  }
}

resource "local_sensitive_file" "kube_config" {
  content  = var.kube_config
  filename = "${path.module}/kubeconfig.yaml"
}

provider "kubernetes" {
  config_path = local_sensitive_file.kube_config.filename
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "zone" {
  zone_id = var.cloudflare_zone_id
}

resource "kubernetes_namespace" "wireguard_namespace" {
  metadata {
    name = "wireguard"
  }
}

resource "oci_core_public_ip" "wireguard_public_ip" {
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"

  lifecycle {
    ignore_changes = [private_ip_id]
  }
}

resource "kubernetes_persistent_volume_claim" "wireguard_pvc" {
  metadata {
    name      = "wireguard-pvc"
    namespace = kubernetes_namespace.wireguard_namespace.id
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        "storage" = "1Gi"
      }
    }
  }
}

locals {
  site2site_map = {
    for obj in var.wireguard_site2site : "SERVER_ALLOWEDIPS_PEER_${obj.peer}" => obj.ips
  }
}

resource "kubernetes_config_map" "wireguard_config_map" {
  metadata {
    name      = "wireguard-config"
    namespace = kubernetes_namespace.wireguard_namespace.id
  }
  data = merge({
    PUID                                                     = "1000"
    PGID                                                     = "1000"
    TZ                                                       = "Etc/UTC"
    SERVERURL                                                = "wireguard.${data.cloudflare_zone.zone.name}"
    SERVERPORT                                               = "${var.wireguard_port}"
    PEERS                                                    = "${var.wireguard_peers}"
    PEERDNS                                                  = "auto"
    INTERNAL_SUBNET                                          = "10.13.13.0"
    ALLOWEDIPS                                               = "0.0.0.0/0"
    PERSISTENTKEEPALIVE_PEERS                                = "${var.wireguard_keepalive_peers}"
    LOG_CONFS                                                = "true"
  }, local.site2site_map)
}

resource "kubernetes_deployment" "wireguard_deployment" {
  metadata {
    name = "wireguard"
    labels = {
      app = "wireguard"
    }
    namespace = kubernetes_namespace.wireguard_namespace.id
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "wireguard"
      }
    }

    template {
      metadata {
        labels = {
          app = "wireguard"
        }
        annotations = {
          "config-hash" = sha256(jsonencode(kubernetes_config_map.wireguard_config_map.data))
        }
      }
      spec {
        volume {
          name = "wireguard-storage"
          persistent_volume_claim {
            claim_name = "wireguard-pvc"
          }
        }
        volume {
          name = "lib-modules"
          host_path {
            path = "/lib/modules"
          }
        }
        container {
          name              = "wireguard"
          image             = "lscr.io/linuxserver/wireguard:latest"
          image_pull_policy = "IfNotPresent"
          env_from {
            config_map_ref {
              name = kubernetes_config_map.wireguard_config_map.metadata[0].name
            }
          }
          volume_mount {
            name       = "wireguard-storage"
            mount_path = "/config"
          }
          volume_mount {
            name       = "lib-modules"
            mount_path = "/lib/modules"
          }
          security_context {
            capabilities {
              add = ["NET_ADMIN"]
            }
          }
          port {
            name           = "wireguard-port"
            container_port = var.wireguard_port
            protocol       = "UDP"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "wireguard_service" {
  metadata {
    name        = "wireguard-service"
    namespace   = kubernetes_namespace.wireguard_namespace.id
    annotations = { "oci.oraclecloud.com/load-balancer-type" : "nlb" }
  }
  spec {
    selector = {
      app = "wireguard"
    }
    port {
      port        = var.wireguard_port
      target_port = var.wireguard_port
      protocol    = "UDP"
    }
    type             = "LoadBalancer"
    load_balancer_ip = oci_core_public_ip.wireguard_public_ip.ip_address
  }
}

resource "cloudflare_record" "wireguard_record" {
  zone_id = data.cloudflare_zone.zone.id
  name    = "wireguard"
  value   = oci_core_public_ip.wireguard_public_ip.ip_address
  type    = "A"
  proxied = false
}
