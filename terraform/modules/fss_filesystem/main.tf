data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

variable "oracle_managed_defined_tag_keys" {
  description = "Allowlist of Oracle-managed defined tag keys to preserve/merge (example: Oracle-Tags.CreatedBy, Oracle-Tags.CreatedOn)."
  type        = set(string)
  default     = ["Oracle-Tags.CreatedBy", "Oracle-Tags.CreatedOn"]

  validation {
    condition = alltrue([
      for k in var.oracle_managed_defined_tag_keys :
      can(regex("^Oracle-Tags\\.[A-Za-z0-9_]+$", k))
    ])
    error_message = "oracle_managed_defined_tag_keys entries must be Oracle-Tags.<Name> (example: Oracle-Tags.CreatedOn)."
  }
}

locals {
  # Sort so random_shuffle input is stable across refreshes (API order is not guaranteed).
  ad_names = sort([for ad in data.oci_identity_availability_domains.ads.availability_domains : ad.name])
}

resource "random_shuffle" "picked_ad" {
  count        = var.availability_domain == null ? 1 : 0
  input        = local.ad_names
  result_count = 1
}

locals {
  display_name        = var.display_name != null ? var.display_name : "${var.name_prefix}-filesystem"
  availability_domain = var.availability_domain != null ? var.availability_domain : random_shuffle.picked_ad[0].result[0]
}

data "oci_file_storage_file_systems" "by_compartment" {
  compartment_id = var.compartment_ocid
  availability_domain = local.availability_domain
  display_name        = local.display_name
}

locals {
  existing_filesystem = try(
    one(try(data.oci_file_storage_file_systems.by_compartment.file_systems, [])),
    null
  )
}

locals {
  # Create mode (no existing filesystem): do not attempt to preserve Oracle tags.
  oracle_managed_defined_tags = local.existing_filesystem == null ? {} : {
    for k, v in try(local.existing_filesystem.defined_tags, {}) :
    k => v
    if contains(var.oracle_managed_defined_tag_keys, k)
  }

  defined_tags = merge(var.defined_tags, local.oracle_managed_defined_tags)
}

resource "oci_file_storage_file_system" "this" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = local.display_name

  defined_tags  = local.defined_tags
  freeform_tags = var.freeform_tags
}

