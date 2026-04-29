variable "region" {
  description = "OCI region used by the Resource Manager provider runner."
  type        = string
}

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain where the mount target will be created."
  type        = string
}

variable "subnet_ocid" {
  description = "Subnet OCID where the mount target will be created."
  type        = string
}

variable "mount_target_display_name" {
  description = "Mount target display name."
  type        = string
  default     = "fss-orm-mount-target"
}

variable "hostname_label" {
  description = "Optional DNS hostname label for the mount target."
  type        = string
  default     = ""
}

variable "nsg_ids" {
  description = "Optional Network Security Group OCIDs."
  type        = list(string)
  default     = []
}

variable "enable_mount_target_logging" {
  description = "Create or enable an OCI File Storage NFS service log for the mount target."
  type        = bool
  default     = false
}

variable "log_group_id" {
  description = "Existing log group OCID. Leave empty to create one when logging is enabled."
  type        = string
  default     = ""
}

variable "log_group_name" {
  description = "Display name for a created log group."
  type        = string
  default     = "fss-orm-mount-target-logs"
}

variable "log_display_name" {
  description = "Display name for the File Storage NFS service log."
  type        = string
  default     = "fss-orm-mount-target-nfs"
}

variable "log_retention_duration" {
  description = "Log retention duration in days."
  type        = number
  default     = 30
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
