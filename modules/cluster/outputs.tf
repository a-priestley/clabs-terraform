output "kube_config" {
  value = data.oci_containerengine_cluster_kube_config.kube_config.content
}
