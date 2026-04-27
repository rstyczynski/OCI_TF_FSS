

locals {
  display_name          = var.display_name != null ? var.display_name : "${var.name_prefix}-filesystem"
  availability_domain   = coalesce(var.availability_domain, local.random_ad_name)
}

resource "oci_file_storage_file_system" "this" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = local.display_name

  defined_tags  = local.defined_tags
  freeform_tags = var.freeform_tags
}

