output "filesystem_ocids" {
  description = "Filesystem OCIDs keyed by input map key."
  value       = { for key, filesystem in module.filesystem : key => filesystem.filesystem_ocid }
}

output "mount_target_ocids" {
  description = "Mount target OCIDs keyed by input map key."
  value       = { for key, mount_target in module.mount_target : key => mount_target.mount_target_ocid }
}

output "mount_target_export_set_ocids" {
  description = "Mount target export set OCIDs keyed by input map key."
  value       = { for key, mount_target in module.mount_target : key => mount_target.mount_target_export_set_ocid }
}

output "export_ocids" {
  description = "Export OCIDs keyed by input map key."
  value       = { for key, export in module.export : key => export.export_ocid }
}

output "export_paths" {
  description = "Export paths keyed by input map key."
  value       = { for key, export in module.export : key => export.export_path }
}

output "effective_source_cidrs" {
  description = "Effective source CIDRs keyed by input map key."
  value       = local.effective_source_cidrs
}
