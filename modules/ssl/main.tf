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
