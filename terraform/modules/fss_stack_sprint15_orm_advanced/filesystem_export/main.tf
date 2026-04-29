provider "oci" {
  region = var.region
}

data "oci_file_storage_mount_targets" "selected" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  id                  = var.existing_mount_target_ocid
}

data "oci_core_subnet" "selected_mount_target" {
  subnet_id = local.selected_mount_target.subnet_id
}

locals {
  kms_key_id            = trimspace(var.kms_key_id) == "" ? null : var.kms_key_id
  selected_mount_target = one(data.oci_file_storage_mount_targets.selected.mount_targets)
  mount_target_fqdn     = trimspace(try(local.selected_mount_target.hostname_label, "")) == "" || data.oci_core_subnet.selected_mount_target.subnet_domain_name == null ? null : "${local.selected_mount_target.hostname_label}.${data.oci_core_subnet.selected_mount_target.subnet_domain_name}"
  mount_address         = coalesce(local.mount_target_fqdn, local.selected_mount_target.ip_address)

  export_slots = {
    export_1 = {
      enabled         = true
      path            = var.export_1_path
      source_cidr     = trimspace(var.export_1_source_cidr) == "" ? var.default_source_cidr : var.export_1_source_cidr
      access          = var.export_1_access
      identity_squash = var.export_1_identity_squash
    }
    export_2 = {
      enabled         = var.add_export_2
      path            = var.export_2_path
      source_cidr     = trimspace(var.export_2_source_cidr) == "" ? var.default_source_cidr : var.export_2_source_cidr
      access          = var.export_2_access
      identity_squash = var.export_2_identity_squash
    }
    export_3 = {
      enabled         = var.add_export_2 && var.add_export_3
      path            = var.export_3_path
      source_cidr     = trimspace(var.export_3_source_cidr) == "" ? var.default_source_cidr : var.export_3_source_cidr
      access          = var.export_3_access
      identity_squash = var.export_3_identity_squash
    }
    export_4 = {
      enabled         = var.add_export_2 && var.add_export_3 && var.add_export_4
      path            = var.export_4_path
      source_cidr     = trimspace(var.export_4_source_cidr) == "" ? var.default_source_cidr : var.export_4_source_cidr
      access          = var.export_4_access
      identity_squash = var.export_4_identity_squash
    }
    export_5 = {
      enabled         = var.add_export_2 && var.add_export_3 && var.add_export_4 && var.add_export_5
      path            = var.export_5_path
      source_cidr     = trimspace(var.export_5_source_cidr) == "" ? var.default_source_cidr : var.export_5_source_cidr
      access          = var.export_5_access
      identity_squash = var.export_5_identity_squash
    }
    export_6 = {
      enabled         = var.add_export_2 && var.add_export_3 && var.add_export_4 && var.add_export_5 && var.add_export_6
      path            = var.export_6_path
      source_cidr     = trimspace(var.export_6_source_cidr) == "" ? var.default_source_cidr : var.export_6_source_cidr
      access          = var.export_6_access
      identity_squash = var.export_6_identity_squash
    }
  }

  enabled_exports = {
    for key, slot in local.export_slots : key => slot
    if slot.enabled
  }

  enabled_export_paths = [for slot in values(local.enabled_exports) : slot.path]
}

resource "terraform_data" "validate_exports" {
  input = local.enabled_export_paths

  lifecycle {
    precondition {
      condition     = alltrue([for path in local.enabled_export_paths : startswith(path, "/") && length(trimspace(path)) > 1])
      error_message = "Every enabled export path must start with / and contain more than the root slash."
    }

    precondition {
      condition     = length(local.enabled_export_paths) == length(toset(local.enabled_export_paths))
      error_message = "Enabled export paths must be unique."
    }
  }
}

resource "oci_file_storage_file_system" "this" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = var.filesystem_display_name
  kms_key_id          = local.kms_key_id
  freeform_tags       = var.freeform_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

resource "oci_file_storage_export" "this" {
  for_each = local.enabled_exports

  export_set_id  = local.selected_mount_target.export_set_id
  file_system_id = oci_file_storage_file_system.this.id
  path           = each.value.path

  export_options {
    source                         = each.value.source_cidr
    access                         = each.value.access
    allowed_auth                   = ["SYS"]
    identity_squash                = each.value.identity_squash
    anonymous_uid                  = var.anonymous_uid
    anonymous_gid                  = var.anonymous_gid
    is_anonymous_access_allowed    = false
    require_privileged_source_port = var.require_privileged_source_port
  }

  depends_on = [terraform_data.validate_exports]
}
