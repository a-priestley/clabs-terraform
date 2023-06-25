variable "oci_region" {
  description = "The region for Oracle Cloud resources"
  type        = string
}

variable "oci_tenancy_ocid" {
  description = "The OCID of the Oracle Cloud tenancy"
  type        = string
}

variable "project_name" {
  description = "The name with which to identify the project scope"
  type        = string
}
