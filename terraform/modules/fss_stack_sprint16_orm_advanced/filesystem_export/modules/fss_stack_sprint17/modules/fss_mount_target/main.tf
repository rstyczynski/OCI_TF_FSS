data "oci_core_subnet" "this" {
  subnet_id = var.subnet_ocid
}

locals {
  mount_target_fqdn = var.hostname_label == null || data.oci_core_subnet.this.subnet_domain_name == null ? null : "${var.hostname_label}.${data.oci_core_subnet.this.subnet_domain_name}"
}

resource "oci_file_storage_mount_target" "this" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  subnet_id           = var.subnet_ocid
  display_name        = var.display_name

  hostname_label = var.hostname_label
  nsg_ids        = var.nsg_ids

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

