data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

locals {
  display_name        = var.display_name != null ? var.display_name : "${var.name_prefix}-filesystem"
  availability_domain = var.availability_domain != null ? var.availability_domain : data.oci_identity_availability_domains.ads.availability_domains[0].name
}

resource "oci_file_storage_file_system" "this" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = local.display_name

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}

