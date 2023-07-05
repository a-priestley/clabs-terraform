output "kube_config" {
  value = data.oci_containerengine_cluster_kube_config.kube_config.content
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.oke_node_pool.id
}

#output "load_balancer_backend_set_id" {
#  value = oci_load_balancer_backend_set.load_balancer_backend_set.id
#}
#
#output "load_balancer_listener_id" {
#  value = oci_load_balancer_listener.load_balancer_listener.id
#}
#
#output "network_load_balancer_backend_set_id" {
#  value = oci_network_load_balancer_backend_set.network_load_balancer_backend_set.id
#}
#
#output "network_load_balancer_listener_id" {
#  value = oci_network_load_balancer_listener.network_load_balancer_listener.id
#}
