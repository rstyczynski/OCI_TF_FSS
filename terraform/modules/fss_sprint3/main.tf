resource "oci_file_storage_file_system" "this" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = var.display_name

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags

  lifecycle {
    ignore_changes = [
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}
