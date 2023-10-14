terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    kustomization = {
      source = "kbst/kustomization"
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

provider "kustomization" {
  alias           = "local"
  kubeconfig_path = local_sensitive_file.kube_config.filename
}

provider "kubernetes" {
  config_path = local_sensitive_file.kube_config.filename
}

#resource "oci_core_public_ip" "traefik_public_ip" {
#  compartment_id = var.compartment_id
#  lifetime       = "RESERVED"
#
#  lifecycle {
#    ignore_changes = [private_ip_id]
#  }
#}

resource "kustomization_resource" "cloudflare_api_token_secret" {
  provider = kustomization.local
  manifest = jsonencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "cloudflare-api-token"
      namespace = "cert-manager"
    }
    type = "Opaque"
    stringData = {
      api-token = "${var.cloudflare_api_token}"
    }
  })
}

module "cert_manager" {
  providers = {
    kustomization = kustomization.local
  }

  source  = "kbst.xyz/catalog/cert-manager/kustomization"
  version = "1.11.1-kbst.0"

  configuration_base_key = "default"
  configuration = {
    default = {
      additional_resources = ["${path.module}/cluster-issuer.yaml"]
      patches = [
        {
          patch = <<-EOF
            - op: replace
              path: /spec/acme/email
              value: ${var.letsencrypt_email}
          EOF

          target = {
            group  = "cert-manager.io"
            verion = "v1"
            kind   = "ClusterIssuer"
            name   = "letsencrypt"
          }
        },
        {
          patch = <<-EOF
            - op: replace
              path: /spec/acme/solvers/0/dns01/cloudflare/apiTokenSecretRef/name
              value: ${yamldecode(kustomization_resource.cloudflare_api_token_secret.manifest)["metadata"]["name"]}
          EOF
          target = {
            group  = "cert-manager.io"
            verion = "v1"
            kind   = "ClusterIssuer"
            name   = "letsencrypt"
          }
        },
        #{
        #  patch = <<-EOF
        #    - op: replace
        #      path: /spec/acme/server
        #      value: https://acme-staging-v02.api.letsencrypt.org/directory
        #  EOF

        #  target = {
        #    group  = "cert-manager.io"
        #    verion = "v1"
        #    kind   = "ClusterIssuer"
        #    name   = "letsencrypt"
        #  }
        #}
      ]
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "zone" {
  zone_id = var.cloudflare_zone_id
}

resource "kustomization_resource" "certificate" {
  provider = kustomization.local
  manifest = jsonencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = data.cloudflare_zone.zone.name
      namespace = "cert-manager"
    }
    spec = {
      secretName = "${data.cloudflare_zone.zone.name}-tls"
      issuerRef = {
        name = "letsencrypt"
        kind = "ClusterIssuer"
      }
      commonName = "*.${data.cloudflare_zone.zone.name}"
      dnsNames = [
        "*.${data.cloudflare_zone.zone.name}",
        data.cloudflare_zone.zone.name,
      ]
    }
  })
  depends_on = [module.cert_manager]
}

resource "kustomization_resource" "certificate_reader_service_account" {
  provider = kustomization.local
  manifest = jsonencode({
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "certificate-reader-service-account"
      namespace = "cert-manager"
    }
  })
}

resource "kustomization_resource" "certificate_reader_role" {
  provider = kustomization.local
  manifest = jsonencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "Role"
    metadata = {
      name      = "certificate-reader-role"
      namespace = "cert-manager"
    }
    rules = [
      {
        apiGroups     = [""]
        resources     = ["secrets"]
        resourceNames = ["${data.cloudflare_zone.zone.name}-tls"]
        verbs         = ["get"]
      }
    ]
  })
}

resource "kustomization_resource" "certificate_reader_role_binding" {
  provider = kustomization.local
  manifest = jsonencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"
    metadata = {
      name      = "read-certificate-secrets"
      namespace = "cert-manager"
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = "certificate-reader-service-account"
        namespace = "cert-manager"
      }
    ]
    roleRef = {
      kind     = "Role"
      name     = "certificate-reader-role"
      apiGroup = "rbac.authorization.k8s.io"
    }
  })
}


