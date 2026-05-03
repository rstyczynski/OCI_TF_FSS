data "oci_core_subnet" "default" {
  subnet_id = var.subnet_ocid
}

data "oci_identity_availability_domains" "ads" {
  count = var.availability_domain == null ? 1 : 0

  compartment_id = var.compartment_ocid
}

resource "random_shuffle" "picked_ad" {
  count = var.availability_domain == null ? 1 : 0

  input        = local.ad_names
  result_count = 1
}

locals {
  ad_names = sort([
    for ad in try(data.oci_identity_availability_domains.ads[0].availability_domains, []) : ad.name
  ])

  default_subnet_availability_domain_raw = try(data.oci_core_subnet.default.availability_domain, null)
  default_subnet_availability_domain     = try(length(trimspace(local.default_subnet_availability_domain_raw)) > 0, false) ? local.default_subnet_availability_domain_raw : null
  random_ad_name                         = length(random_shuffle.picked_ad) > 0 ? random_shuffle.picked_ad[0].result[0] : null
  default_effective_availability_domain  = coalesce(var.availability_domain, local.default_subnet_availability_domain, local.random_ad_name)

  kms_key_mode = var.kms_key_id == null ? "ORACLE_MANAGED" : "CUSTOMER_MANAGED"

  exports_flat = length(var.filesystems) == 0 ? {} : merge([
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

  effective_mount_target_subnet_ocids = {
    for key, mt in var.mount_targets :
    key => coalesce(try(mt.subnet_ocid, null), var.subnet_ocid)
  }

  effective_mount_target_availability_domains = {
    for key, mt in var.mount_targets :
    key => coalesce(try(mt.availability_domain, null), local.default_effective_availability_domain)
  }

  managed_mount_targets = {
    for key, mt in var.mount_targets : key => mt
    if try(mt.external_ocid, null) == null
  }

  external_mount_targets = {
    for key, mt in var.mount_targets : key => mt
    if try(mt.external_ocid, null) != null
  }

  logging_enabled_mount_targets = {
    for key, mt in local.managed_mount_targets : key => mt
    if try(mt.logging.enabled, false)
  }

  logging_lookup_groups = {
    for key, mt in local.logging_enabled_mount_targets : key => mt
    if try(mt.logging.log_group_id, null) == null
  }

  logging_log_group_names = {
    for key, mt in local.logging_enabled_mount_targets :
    key => coalesce(try(mt.logging.log_group_name, null), "fss-${key}-logs")
  }

  logging_log_display_names = {
    for key, mt in local.logging_enabled_mount_targets :
    key => coalesce(try(mt.logging.log_display_name, null), "fss-${key}-nfs")
  }
}

data "oci_core_subnet" "mount_target" {
  for_each  = var.mount_targets
  subnet_id = local.effective_mount_target_subnet_ocids[each.key]
}

module "mount_target" {
  for_each = local.managed_mount_targets

  source = "./modules/fss_mount_target"

  compartment_ocid    = var.compartment_ocid
  availability_domain = local.effective_mount_target_availability_domains[each.key]
  subnet_ocid         = local.effective_mount_target_subnet_ocids[each.key]
  display_name        = coalesce(each.value.display_name, "fss-mt-${each.key}")
  hostname_label      = each.value.hostname_label
  nsg_ids             = each.value.nsg_ids
  freeform_tags       = each.value.freeform_tags
  defined_tags        = each.value.defined_tags
}

data "oci_file_storage_mount_targets" "external" {
  for_each = local.external_mount_targets

  compartment_id      = var.compartment_ocid
  availability_domain = local.effective_mount_target_availability_domains[each.key]
  id                  = each.value.external_ocid
}

locals {
  external_selected_mount_targets = {
    for key, _ in local.external_mount_targets :
    key => one(data.oci_file_storage_mount_targets.external[key].mount_targets)
  }
}

data "oci_core_private_ip" "external_mount_target" {
  for_each = local.external_mount_targets

  private_ip_id = local.external_selected_mount_targets[each.key].private_ip_ids[0]
}

locals {
  external_mount_target_hostname_labels = {
    for key, mt in local.external_selected_mount_targets :
    key => try(mt.hostname_label, null)
  }

  external_mount_target_fqdns = {
    for key, mt in local.external_selected_mount_targets :
    key => (
      local.external_mount_target_hostname_labels[key] == null || try(data.oci_core_subnet.mount_target[key].subnet_domain_name, null) == null
      ? null
      : "${local.external_mount_target_hostname_labels[key]}.${data.oci_core_subnet.mount_target[key].subnet_domain_name}"
    )
  }

  resolved_mount_targets = merge(
    {
      for key, mt in module.mount_target : key => {
        ocid            = mt.mount_target_ocid
        display_name    = mt.mount_target_display_name
        export_set_ocid = mt.mount_target_export_set_ocid
        private_ip_ids  = mt.mount_target_private_ip_ids
        ip_address      = mt.mount_target_ip_address
        fqdn            = mt.mount_target_fqdn
        mount_address   = mt.mount_target_mount_address

        subnet_ocid         = local.effective_mount_target_subnet_ocids[key]
        availability_domain = local.effective_mount_target_availability_domains[key]

        external_ocid = null
      }
    },
    {
      for key, mt in local.external_selected_mount_targets : key => {
        ocid            = mt.id
        display_name    = mt.display_name
        export_set_ocid = mt.export_set_id
        private_ip_ids  = mt.private_ip_ids
        ip_address      = data.oci_core_private_ip.external_mount_target[key].ip_address
        fqdn            = local.external_mount_target_fqdns[key]
        mount_address   = coalesce(local.external_mount_target_fqdns[key], data.oci_core_private_ip.external_mount_target[key].ip_address)

        subnet_ocid         = local.effective_mount_target_subnet_ocids[key]
        availability_domain = local.effective_mount_target_availability_domains[key]

        external_ocid = var.mount_targets[key].external_ocid
      }
    }
  )
}

resource "terraform_data" "validate_external_mount_targets" {
  for_each = local.external_mount_targets

  input = each.value.external_ocid

  lifecycle {
    precondition {
      condition     = local.external_selected_mount_targets[each.key].subnet_id == local.effective_mount_target_subnet_ocids[each.key]
      error_message = "External mount target '${each.key}' subnet_id does not match effective subnet_ocid for this mount target entry."
    }
    precondition {
      condition     = local.external_selected_mount_targets[each.key].availability_domain == local.effective_mount_target_availability_domains[each.key]
      error_message = "External mount target '${each.key}' availability_domain does not match effective availability_domain for this mount target entry."
    }
  }
}

resource "terraform_data" "validate_export_mount_target_keys" {
  for_each = local.exports_flat

  input = each.value.export.mount_target_key

  lifecycle {
    precondition {
      condition     = contains(keys(var.mount_targets), each.value.export.mount_target_key)
      error_message = "Export '${each.key}' references mount_target_key='${each.value.export.mount_target_key}', but no such key exists in var.mount_targets."
    }
  }
}

module "filesystem" {
  for_each = var.filesystems

  source = "./modules/fss_filesystem"

  compartment_ocid    = var.compartment_ocid
  availability_domain = local.default_effective_availability_domain
  display_name        = each.value.display_name
  kms_key_id          = var.kms_key_id
  freeform_tags       = each.value.freeform_tags
  defined_tags        = each.value.defined_tags
}

module "export" {
  for_each = local.exports_flat

  source = "./modules/fss_export"

  export_set_ocid  = local.resolved_mount_targets[each.value.export.mount_target_key].export_set_ocid
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

data "oci_logging_log_groups" "mount_target" {
  for_each = local.logging_lookup_groups

  compartment_id = var.compartment_ocid
  display_name   = local.logging_log_group_names[each.key]
}

resource "terraform_data" "validate_logging_log_groups" {
  for_each = data.oci_logging_log_groups.mount_target

  input = local.logging_log_group_names[each.key]

  lifecycle {
    precondition {
      condition     = length(each.value.log_groups) <= 1
      error_message = "Expected at most one OCI Logging log group named '${local.logging_log_group_names[each.key]}' in compartment '${var.compartment_ocid}', but found ${length(each.value.log_groups)}."
    }
  }
}

locals {
  existing_log_group_ids = {
    for key, result in data.oci_logging_log_groups.mount_target :
    key => length(result.log_groups) == 1 ? result.log_groups[0].id : null
  }

  logging_created_groups = {
    for key, mt in local.logging_enabled_mount_targets : key => mt
    if try(mt.logging.log_group_id, null) == null && try(local.existing_log_group_ids[key], null) == null
  }
}

resource "oci_logging_log_group" "mount_target" {
  for_each = local.logging_created_groups

  compartment_id = var.compartment_ocid
  display_name   = local.logging_log_group_names[each.key]
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

locals {
  resolved_log_group_ids = {
    for key, mt in local.logging_enabled_mount_targets :
    key => coalesce(
      try(mt.logging.log_group_id, null),
      try(local.existing_log_group_ids[key], null),
      try(oci_logging_log_group.mount_target[key].id, null)
    )
  }

  logging_lookup_logs = {
    for key, mt in local.logging_enabled_mount_targets : key => mt
    if !contains(keys(local.logging_created_groups), key)
  }
}

data "oci_logging_logs" "mount_target" {
  for_each = local.logging_lookup_logs

  log_group_id = local.resolved_log_group_ids[each.key]
  display_name = local.logging_log_display_names[each.key]
}

resource "terraform_data" "validate_logging_logs" {
  for_each = data.oci_logging_logs.mount_target

  input = local.logging_log_display_names[each.key]

  lifecycle {
    precondition {
      condition     = length(each.value.logs) <= 1
      error_message = "Expected at most one OCI Logging log named '${local.logging_log_display_names[each.key]}' in log group '${local.resolved_log_group_ids[each.key]}', but found ${length(each.value.logs)}."
    }

    precondition {
      condition = length(each.value.logs) == 0 || try((
        each.value.logs[0].log_type == "SERVICE"
        && try(each.value.logs[0].configuration[0].source[0].service, null) == "filestorage"
        && try(each.value.logs[0].configuration[0].source[0].resource, null) == module.mount_target[each.key].mount_target_ocid
        && try(each.value.logs[0].configuration[0].source[0].category, null) == "nfslogs"
      ), false)
      error_message = "Existing OCI Logging log '${local.logging_log_display_names[each.key]}' in log group '${local.resolved_log_group_ids[each.key]}' is not the expected File Storage NFS service log for mount target '${module.mount_target[each.key].mount_target_ocid}'."
    }
  }
}

locals {
  existing_log_ids = {
    for key, result in data.oci_logging_logs.mount_target :
    key => length(result.logs) == 1 ? result.logs[0].id : null
  }

  logging_created_logs = {
    for key, mt in local.logging_enabled_mount_targets : key => mt
    if !contains(keys(local.logging_lookup_logs), key) || try(local.existing_log_ids[key], null) == null
  }
}

resource "oci_logging_log" "mount_target" {
  for_each = local.logging_created_logs

  log_group_id       = local.resolved_log_group_ids[each.key]
  display_name       = local.logging_log_display_names[each.key]
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

locals {
  resolved_mount_target_logging = {
    for key, mt in local.logging_enabled_mount_targets : key => {
      log_group_ocid = local.resolved_log_group_ids[key]
      log_ocid = coalesce(
        try(local.existing_log_ids[key], null),
        try(oci_logging_log.mount_target[key].id, null)
      )
      log_display_name = local.logging_log_display_names[key]
      service          = "filestorage"
      resource         = module.mount_target[key].mount_target_ocid
      category         = "nfslogs"
      is_enabled = try(local.existing_log_ids[key], null) != null ? (
        try(data.oci_logging_logs.mount_target[key].logs[0].is_enabled, null)
      ) : try(oci_logging_log.mount_target[key].is_enabled, null)
      retention_duration = try(local.existing_log_ids[key], null) != null ? (
        try(data.oci_logging_logs.mount_target[key].logs[0].retention_duration, null)
      ) : try(oci_logging_log.mount_target[key].retention_duration, null)
    }
  }
}
