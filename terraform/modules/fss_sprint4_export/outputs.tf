output "export_ocid" {
  description = "OCID of the created export."
  value       = oci_file_storage_export.this.id
}

output "export_path" {
  description = "NFS export path."
  value       = oci_file_storage_export.this.path
}

output "export_set_ocid" {
  description = "Export set OCID used by the export."
  value       = oci_file_storage_export.this.export_set_id
}

output "file_system_ocid" {
  description = "Filesystem OCID used by the export."
  value       = oci_file_storage_export.this.file_system_id
}

output "identity_squash" {
  description = "Identity squash mode applied to the export option."
  value       = oci_file_storage_export.this.export_options[0].identity_squash
}
