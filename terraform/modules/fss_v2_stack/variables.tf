#
# Mandatory variables
#

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
}

variable "subnet_ocid" {
  description = "Subnet OCID where mount targets will be created."
  type        = string
}

#
# Optional variables
#

variable "availability_domain" {
  description = "Availability Domain name for filesystems and mount targets. When omitted, v2 derives it from the subnet or randomly selects a regional AD using the Sprint 2 pattern."
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "Optional KMS master encryption key OCID used to encrypt all filesystems. When omitted, OCI File Storage uses Oracle-managed encryption."
  type        = string
  default     = null
}

variable "default_source_cidr" {
  description = "Default client IPv4 CIDR allowed by exports when an entry omits source."
  type        = string
  default     = "0.0.0.0/0"
}

variable "mount_targets" {
  description = "Map of mount targets keyed by stable operator names. Exports reference these keys via exports[*].mount_target_key."
  type = map(object({
    display_name   = optional(string)
    hostname_label = optional(string)
    nsg_ids        = optional(list(string))
    freeform_tags  = optional(map(string), {})
    defined_tags   = optional(map(string), {})
    logging = optional(object({
      enabled            = optional(bool, false)
      log_group_id       = optional(string)
      log_group_name     = optional(string)
      log_display_name   = optional(string)
      retention_duration = optional(number, 30)
      freeform_tags      = optional(map(string), {})
      defined_tags       = optional(map(string), {})
    }))
  }))
  default = {}
}

variable "filesystems" {
  description = "Map of filesystem entries keyed by stable operator names. Each filesystem may have multiple exports; each export targets a mount target by key."
  type = map(object({
    display_name  = string
    freeform_tags = optional(map(string), {})
    defined_tags  = optional(map(string), {})
    exports = optional(map(object({
      mount_target_key               = string
      path                           = string
      source                         = optional(string, null)
      access                         = optional(string, "READ_WRITE")
      allowed_auth                   = optional(list(string), ["SYS"])
      identity_squash                = optional(string, "ROOT")
      anonymous_uid                  = optional(number, 65534)
      anonymous_gid                  = optional(number, 65534)
      is_anonymous_access_allowed    = optional(bool, false)
      require_privileged_source_port = optional(bool, false)
    })), {})
  }))
  default = {}
}
