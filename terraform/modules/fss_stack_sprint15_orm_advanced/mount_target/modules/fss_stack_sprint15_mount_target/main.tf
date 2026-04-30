module "mount_target" {
  source = "./modules/fss_mount_target"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid
  display_name        = var.display_name
  hostname_label      = var.hostname_label
  nsg_ids             = var.nsg_ids
  freeform_tags       = var.freeform_tags
  defined_tags        = var.defined_tags
}

resource "oci_logging_log_group" "mount_target" {
  count = var.enable_logging && var.log_group_id == null ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = var.log_group_name
  description    = "FSS mount target logs for ${var.display_name}."
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

resource "oci_logging_log" "mount_target" {
  count = var.enable_logging ? 1 : 0

  log_group_id       = coalesce(var.log_group_id, try(oci_logging_log_group.mount_target[0].id, null))
  display_name       = var.log_display_name
  log_type           = "SERVICE"
  is_enabled         = true
  retention_duration = var.log_retention_duration
  freeform_tags      = var.freeform_tags
  defined_tags       = var.defined_tags

  configuration {
    source {
      source_type = "OCISERVICE"
      service     = "filestorage"
      resource    = module.mount_target.mount_target_ocid
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
