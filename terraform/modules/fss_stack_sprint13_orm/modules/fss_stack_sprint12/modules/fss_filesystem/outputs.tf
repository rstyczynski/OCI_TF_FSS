output "filesystem_ocid" {
  description = "OCID of the created filesystem."
  value       = oci_file_storage_file_system.this.id
}

output "filesystem_display_name" {
  description = "Display name used for the filesystem."
  value       = oci_file_storage_file_system.this.display_name
}

output "availability_domain" {
  description = "Availability Domain used for the filesystem."
  value       = oci_file_storage_file_system.this.availability_domain
}

output "kms_key_id" {
  description = "KMS master encryption key OCID used by the filesystem."
  value       = oci_file_storage_file_system.this.kms_key_id
}

output "freeform_tags" {
  description = "Freeform tags applied to the filesystem."
  value       = oci_file_storage_file_system.this.freeform_tags
}
