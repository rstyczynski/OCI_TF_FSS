#
# Mandatory variables
#

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
}

variable "subnet_ocid" {
  description = "Subnet OCID where the FSS mount target will be created."
  type        = string
}

variable "region" {
  description = "OCI region used by the Resource Manager provider runner."
  type        = string
}

#
# Optional variables
#

variable "availability_domain" {
  description = "Optional Availability Domain override. Leave empty to derive from subnet or regional AD selection."
  type        = string
  default     = ""
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key OCID. Leave empty for Oracle-managed encryption."
  type        = string
  default     = ""
}

variable "default_source_cidr" {
  description = "Default client IPv4 CIDR allowed by the export."
  type        = string
  default     = "0.0.0.0/0"
}

variable "mount_target_display_name" {
  description = "Mount target display name."
  type        = string
  default     = "fss-orm-mount-target"
}

variable "mount_target_hostname_label" {
  description = "Optional mount target hostname label."
  type        = string
  default     = ""
}

variable "mount_target_nsg_ids" {
  description = "Optional NSG OCIDs attached to the mount target."
  type        = list(string)
  default     = []
}

variable "filesystem_display_name" {
  description = "Filesystem display name."
  type        = string
  default     = "fss-orm-filesystem"
}

variable "export_path" {
  description = "NFS export path."
  type        = string
  default     = "/data"
}

variable "export_source_cidr" {
  description = "Optional client CIDR for the export. Leave empty to use default_source_cidr."
  type        = string
  default     = ""
}

variable "export_access" {
  description = "Export access mode."
  type        = string
  default     = "READ_WRITE"

  validation {
    condition     = contains(["READ_WRITE", "READ_ONLY"], var.export_access)
    error_message = "export_access must be READ_WRITE or READ_ONLY."
  }
}

variable "identity_squash" {
  description = "NFS identity squash behavior."
  type        = string
  default     = "ROOT"

  validation {
    condition     = contains(["ROOT", "NONE"], var.identity_squash)
    error_message = "identity_squash must be ROOT or NONE."
  }
}

variable "anonymous_uid" {
  description = "Anonymous UID for squashed access."
  type        = number
  default     = 65534
}

variable "anonymous_gid" {
  description = "Anonymous GID for squashed access."
  type        = number
  default     = 65534
}

variable "is_anonymous_access_allowed" {
  description = "Whether anonymous access is allowed."
  type        = bool
  default     = false
}

variable "require_privileged_source_port" {
  description = "Whether clients must use privileged source ports."
  type        = bool
  default     = false
}

variable "enable_mount_target_logging" {
  description = "Whether to enable OCI File Storage NFS service logs for the mount target."
  type        = bool
  default     = false
}

variable "log_group_id" {
  description = "Optional existing log group OCID. Leave empty to create a log group when logging is enabled."
  type        = string
  default     = ""
}

variable "log_group_name" {
  description = "Display name for a created log group."
  type        = string
  default     = "fss-orm-logs"
}

variable "log_display_name" {
  description = "Display name for the FSS NFS service log."
  type        = string
  default     = "fss-orm-nfs"
}

variable "log_retention_duration" {
  description = "Log retention duration in days."
  type        = number
  default     = 30
}

variable "freeform_tags" {
  description = "Freeform tags applied to created FSS and logging resources."
  type        = map(string)
  default     = {}
}
