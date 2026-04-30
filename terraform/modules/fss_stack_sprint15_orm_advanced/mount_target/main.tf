provider "oci" {
  region = var.region
}

locals {
  hostname_label = trimspace(var.hostname_label) == "" ? null : var.hostname_label
  nsg_ids        = length(var.nsg_ids) == 0 ? null : var.nsg_ids
  log_group_id   = trimspace(var.log_group_id) == "" ? null : var.log_group_id

  tag_slots = {
    tag_1  = { enabled = true, key = var.tag_1_key, value = var.tag_1_value }
    tag_2  = { enabled = var.add_tag_2, key = var.tag_2_key, value = var.tag_2_value }
    tag_3  = { enabled = var.add_tag_2 && var.add_tag_3, key = var.tag_3_key, value = var.tag_3_value }
    tag_4  = { enabled = var.add_tag_2 && var.add_tag_3 && var.add_tag_4, key = var.tag_4_key, value = var.tag_4_value }
    tag_5  = { enabled = var.add_tag_2 && var.add_tag_3 && var.add_tag_4 && var.add_tag_5, key = var.tag_5_key, value = var.tag_5_value }
    tag_6  = { enabled = var.add_tag_2 && var.add_tag_3 && var.add_tag_4 && var.add_tag_5 && var.add_tag_6, key = var.tag_6_key, value = var.tag_6_value }
    tag_7  = { enabled = var.add_tag_2 && var.add_tag_3 && var.add_tag_4 && var.add_tag_5 && var.add_tag_6 && var.add_tag_7, key = var.tag_7_key, value = var.tag_7_value }
    tag_8  = { enabled = var.add_tag_2 && var.add_tag_3 && var.add_tag_4 && var.add_tag_5 && var.add_tag_6 && var.add_tag_7 && var.add_tag_8, key = var.tag_8_key, value = var.tag_8_value }
    tag_9  = { enabled = var.add_tag_2 && var.add_tag_3 && var.add_tag_4 && var.add_tag_5 && var.add_tag_6 && var.add_tag_7 && var.add_tag_8 && var.add_tag_9, key = var.tag_9_key, value = var.tag_9_value }
    tag_10 = { enabled = var.add_tag_2 && var.add_tag_3 && var.add_tag_4 && var.add_tag_5 && var.add_tag_6 && var.add_tag_7 && var.add_tag_8 && var.add_tag_9 && var.add_tag_10, key = var.tag_10_key, value = var.tag_10_value }
  }

  enabled_tag_slots = {
    for key, slot in local.tag_slots : key => slot
    if slot.enabled
  }

  tag_pair_keys = [
    for slot in values(local.enabled_tag_slots) : trimspace(slot.key)
    if trimspace(slot.key) != ""
  ]

  tag_pair_freeform_tags = {
    for _, slot in local.enabled_tag_slots : trimspace(slot.key) => slot.value
    if trimspace(slot.key) != ""
  }
}

resource "terraform_data" "validate_tags" {
  input = local.tag_pair_freeform_tags

  lifecycle {
    precondition {
      condition = alltrue([
        for key, slot in local.enabled_tag_slots :
        key == "tag_1"
        ? ((trimspace(slot.key) == "" && trimspace(slot.value) == "") || (trimspace(slot.key) != "" && trimspace(slot.value) != ""))
        : (trimspace(slot.key) != "" && trimspace(slot.value) != "")
      ])
      error_message = "Enabled tag slots must provide both tag key and tag value. Tag 1 may be left empty only when no tags are needed."
    }

    precondition {
      condition     = length(local.tag_pair_keys) == length(toset(local.tag_pair_keys))
      error_message = "Tag keys must be unique."
    }
  }
}

module "fss_stack" {
  source = "./modules/fss_stack_sprint15_mount_target"

  compartment_ocid       = var.compartment_ocid
  availability_domain    = var.availability_domain
  subnet_ocid            = var.subnet_ocid
  display_name           = var.mount_target_display_name
  hostname_label         = local.hostname_label
  nsg_ids                = local.nsg_ids
  freeform_tags          = local.tag_pair_freeform_tags
  defined_tags           = {}
  enable_logging         = var.enable_mount_target_logging
  log_group_id           = local.log_group_id
  log_group_name         = var.log_group_name
  log_display_name       = var.log_display_name
  log_retention_duration = var.log_retention_duration

  depends_on = [terraform_data.validate_tags]
}
