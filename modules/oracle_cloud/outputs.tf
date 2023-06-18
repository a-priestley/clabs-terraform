output "all-availability-domains-in-your-tenancy" {
  value = data.oci_identity_availability_domains.ads
}

#output "vcn_id" {
#  description = "OCID of the VCN that is created"
#  value = module.vcn.vcn_id
#}
#output "id-for-route-table-that-includes-the-internet-gateway" {
#  description = "OCID of the internet-route table. This route table has an internet gateway to be used for public subnets"
#  value = module.vcn.ig_route_id
#}
#output "nat-gateway-id" {
#  description = "OCID for NAT gateway"
#  value = module.vcn.nat_gateway_id
#}
#output "id-for-for-route-table-that-includes-the-nat-gateway" {
#  description = "OCID of the nat-route table - This route table has a nat gateway to be used for private subnets. This route table also has a service gateway."
#  value = module.vcn.nat_route_id
#}
