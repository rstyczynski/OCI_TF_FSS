variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain for the filesystem."
  type        = string
}

variable "export_set_ocid" {
  description = "Export set OCID of the existing mount target."
  type        = string
}

variable "filesystem_display_name" {
  description = "Filesystem display name."
  type        = string
  default     = "fss-orm-filesystem"
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key OCID. Null uses Oracle-managed encryption."
  type        = string
  default     = null
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

variable "enabled_exports" {
  description = "Map of enabled export slots keyed by slot name (e.g. export_1)."
  type = map(object({
    path            = string
    source_cidr     = string
    access          = string
    identity_squash = string
  }))
}

variable "anonymous_uid" {
  description = "Anonymous UID used when identity squashing applies."
  type        = number
  default     = 65534
}

variable "anonymous_gid" {
  description = "Anonymous GID used when identity squashing applies."
  type        = number
  default     = 65534
}

variable "require_privileged_source_port" {
  description = "Whether clients must use a privileged source port."
  type        = bool
  default     = false
}
