locals {
  exports_flat = merge([
    for fs_key, fs in var.filesystems : {
      for export_key, export in fs.exports :
      "${fs_key}__${export_key}" => {
        fs_key     = fs_key
        export_key = export_key
        export     = export
      }
    }
  ]...)

  effective_sources = {
    for composite_key, pair in local.exports_flat :
    composite_key => coalesce(pair.export.source, var.default_source_cidr)
  }

  logging_enabled_mount_targets = {
    for key, mt in var.mount_targets : key => mt
    if try(mt.logging.enabled, false)
  }

  logging_created_groups = {
    for key, mt in local.logging_enabled_mount_targets : key => mt
    if try(mt.logging.log_group_id, null) == null
  }
}

module "mount_target" {
  for_each = var.mount_targets

  source = "../fss_sprint4_mount_target"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid
  display_name        = coalesce(each.value.display_name, "fss-mt-${each.key}")
  hostname_label      = each.value.hostname_label
  nsg_ids             = each.value.nsg_ids
  freeform_tags       = each.value.freeform_tags
  defined_tags        = each.value.defined_tags
}

module "filesystem" {
  for_each = var.filesystems

  source = "../fss_sprint5_filesystem"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = each.value.display_name
  kms_key_id          = var.kms_key_id
  freeform_tags       = each.value.freeform_tags
  defined_tags        = each.value.defined_tags
}

module "export" {
  for_each = local.exports_flat

  source = "../fss_sprint4_export"

  export_set_ocid  = module.mount_target[each.value.export.mount_target_key].mount_target_export_set_ocid
  file_system_ocid = module.filesystem[each.value.fs_key].filesystem_ocid
  path             = each.value.export.path
  source_cidr      = local.effective_sources[each.key]

  access                         = each.value.export.access
  allowed_auth                   = each.value.export.allowed_auth
  identity_squash                = each.value.export.identity_squash
  anonymous_uid                  = each.value.export.anonymous_uid
  anonymous_gid                  = each.value.export.anonymous_gid
  is_anonymous_access_allowed    = each.value.export.is_anonymous_access_allowed
  require_privileged_source_port = each.value.export.require_privileged_source_port
}

resource "oci_logging_log_group" "mount_target" {
  for_each = local.logging_created_groups

  compartment_id = var.compartment_ocid
  display_name   = coalesce(each.value.logging.log_group_name, "fss-${each.key}-logs")
  description    = "FSS mount target logs for ${each.key}."
  freeform_tags  = each.value.logging.freeform_tags
  defined_tags   = each.value.logging.defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

resource "oci_logging_log" "mount_target" {
  for_each = local.logging_enabled_mount_targets

  log_group_id       = coalesce(try(each.value.logging.log_group_id, null), try(oci_logging_log_group.mount_target[each.key].id, null))
  display_name       = coalesce(each.value.logging.log_display_name, "fss-${each.key}-nfs")
  log_type           = "SERVICE"
  is_enabled         = true
  retention_duration = each.value.logging.retention_duration
  freeform_tags      = each.value.logging.freeform_tags
  defined_tags       = each.value.logging.defined_tags

  configuration {
    source {
      source_type = "OCISERVICE"
      service     = "filestorage"
      resource    = module.mount_target[each.key].mount_target_ocid
      category    = "nfslogs"
    }
  }

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}
