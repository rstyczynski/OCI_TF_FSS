output "filesystem_ocid" {
  description = "OCID of the created filesystem."
  value       = oci_file_storage_file_system.this.id
}

output "export_ocids" {
  description = "Export OCIDs keyed by export slot."
  value       = { for key, export in oci_file_storage_export.this : key => export.id }
}

output "export_paths" {
  description = "Export paths keyed by export slot."
  value       = { for key, export in oci_file_storage_export.this : key => export.path }
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
    for key, export in oci_file_storage_export.this :
    key => "${local.mount_address}:${export.path}"
  }
}

output "filesystem_export_summary" {
  description = "Compact Resource Manager summary for the created filesystem and exports."
  value = {
    filesystem_ocid   = oci_file_storage_file_system.this.id
    display_name      = oci_file_storage_file_system.this.display_name
    mount_target_ocid = local.selected_mount_target.id
    export_set_ocid   = local.selected_mount_target.export_set_id
    mount_address     = local.mount_address
    nfs_mount_sources = {
      for key, export in oci_file_storage_export.this :
      key => "${local.mount_address}:${export.path}"
    }
  }
}
