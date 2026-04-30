resource "oci_file_storage_file_system" "this" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = var.display_name
  kms_key_id          = var.kms_key_id

  are_quota_rules_enabled       = var.are_quota_rules_enabled
  clone_attach_status           = var.clone_attach_status
  detach_clone_trigger          = var.detach_clone_trigger
  filesystem_snapshot_policy_id = var.filesystem_snapshot_policy_id
  is_lock_override              = var.is_lock_override
  source_snapshot_id            = var.source_snapshot_id

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags

  dynamic "locks" {
    for_each = var.locks

    content {
      type                = locks.value.type
      message             = try(locks.value.message, null)
      related_resource_id = try(locks.value.related_resource_id, null)
      time_created        = try(locks.value.time_created, null)
    }
  }

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = try(timeouts.value.create, null)
      update = try(timeouts.value.update, null)
      delete = try(timeouts.value.delete, null)
    }
  }

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

