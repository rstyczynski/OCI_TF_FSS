output "filesystem_ocid" {
  description = "OCID of the created filesystem."
  value       = module.fss_stack.filesystem_ocid
}

output "export_ocids" {
  description = "Export OCIDs keyed by export slot."
  value       = module.fss_stack.export_ocids
}

output "export_paths" {
  description = "Export paths keyed by export slot."
  value       = module.fss_stack.export_paths
}

output "filesystem_display_name" {
  description = "Display name used for the created filesystem."
  value       = module.fss_stack.filesystem_display_name
}

output "mount_target_ocid" {
  description = "Selected mount target OCID."
  value       = local.selected_mount_target.id
}

output "export_set_ocid" {
  description = "Export set OCID resolved from the selected mount target."
  value       = local.selected_mount_target.export_set_id
}

output "nfs_mount_sources" {
  description = "Ready-to-use NFS mount sources keyed by export slot."
  value = {
    for key, path in module.fss_stack.export_paths :
    key => "${local.mount_address}:${path}"
  }
}

output "filesystem_export_summary" {
  description = "Compact Resource Manager summary for the created filesystem and exports."
  value = {
    filesystem_ocid   = module.fss_stack.filesystem_ocid
    display_name      = module.fss_stack.filesystem_display_name
    mount_target_ocid = local.selected_mount_target.id
    export_set_ocid   = local.selected_mount_target.export_set_id
    mount_address     = local.mount_address
    nfs_mount_sources = {
      for key, path in module.fss_stack.export_paths :
      key => "${local.mount_address}:${path}"
    }
  }
}
