locals {
  availability_domain = trimspace(var.availability_domain) == "" ? null : var.availability_domain
  kms_key_id          = trimspace(var.kms_key_id) == "" ? null : var.kms_key_id
  hostname_label      = trimspace(var.mount_target_hostname_label) == "" ? null : var.mount_target_hostname_label
  export_source       = trimspace(var.export_source_cidr) == "" ? null : var.export_source_cidr
  log_group_id        = trimspace(var.log_group_id) == "" ? null : var.log_group_id

  mount_target_logging = var.enable_mount_target_logging ? {
    enabled            = true
    log_group_id       = local.log_group_id
    log_group_name     = var.log_group_name
    log_display_name   = var.log_display_name
    retention_duration = var.log_retention_duration
    freeform_tags      = var.freeform_tags
    defined_tags       = {}
  } : null
}

provider "oci" {
  region = var.region
}

module "fss" {
  source = "./modules/fss_stack_sprint12"

  compartment_ocid    = var.compartment_ocid
  subnet_ocid         = var.subnet_ocid
  availability_domain = local.availability_domain
  kms_key_id          = local.kms_key_id
  default_source_cidr = var.default_source_cidr

  mount_targets = {
    primary = {
      display_name   = var.mount_target_display_name
      hostname_label = local.hostname_label
      nsg_ids        = length(var.mount_target_nsg_ids) == 0 ? null : var.mount_target_nsg_ids
      freeform_tags  = var.freeform_tags
      defined_tags   = {}
      logging        = local.mount_target_logging
    }
  }

  filesystems = {
    data = {
      display_name  = var.filesystem_display_name
      freeform_tags = var.freeform_tags
      defined_tags  = {}
      exports = {
        primary = {
          mount_target_key               = "primary"
          path                           = var.export_path
          source                         = local.export_source
          access                         = var.export_access
          allowed_auth                   = ["SYS"]
          identity_squash                = var.identity_squash
          anonymous_uid                  = var.anonymous_uid
          anonymous_gid                  = var.anonymous_gid
          is_anonymous_access_allowed    = var.is_anonymous_access_allowed
          require_privileged_source_port = var.require_privileged_source_port
        }
      }
    }
  }
}
