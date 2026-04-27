data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

resource "random_shuffle" "picked_ad" {
  count        = var.availability_domain == null ? 1 : 0
  input        = local.ad_names
  result_count = 1
}

locals {
  # Sort so random_shuffle input is stable across refreshes (API order is not guaranteed).
  ad_names = sort([for ad in data.oci_identity_availability_domains.ads.availability_domains : ad.name])
  # picked_ad is absent when var.availability_domain is set (random_shuffle count = 0).
  random_ad_name = length(random_shuffle.picked_ad) > 0 ? random_shuffle.picked_ad[0].result[0] : null
}

