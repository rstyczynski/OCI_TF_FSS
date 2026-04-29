output "nfs_mount_sources" {
  description = "Ready-to-use NFS mount sources in <mount-address>:<export-path> form."
  value       = module.fss.nfs_mount_sources
}

output "mount_targets" {
  description = "Mount target details, including mount address and logging details when enabled."
  value       = module.fss.mount_targets
}

output "filesystems" {
  description = "Filesystem details, including nested export summaries."
  value       = module.fss.filesystems
}

output "exports" {
  description = "Export paths keyed by composite filesystem__export key."
  value       = module.fss.export_paths
}

output "resource_manager_summary" {
  description = "Compact summary intended for the OCI Resource Manager job page."
  value = {
    nfs_mount_source           = module.fss.nfs_mount_sources["data__primary"]
    mount_target_mount_address = module.fss.mount_targets["primary"].mount_address
    filesystem_ocid            = module.fss.filesystems["data"].filesystem_ocid
    export_path                = module.fss.filesystems["data"].exports["primary"].path
    availability_domain        = module.fss.effective_availability_domain
    availability_domain_source = module.fss.availability_domain_source
    kms_key_mode               = module.fss.kms_key_mode
    logging                    = module.fss.mount_targets["primary"].logging
  }
}
