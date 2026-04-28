variable "compartment_ocid" {
  description = "Target OCI compartment OCID (expected: /oci_tf_fss)."
  type        = string
}

variable "name_prefix" {
  description = "Name prefix used when display_name is not set."
  type        = string
  default     = "fss"
}

variable "display_name" {
  description = "Filesystem display name. When null, derived from name_prefix."
  type        = string
  default     = null
}

variable "availability_domain" {
  description = "Availability Domain name. When null, the first AD is selected."
  type        = string
  default     = null
}

variable "freeform_tags" {
  description = "Freeform tags to apply to the filesystem."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "Defined tags to apply to the filesystem."
  type        = map(string)
  default     = {}
}
