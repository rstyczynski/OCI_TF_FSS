variable "compartment_ocid" {
  description = "Target OCI compartment OCID (expected: /oci_tf_fss)."
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain name for the filesystem."
  type        = string
}

variable "display_name" {
  description = "Filesystem display name."
  type        = string
}

variable "freeform_tags" {
  description = "Freeform tags to apply to the filesystem."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "User-managed defined tags to apply to the filesystem."
  type        = map(string)
  default     = {}
}
