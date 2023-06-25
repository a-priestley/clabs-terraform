variable "public_subnet_id" {
  description = "The public subnet ID for the cluster"
  type        = string
}

variable "private_subnet_id" {
  description = "The private subnet ID for the cluster"
  type        = string
}

variable "vcn_id" {
  description = "The virtual cloud network ID"
  type        = string
}

variable "compartment_id" {
  description = "The compartment ID"
  type        = string
}

variable "oci_ssh_public_key_path" {
  description = "Your local ssh public key path"
  type        = string
}

variable "load_balancer_id" {
  description = "The ID of the load balancer"
  type        = string
}
