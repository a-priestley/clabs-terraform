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

resource "kubernetes_namespace" "headscale_namespace" {
  metadata {
    name = "headscale"
  }
}

resource "oci_core_public_ip" "headscale_public_ip" {
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"

  lifecycle {
    ignore_changes = [private_ip_id]
  }
}


resource "kubernetes_config_map" "headscale_config_map" {
  metadata {
    name      = "headscale-config"
    namespace = kubernetes_namespace.headscale_namespace.id
  }
  data = {
    "config.yaml" = <<EOF
server_url: https://headscale.${data.cloudflare_zone.zone.name}
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 0.0.0.0:9090
private_key_path: /etc/headscale/private.key
noise:
  private_key_path: /etc/headscale/noise_private.key
db_type: sqlite3
db_path: /etc/headscale/db.sqlite
tls_cert_path: ""
tls_key_path: ""
EOF
  }
}

#resource "kubernetes_persistent_volume_claim" "headscale_pvc" {
#  metadata {
#    name      = "headscale-pvc"
#    namespace = kubernetes_namespace.headscale_namespace.id
#    annotations = {
#      "volume.beta.kubernetes.io/oci-volume-source" = "ocid1.bootvolume.oc1.ca-montreal-1.ab4xkljrvmbpwtn3sd3f4s7uhhxwzyiq6pio73unax2ho7ucj6nqw6ng4kca"
#    }
#  }
#  spec {
#    access_modes = ["ReadWriteOnce"]
#    resources {
#      requests = {
#        "storage" = "1Gi"
#      }
#    }
#  }
#  wait_until_bound = false
#}
#
#resource "kubernetes_deployment" "headscale_deployment" {
#  metadata {
#    name = "headscale"
#    labels = {
#      app = "headscale"
#    }
#    namespace = kubernetes_namespace.headscale_namespace.id
#  }
#  spec {
#    replicas = 1
#    selector {
#      match_labels = {
#        app = "headscale"
#      }
#    }
#    template {
#      metadata {
#        labels = {
#          app = "headscale"
#        }
#        annotations = {
#          "config-hash" = sha256(jsonencode(kubernetes_config_map.headscale_config_map.data))
#        }
#      }
#      spec {
#        volume {
#          name = "config"
#          config_map {
#            name = kubernetes_config_map.headscale_config_map.metadata[0].name
#          }
#        }
#        volume {
#          name = "data"
#          persistent_volume_claim {
#            claim_name = "headscale-pvc"
#          }
#        }
#        service_account_name = "certificate-reader-service-account"
#        container {
#          image             = "headscale/headscale:latest"
#          name              = "headscale"
#          image_pull_policy = "IfNotPresent"
#          volume_mount {
#            mount_path = "/etc/headscale/config.yaml"
#            name       = "config"
#            sub_path   = "config.yaml"
#          }
#          volume_mount {
#            mount_path = "/etc/headscale"
#            name       = "data"
#          }
#          security_context {
#            capabilities {
#              add = ["NET_ADMIN"]
#            }
#          }
#          port {
#            name           = "headscale-port"
#            container_port = 3478
#            protocol       = "UDP"
#          }
#          #env {
#          #  
#          #}
#          command = ["headscale", "serve"]
#          #command = ["sleep", "infinity"]
#        }
#      }
#    }
#  }
#}

#resource "kubernetes_ingress" "headscale_ingress" {
#  metadata {
#    name        = "headscale-ingress"
#    namespace   = "headscale"
#    annotations = { "kubernetes.io/ingress.class" : "traefik-external" }
#  }
#  spec {
#    backend {
#      service_name = "headscale-service"
#      service_port = 8080
#    }
#    entry_points = ["webSecure"]
#    rule {
#      http {
#        
#      }
#      host = 
#    }
#    routes = [
#      {
#        "match" : "Host(`www.headscale.carcinomalabs.com`)"
#        "kind" : "Rule"
#        "services" : [
#          {
#            "name" : "headscale",
#            "port" : 80
#          }
#        ]
#      },
#      {
#        "match" : "Host(`headscale.carcinomalabs.com`)"
#        "kind" : "Rule"
#        "services" : [
#          {
#            "name" : "headscale",
#            "port" : 80
#          }
#        ]
#      }
#    ]
#    tls {
#      secret_name = "${data.cloudflare_zone.zone.name}-tls"
#    }
#  }
#}
#
#resource "kubernetes_service" "headscale_service" {
#  metadata {
#    name        = "headscale-service"
#    namespace   = kubernetes_namespace.headscale_namespace.id
#    annotations = { "oci.oraclecloud.com/load-balancer-type" : "nlb" }
#  }
#  spec {
#    selector = {
#      app = "headscale"
#    }
#    port {
#      port        = 3478
#      target_port = 3478
#      protocol    = "UDP"
#    }
#    type             = "LoadBalancer"
#    load_balancer_ip = oci_core_public_ip.headscale_public_ip.ip_address
#  }
#}
#
#resource "cloudflare_record" "headscale_record" {
#  zone_id = data.cloudflare_zone.zone.id
#  name    = "headscale"
#  value   = oci_core_public_ip.headscale_public_ip.ip_address
#  type    = "A"
#  proxied = false
#}
