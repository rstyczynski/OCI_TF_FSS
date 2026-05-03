locals {
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
    if !contains(keys(local.logging_created_groups), key) && try(mt.logging.log_id, null) == null
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
    if try(mt.logging.log_id, null) == null && (
      !contains(keys(local.logging_lookup_logs), key) || try(local.existing_log_ids[key], null) == null
    )
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
        try(mt.logging.log_id, null),
        try(local.existing_log_ids[key], null),
        try(oci_logging_log.mount_target[key].id, null)
      )
      log_display_name = local.logging_log_display_names[key]
      service          = "filestorage"
      resource         = module.mount_target[key].mount_target_ocid
      category         = "nfslogs"
      is_enabled = try(mt.logging.log_id, null) != null ? null : (
        try(local.existing_log_ids[key], null) != null ? (
          try(data.oci_logging_logs.mount_target[key].logs[0].is_enabled, null)
        ) : try(oci_logging_log.mount_target[key].is_enabled, null)
      )
      retention_duration = try(mt.logging.log_id, null) != null ? null : (
        try(local.existing_log_ids[key], null) != null ? (
          try(data.oci_logging_logs.mount_target[key].logs[0].retention_duration, null)
        ) : try(oci_logging_log.mount_target[key].retention_duration, null)
      )
    }
  }
}
