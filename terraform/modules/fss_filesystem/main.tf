data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
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

resource "oci_file_storage_file_system" "this" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = local.display_name

  defined_tags  = local.defined_tags
  freeform_tags = var.freeform_tags

  lifecycle {
    # OCI injects Oracle-managed defined tags (Oracle-Tags.*). The list data source used for
    # update-mode lookups does not reliably surface defined_tags in all situations, which would
    # otherwise cause perpetual drift (Terraform trying to remove Oracle tags).
    ignore_changes = [defined_tags]
  }
}

