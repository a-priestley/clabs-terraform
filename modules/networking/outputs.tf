output "public_subnet_id" {
  value = oci_core_subnet.public_subnet.id
}

output "private_subnet_id" {
  value = oci_core_subnet.private_subnet.id
}

output "vcn_id" {
  value = module.vcn.vcn_id
}

output "compartment_id" {
  value = oci_identity_compartment.identity_compartment.id
}

output "load_balancer_id" {
  value = oci_load_balancer_load_balancer.load_balancer.id
}
