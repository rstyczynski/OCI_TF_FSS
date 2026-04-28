#
# Mandatory variables
#

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain name for filesystems and mount targets."
  type        = string
}

variable "subnet_ocid" {
  description = "Subnet OCID where mount targets will be created."
  type        = string
}

variable "kms_key_id" {
  description = "KMS master encryption key OCID used to encrypt all filesystems."
  type        = string
}

variable "filesystems" {
  description = "Map of filesystem stack entries keyed by stable operator names."
  type = map(object({
    filesystem_display_name = string
    export_path             = string

    mount_target_display_name = optional(string)
    source_cidr               = optional(string)

    are_quota_rules_enabled       = optional(bool)
    clone_attach_status           = optional(string)
    detach_clone_trigger          = optional(number)
    filesystem_snapshot_policy_id = optional(string)
    is_lock_override              = optional(bool)
    source_snapshot_id            = optional(string)
    freeform_tags                 = optional(map(string), {})
    defined_tags                  = optional(map(string), {})
    locks = optional(list(object({
      type                = string
      message             = optional(string)
      related_resource_id = optional(string)
      time_created        = optional(string)
    })), [])
    timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
    }))

    hostname_label = optional(string)
    nsg_ids        = optional(list(string))

    access                         = optional(string, "READ_WRITE")
    allowed_auth                   = optional(list(string), ["SYS"])
    identity_squash                = optional(string, "ROOT")
    anonymous_uid                  = optional(number, 65534)
    anonymous_gid                  = optional(number, 65534)
    is_anonymous_access_allowed    = optional(bool, false)
    require_privileged_source_port = optional(bool, false)
  }))
}

#
# Optional variables
#

variable "default_source_cidr" {
  description = "Default client IPv4 CIDR allowed by exports when an entry omits source_cidr."
  type        = string
  default     = null
}
