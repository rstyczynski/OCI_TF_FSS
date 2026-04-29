provider "oci" {
  region = var.region
}

data "oci_core_subnet" "selected" {
  subnet_id = var.subnet_ocid
}

locals {
  hostname_label = trimspace(var.hostname_label) == "" ? null : var.hostname_label
  nsg_ids        = length(var.nsg_ids) == 0 ? null : var.nsg_ids
  log_group_id   = trimspace(var.log_group_id) == "" ? null : var.log_group_id

  mount_target_fqdn    = local.hostname_label == null || data.oci_core_subnet.selected.subnet_domain_name == null ? null : "${local.hostname_label}.${data.oci_core_subnet.selected.subnet_domain_name}"
  mount_target_address = coalesce(local.mount_target_fqdn, oci_file_storage_mount_target.this.ip_address)
}

resource "oci_file_storage_mount_target" "this" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  subnet_id           = var.subnet_ocid
  display_name        = var.mount_target_display_name
  hostname_label      = local.hostname_label
  nsg_ids             = local.nsg_ids
  freeform_tags       = var.freeform_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

resource "oci_logging_log_group" "mount_target" {
  count = var.enable_mount_target_logging && local.log_group_id == null ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = var.log_group_name
  description    = "FSS mount target logs for ${var.mount_target_display_name}."
  freeform_tags  = var.freeform_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

resource "oci_logging_log" "mount_target" {
  count = var.enable_mount_target_logging ? 1 : 0

  log_group_id       = coalesce(local.log_group_id, try(oci_logging_log_group.mount_target[0].id, null))
  display_name       = var.log_display_name
  log_type           = "SERVICE"
  is_enabled         = true
  retention_duration = var.log_retention_duration
  freeform_tags      = var.freeform_tags

  configuration {
    source {
      source_type = "OCISERVICE"
      service     = "filestorage"
      resource    = oci_file_storage_mount_target.this.id
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
