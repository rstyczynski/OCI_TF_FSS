locals {
  effective_source_cidrs = {
    for key, filesystem in var.filesystems :
    key => coalesce(filesystem.source_cidr, var.default_source_cidr)
  }
}

module "filesystem" {
  for_each = var.filesystems

  source = "../fss_sprint5_filesystem"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = each.value.filesystem_display_name
  kms_key_id          = var.kms_key_id

  are_quota_rules_enabled       = each.value.are_quota_rules_enabled
  clone_attach_status           = each.value.clone_attach_status
  detach_clone_trigger          = each.value.detach_clone_trigger
  filesystem_snapshot_policy_id = each.value.filesystem_snapshot_policy_id
  is_lock_override              = each.value.is_lock_override
  source_snapshot_id            = each.value.source_snapshot_id
  freeform_tags                 = each.value.freeform_tags
  defined_tags                  = each.value.defined_tags
  locks                         = each.value.locks
}

module "mount_target" {
  for_each = var.filesystems

  source = "../fss_sprint4_mount_target"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid
  display_name        = coalesce(each.value.mount_target_display_name, "fss-mt-${each.key}")

  hostname_label = each.value.hostname_label
  nsg_ids        = each.value.nsg_ids
}

module "export" {
  for_each = var.filesystems

  source = "../fss_sprint4_export"

  export_set_ocid  = module.mount_target[each.key].mount_target_export_set_ocid
  file_system_ocid = module.filesystem[each.key].filesystem_ocid
  path             = each.value.export_path
  source_cidr      = local.effective_source_cidrs[each.key]

  access                         = each.value.access
  allowed_auth                   = each.value.allowed_auth
  identity_squash                = each.value.identity_squash
  anonymous_uid                  = each.value.anonymous_uid
  anonymous_gid                  = each.value.anonymous_gid
  is_anonymous_access_allowed    = each.value.is_anonymous_access_allowed
  require_privileged_source_port = each.value.require_privileged_source_port
}
