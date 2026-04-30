output "filesystem_ocid" {
  description = "OCID of the created filesystem."
  value       = module.filesystem.filesystem_ocid
}

output "filesystem_display_name" {
  description = "Display name used for the filesystem."
  value       = module.filesystem.filesystem_display_name
}

output "export_ocids" {
  description = "Export OCIDs keyed by export slot."
  value       = { for key, exp in module.export : key => exp.export_ocid }
}

output "export_paths" {
  description = "Export paths keyed by export slot."
  value       = { for key, exp in module.export : key => exp.export_path }
}
