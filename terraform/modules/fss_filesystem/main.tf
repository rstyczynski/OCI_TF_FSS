data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

locals {
  ad_names = [for ad in data.oci_identity_availability_domains.ads.availability_domains : ad.name]
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

resource "oci_file_storage_file_system" "this" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = local.display_name

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}

