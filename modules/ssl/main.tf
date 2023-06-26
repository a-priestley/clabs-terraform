terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    kustomization = {
      source = "kbst/kustomization"
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

resource "kustomization_resource" "certificate_reader" {
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
      name      = "certificate-reader"
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
        namespace = "default"
      }
    ]
    roleRef = {
      kind     = "Role"
      name     = "certificate-reader"
      apiGroup = "rbac.authorization.k8s.io"
    }
  })
}

#resource "kustomization_resource" "import_load_balancer_cert_cronjob" {
#  provider = kustomization.local
#  manifest = jsonencode({
#    apiVersion = "batch/v1"
#    kind       = "CronJob"
#    metadata = {
#      name      = "import-load-balancer-cert"
#      namespace = "default"
#    }
#    spec = {
#      serviceAccountName = "certificate-reader-service-account"
#      schedule           = "* * * * *"
#      jobTemplate = {
#        spec = {
#          template = {
#            spec = {
#              containers = [
#                {
#                  name            = "import-load-balancer-cert"
#                  image           = "ghcr.io/oracle/oci-cli:latest"
#                  imagePullPolicy = "IfNotPresent"
#                  command         = ["/bin/sh", "-c"]
#                  args = [<<-EOF
#                    TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
#                    NAMESPACE="cert-manager"
#                    SECRET_OUTPUT=$(curl -sSk -H "Authorization: Bearer $TOKEN" https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/secrets/$SECRET_NAME)
#                    echo "Secret output: $SECRET_OUTPUT"
#                    echo "$SECRET_OUTPUT" | jq -r '.data."tls.crt"' | base64 -d > /tmp/cert.pem
#                    echo "$SECRET_OUTPUT" | jq -r '.data."tls.key"' | base64 -d > /tmp/key.pem
#                    oci lb certificate create --certificate-name test-cert --public-certificate-file /tmp/cert.pem --private-key-file /tmp/key.pem --load-balancer-id $LOAD_BALANCER_ID
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
#}

#resource "kustomization_resource" "oci_config_secret" {
#  provider = kustomization.local
#  manifest = jsonencode({
#    apiVersion = "v1"
#    kind       = "Secret"
#    metadata = {
#      name      = "oci-config"
#      namespace = "default"
#    }
#    type = "Opaque"
#    data = {
#      config = filebase64("${
#    }
#  })
#}
