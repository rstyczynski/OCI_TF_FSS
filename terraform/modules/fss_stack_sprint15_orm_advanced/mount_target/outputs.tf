output "mount_target_ocid" {
  description = "OCID of the created mount target."
  value       = module.fss_stack.mount_target_ocid
}

output "export_set_ocid" {
  description = "Export set OCID associated with the created mount target."
  value       = module.fss_stack.export_set_ocid
}

output "mount_address" {
  description = "Preferred NFS server address; FQDN when available, otherwise private IP."
  value       = module.fss_stack.mount_target_mount_address
}

output "ip_address" {
  description = "Private IP address of the mount target."
  value       = module.fss_stack.mount_target_ip_address
}

output "logging" {
  description = "Logging resource details when mount target logging is enabled."
  value       = module.fss_stack.logging
}

output "availability_domain" {
  description = "Availability Domain used for the mount target."
  value       = module.fss_stack.availability_domain
}

output "subnet_ocid" {
  description = "Subnet OCID used for the mount target."
  value       = module.fss_stack.subnet_ocid
}

output "mount_target_summary" {
  description = "Compact Resource Manager summary for downstream FSS workflows."
  value = {
    mount_target_ocid   = module.fss_stack.mount_target_ocid
    export_set_ocid     = module.fss_stack.export_set_ocid
    mount_address       = module.fss_stack.mount_target_mount_address
    ip_address          = module.fss_stack.mount_target_ip_address
    availability_domain = module.fss_stack.availability_domain
    subnet_ocid         = module.fss_stack.subnet_ocid
    logging_enabled     = var.enable_mount_target_logging
  }
}
