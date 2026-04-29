variable "region" {
  description = "OCI region used by the Resource Manager provider runner."
  type        = string
}

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain for the filesystem and mount target lookup."
  type        = string
}

variable "existing_mount_target_ocid" {
  description = "Existing mount target OCID selected by the operator."
  type        = string
}

variable "filesystem_display_name" {
  description = "Filesystem display name."
  type        = string
  default     = "fss-orm-filesystem"
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key OCID. Leave empty for Oracle-managed encryption."
  type        = string
  default     = ""
}

variable "default_source_cidr" {
  description = "Default client CIDR for exports with an empty source CIDR."
  type        = string
  default     = "0.0.0.0/0"
}

variable "export_1_path" {
  description = "Mandatory export 1 path."
  type        = string
}

variable "export_1_source_cidr" {
  description = "Export 1 source CIDR. Leave empty to use default_source_cidr."
  type        = string
  default     = ""
}

variable "export_1_access" {
  description = "Export 1 access mode."
  type        = string
  default     = "READ_WRITE"
}

variable "export_1_identity_squash" {
  description = "Export 1 identity squash mode."
  type        = string
  default     = "ROOT"
}

variable "add_export_2" {
  description = "Show and create export 2."
  type        = bool
  default     = false
}

variable "export_2_path" {
  description = "Export 2 path."
  type        = string
  default     = ""
}

variable "export_2_source_cidr" {
  description = "Export 2 source CIDR. Leave empty to use default_source_cidr."
  type        = string
  default     = ""
}

variable "export_2_access" {
  description = "Export 2 access mode."
  type        = string
  default     = "READ_WRITE"
}

variable "export_2_identity_squash" {
  description = "Export 2 identity squash mode."
  type        = string
  default     = "ROOT"
}

variable "add_export_3" {
  description = "Show and create export 3."
  type        = bool
  default     = false
}

variable "export_3_path" {
  description = "Export 3 path."
  type        = string
  default     = ""
}

variable "export_3_source_cidr" {
  description = "Export 3 source CIDR. Leave empty to use default_source_cidr."
  type        = string
  default     = ""
}

variable "export_3_access" {
  description = "Export 3 access mode."
  type        = string
  default     = "READ_WRITE"
}

variable "export_3_identity_squash" {
  description = "Export 3 identity squash mode."
  type        = string
  default     = "ROOT"
}

variable "add_export_4" {
  description = "Show and create export 4."
  type        = bool
  default     = false
}

variable "export_4_path" {
  description = "Export 4 path."
  type        = string
  default     = ""
}

variable "export_4_source_cidr" {
  description = "Export 4 source CIDR. Leave empty to use default_source_cidr."
  type        = string
  default     = ""
}

variable "export_4_access" {
  description = "Export 4 access mode."
  type        = string
  default     = "READ_WRITE"
}

variable "export_4_identity_squash" {
  description = "Export 4 identity squash mode."
  type        = string
  default     = "ROOT"
}

variable "add_export_5" {
  description = "Show and create export 5."
  type        = bool
  default     = false
}

variable "export_5_path" {
  description = "Export 5 path."
  type        = string
  default     = ""
}

variable "export_5_source_cidr" {
  description = "Export 5 source CIDR. Leave empty to use default_source_cidr."
  type        = string
  default     = ""
}

variable "export_5_access" {
  description = "Export 5 access mode."
  type        = string
  default     = "READ_WRITE"
}

variable "export_5_identity_squash" {
  description = "Export 5 identity squash mode."
  type        = string
  default     = "ROOT"
}

variable "add_export_6" {
  description = "Show and create export 6."
  type        = bool
  default     = false
}

variable "export_6_path" {
  description = "Export 6 path."
  type        = string
  default     = ""
}

variable "export_6_source_cidr" {
  description = "Export 6 source CIDR. Leave empty to use default_source_cidr."
  type        = string
  default     = ""
}

variable "export_6_access" {
  description = "Export 6 access mode."
  type        = string
  default     = "READ_WRITE"
}

variable "export_6_identity_squash" {
  description = "Export 6 identity squash mode."
  type        = string
  default     = "ROOT"
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

variable "freeform_tags" {
  description = "Programmatic freeform tags merged with Resource Manager tag pair inputs."
  type        = map(string)
  default     = {}
}

variable "tag_1_key" {
  type    = string
  default = ""
}
variable "tag_1_value" {
  type    = string
  default = ""
}
variable "add_tag_2" {
  type    = bool
  default = false
}
variable "tag_2_key" {
  type    = string
  default = ""
}
variable "tag_2_value" {
  type    = string
  default = ""
}
variable "add_tag_3" {
  type    = bool
  default = false
}
variable "tag_3_key" {
  type    = string
  default = ""
}
variable "tag_3_value" {
  type    = string
  default = ""
}
variable "add_tag_4" {
  type    = bool
  default = false
}
variable "tag_4_key" {
  type    = string
  default = ""
}
variable "tag_4_value" {
  type    = string
  default = ""
}
variable "add_tag_5" {
  type    = bool
  default = false
}
variable "tag_5_key" {
  type    = string
  default = ""
}
variable "tag_5_value" {
  type    = string
  default = ""
}
variable "add_tag_6" {
  type    = bool
  default = false
}
variable "tag_6_key" {
  type    = string
  default = ""
}
variable "tag_6_value" {
  type    = string
  default = ""
}
variable "add_tag_7" {
  type    = bool
  default = false
}
variable "tag_7_key" {
  type    = string
  default = ""
}
variable "tag_7_value" {
  type    = string
  default = ""
}
variable "add_tag_8" {
  type    = bool
  default = false
}
variable "tag_8_key" {
  type    = string
  default = ""
}
variable "tag_8_value" {
  type    = string
  default = ""
}
variable "add_tag_9" {
  type    = bool
  default = false
}
variable "tag_9_key" {
  type    = string
  default = ""
}
variable "tag_9_value" {
  type    = string
  default = ""
}
variable "add_tag_10" {
  type    = bool
  default = false
}
variable "tag_10_key" {
  type    = string
  default = ""
}
variable "tag_10_value" {
  type    = string
  default = ""
}
