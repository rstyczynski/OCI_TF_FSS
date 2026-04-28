variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain name for the mount target."
  type        = string
}

variable "subnet_ocid" {
  description = "Subnet OCID where the mount target will be created."
  type        = string
}

variable "display_name" {
  description = "Mount target display name."
  type        = string
}

variable "hostname_label" {
  description = "Optional hostname label for the mount target private IP."
  type        = string
  default     = null
}

variable "nsg_ids" {
  description = "Optional NSG OCIDs to attach to the mount target."
  type        = list(string)
  default     = null
}

variable "freeform_tags" {
  description = "Freeform tags to apply to the mount target."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "User-managed defined tags to apply to the mount target."
  type        = map(string)
  default     = {}
}
