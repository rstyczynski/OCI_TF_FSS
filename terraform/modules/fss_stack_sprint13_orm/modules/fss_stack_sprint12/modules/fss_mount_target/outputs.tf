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

output "mount_target_ip_address" {
  description = "Primary private IP address assigned to the mount target."
  value       = oci_file_storage_mount_target.this.ip_address
}

output "mount_target_fqdn" {
  description = "DNS name for the mount target when hostname_label and subnet DNS are available."
  value       = local.mount_target_fqdn
}

output "mount_target_mount_address" {
  description = "Preferred NFS server address for mounting; FQDN when available, otherwise private IP address."
  value       = coalesce(local.mount_target_fqdn, oci_file_storage_mount_target.this.ip_address)
}

output "availability_domain" {
  description = "Availability Domain used for the mount target."
  value       = oci_file_storage_mount_target.this.availability_domain
}

output "subnet_ocid" {
  description = "Subnet OCID used for the mount target."
  value       = oci_file_storage_mount_target.this.subnet_id
}
