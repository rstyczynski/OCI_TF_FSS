output "mount_target_ocid" {
  description = "OCID of the created mount target."
  value       = oci_file_storage_mount_target.this.id
}

output "export_set_ocid" {
  description = "Export set OCID associated with the created mount target."
  value       = oci_file_storage_mount_target.this.export_set_id
}

output "mount_address" {
  description = "Preferred NFS server address; FQDN when available, otherwise private IP."
  value       = local.mount_target_address
}

output "ip_address" {
  description = "Private IP address of the mount target."
  value       = oci_file_storage_mount_target.this.ip_address
}

output "logging" {
  description = "Logging resource details when mount target logging is enabled."
  value = var.enable_mount_target_logging ? {
    log_group_ocid     = oci_logging_log.mount_target[0].log_group_id
    log_ocid           = oci_logging_log.mount_target[0].id
    log_display_name   = oci_logging_log.mount_target[0].display_name
    is_enabled         = oci_logging_log.mount_target[0].is_enabled
    retention_duration = oci_logging_log.mount_target[0].retention_duration
  } : null
}

output "mount_target_summary" {
  description = "Compact Resource Manager summary for downstream FSS workflows."
  value = {
    mount_target_ocid   = oci_file_storage_mount_target.this.id
    export_set_ocid     = oci_file_storage_mount_target.this.export_set_id
    mount_address       = local.mount_target_address
    ip_address          = oci_file_storage_mount_target.this.ip_address
    availability_domain = oci_file_storage_mount_target.this.availability_domain
    subnet_ocid         = oci_file_storage_mount_target.this.subnet_id
    logging_enabled     = var.enable_mount_target_logging
  }
}
