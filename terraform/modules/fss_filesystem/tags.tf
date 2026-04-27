variable "oracle_managed_defined_tag_keys" {
  description = "Allowlist of Oracle-managed defined tag keys to preserve/merge (example: Oracle-Tags.CreatedBy, Oracle-Tags.CreatedOn)."
  type        = set(string)
  default     = ["Oracle-Tags.CreatedBy", "Oracle-Tags.CreatedOn"]
}

data "oci_file_storage_file_systems" "by_compartment" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.availability_domain
  display_name        = local.display_name
}

locals {
  existing_filesystem = try(
    one(try(data.oci_file_storage_file_systems.by_compartment.file_systems, [])),
    null
  )

  # Create mode (no existing filesystem): do not attempt to preserve Oracle tags.
  oracle_managed_defined_tags = local.existing_filesystem == null ? {} : {
    for k, v in try(local.existing_filesystem.defined_tags, {}) :
    k => v
    if contains(var.oracle_managed_defined_tag_keys, k)
  }

  defined_tags = merge(var.defined_tags, local.oracle_managed_defined_tags)
}  