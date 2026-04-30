output "mount_target_ocid" {
  description = "OCID of the created mount target."
  value       = module.mount_target.mount_target_ocid
}

output "export_set_ocid" {
  description = "Export set OCID associated with the created mount target."
  value       = module.mount_target.mount_target_export_set_ocid
}

output "mount_target_mount_address" {
  description = "Preferred NFS server address; FQDN when available, otherwise private IP."
  value       = module.mount_target.mount_target_mount_address
}

output "mount_target_ip_address" {
  description = "Private IP address of the mount target."
  value       = module.mount_target.mount_target_ip_address
}

output "availability_domain" {
  description = "Availability Domain used for the mount target."
  value       = module.mount_target.availability_domain
}

output "subnet_ocid" {
  description = "Subnet OCID used for the mount target."
  value       = module.mount_target.subnet_ocid
}

output "logging" {
  description = "Logging resource details when mount target logging is enabled."
  value = var.enable_logging ? {
    log_group_ocid     = oci_logging_log.mount_target[0].log_group_id
    log_ocid           = oci_logging_log.mount_target[0].id
    log_display_name   = oci_logging_log.mount_target[0].display_name
    is_enabled         = oci_logging_log.mount_target[0].is_enabled
    retention_duration = oci_logging_log.mount_target[0].retention_duration
  } : null
}