#resource "kubernetes_namespace" "traefik_namespace" {
#  metadata {
#    name = "traefik"
#  }
#}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig.yaml"
  }
}

#resource "helm_release" "traefik" {
#  name = "traefik-release"
#  repository = "https://helm.traefik.io/traefik"
#  chart = "traefik"
#
#  values = [
#    "${file("${path.module}/traefik.yaml")}"
#  ]
#
#  set {
#    name = "service.spec.loadBalancerIP"
#    value = oci_core_public_ip.traefik_public_ip.ip_address
#  }
#}

#resource "kustomization_resource" "import_load_balancer_cert_cronjob" {
#  provider = kustomization.local
#  manifest = jsonencode({
#    apiVersion = "batch/v1"
#    kind       = "CronJob"
#    metadata = {
#      name      = "import-load-balancer-cert"
#      namespace = "cert-manager"
#    }
#    spec = {
#      schedule = "0 0 * * *"
#      jobTemplate = {
#        spec = {
#          template = {
#            spec = {
#              serviceAccountName = "certificate-reader-service-account"
#              containers = [
#                {
#                  name            = "import-load-balancer-cert"
#                  image           = "ghcr.io/oracle/oci-cli:latest"
#                  imagePullPolicy = "IfNotPresent"
#                  command         = ["/bin/sh", "-c"]
#                  args = [<<-EOF
#                    TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
#                    NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
#                    SECRET=$(curl -sSk -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/secrets/$SECRET_NAME)
#                    NEW_CERTIFICATE=$(echo "$SECRET" | jq -r '.data."tls.crt"' | base64 -d)
#                    CURRENT_CERTIFICATES=$(oci lb certificate list --load-balancer-id $LOAD_BALANCER_ID --all)
#                    LATEST_CERTIFICATE=$(echo $CURRENT_CERTIFICATES | jq -r '.data | sort_by(."certificate-name") | last."public-certificate"')
#                    if [ "$LATEST_CERTIFICATE" != "$NEW_CERTIFICATE" ]; then
#                        CERTIFICATE_NAME=$(date +%s)
#                        echo "$SECRET" | jq -r '.data."tls.key"' | base64 -d > /tmp/key.pem
#                        echo "$NEW_CERTIFICATE" > /tmp/cert.pem
#                        oci lb certificate create --certificate-name $CERTIFICATE_NAME --public-certificate-file /tmp/cert.pem --private-key-file /tmp/key.pem --load-balancer-id $LOAD_BALANCER_ID --wait-for-state SUCCEEDED
#                        oci lb listener update --load-balancer-id $LOAD_BALANCER_ID --default-backend-set-name load-balancer-backend-set --port 443 --protocol HTTP2 --listener-name load-balancer-listener --ssl-certificate-name $CERTIFICATE_NAME --cipher-suite-name oci-default-http2-ssl-cipher-suite-v1 --force
#                        OLD_CERTS=$(echo $CURRENT_CERTIFICATES | jq -r ".data[] | select(.\"certificate-name\" != \"$CERTIFICATE_NAME\") | .\"certificate-name\"")
#                        for cert in $OLD_CERTS; do 
#                            oci lb certificate delete --load-balancer-id $LOAD_BALANCER_ID --certificate-name $cert --force; 
#                        done
#                    fi  
#                  EOF
#                  ]
#                  env = [
#                    {
#                      name  = "OCI_CLI_AUTH",
#                      value = "instance_principal"
#                    },
#                    {
#                      name  = "SECRET_NAME",
#                      value = "${data.cloudflare_zone.zone.name}-tls"
#                    },
#                    {
#                      name  = "LOAD_BALANCER_ID",
#                      value = var.load_balancer_id
#                    }
#                  ]
#                }
#              ]
#              restartPolicy = "OnFailure"
#            }
#          }
#        }
#      }
#    }
#  })
#  depends_on = [
#    kustomization_resource.certificate_reader_role,
#    kustomization_resource.certificate_reader_role_binding
#  ]
#}
