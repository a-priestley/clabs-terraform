variable "oci_user_ocid" {
  description = "The OCID of the Oracle Cloud user"
  type        = string
}

variable "oci_private_key_path" {
  description = "Path to the private key for the Oracle Cloud user"
  type        = string
}

variable "oci_fingerprint" {
  description = "The fingerprint for the private key"
  type        = string
}

variable "oci_tenancy_ocid" {
  description = "The OCID of the Oracle Cloud tenancy"
  type        = string
}

variable "oci_region" {
  description = "The region for Oracle Cloud resources"
  type        = string
}
