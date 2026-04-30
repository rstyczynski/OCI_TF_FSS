#
# Mandatory variables
#

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
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

variable "kms_key_id" {
  description = "KMS master encryption key OCID used to encrypt the filesystem."
  type        = string
}

#
# Optional variables
#

variable "are_quota_rules_enabled" {
  description = "Whether quota rules are enabled for the filesystem."
  type        = bool
  default     = null
}

variable "clone_attach_status" {
  description = "Advanced OCI provider pass-through for clone attach status."
  type        = string
  default     = null
}

variable "detach_clone_trigger" {
  description = "Advanced OCI provider pass-through for detach clone trigger."
  type        = number
  default     = null
}

variable "filesystem_snapshot_policy_id" {
  description = "Filesystem snapshot policy OCID to associate with the filesystem."
  type        = string
  default     = null
}

variable "is_lock_override" {
  description = "Whether to override locks during filesystem operations."
  type        = bool
  default     = null
}

variable "source_snapshot_id" {
  description = "Snapshot OCID to use as the filesystem source."
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

variable "locks" {
  description = "Optional filesystem locks."
  type = list(object({
    type                = string
    message             = optional(string)
    related_resource_id = optional(string)
    time_created        = optional(string)
  }))
  default = []
}

variable "timeouts" {
  description = "Optional Terraform operation timeouts for the filesystem."
  type = object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default = null
}

