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
  description = "Freeform tags applied to created resources."
  type        = map(string)
  default     = {}
}
