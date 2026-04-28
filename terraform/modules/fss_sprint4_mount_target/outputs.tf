output "mount_target_ocid" {
  description = "OCID of the created mount target."
  value       = oci_file_storage_mount_target.this.id
}

output "mount_target_display_name" {
  description = "Display name used for the mount target."
  value       = oci_file_storage_mount_target.this.display_name
}

output "mount_target_export_set_ocid" {
  description = "Export set OCID associated with the mount target."
  value       = oci_file_storage_mount_target.this.export_set_id
}

output "mount_target_private_ip_ids" {
  description = "Private IP OCIDs associated with the mount target."
  value       = oci_file_storage_mount_target.this.private_ip_ids
}

output "availability_domain" {
  description = "Availability Domain used for the mount target."
  value       = oci_file_storage_mount_target.this.availability_domain
}

output "subnet_ocid" {
  description = "Subnet OCID used for the mount target."
  value       = oci_file_storage_mount_target.this.subnet_id
}
