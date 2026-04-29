output "filesystems" {
  description = "Complete FSS stack outputs keyed by input map key."
  value = {
    for key in keys(var.filesystems) : key => {
      availability_domain     = var.availability_domain
      compartment_ocid        = var.compartment_ocid
      filesystem_ocid         = module.filesystem[key].filesystem_ocid
      filesystem_display_name = module.filesystem[key].filesystem_display_name
      kms_key_id              = var.kms_key_id
      subnet_ocid             = var.subnet_ocid
      source_cidr             = local.effective_source_cidrs[key]

      mount_target_ocid            = module.mount_target[key].mount_target_ocid
      mount_target_display_name    = module.mount_target[key].mount_target_display_name
      mount_target_export_set_ocid = module.mount_target[key].mount_target_export_set_ocid
      mount_target_private_ip_ids  = module.mount_target[key].mount_target_private_ip_ids
      mount_target_ip_address      = module.mount_target[key].mount_target_ip_address
      mount_target_fqdn            = module.mount_target[key].mount_target_fqdn
      mount_target_mount_address   = module.mount_target[key].mount_target_mount_address

      export_ocid     = module.export[key].export_ocid
      export_set_ocid = module.export[key].export_set_ocid
      export_path     = module.export[key].export_path
      nfs_mount_source = format(
        "%s:%s",
        module.mount_target[key].mount_target_mount_address,
        module.export[key].export_path
      )
    }
  }
}

output "filesystem_ocids" {
  description = "Filesystem OCIDs keyed by input map key."
  value       = { for key, filesystem in module.filesystem : key => filesystem.filesystem_ocid }
}

output "filesystem_display_names" {
  description = "Filesystem display names keyed by input map key."
  value       = { for key, filesystem in module.filesystem : key => filesystem.filesystem_display_name }
}

output "kms_key_id" {
  description = "KMS master encryption key OCID used by all filesystems."
  value       = var.kms_key_id
}

output "mount_target_ocids" {
  description = "Mount target OCIDs keyed by input map key."
  value       = { for key, mount_target in module.mount_target : key => mount_target.mount_target_ocid }
}

output "mount_target_display_names" {
  description = "Mount target display names keyed by input map key."
  value       = { for key, mount_target in module.mount_target : key => mount_target.mount_target_display_name }
}

output "mount_target_export_set_ocids" {
  description = "Mount target export set OCIDs keyed by input map key."
  value       = { for key, mount_target in module.mount_target : key => mount_target.mount_target_export_set_ocid }
}

output "mount_target_private_ip_ids" {
  description = "Private IP OCIDs for mount targets keyed by input map key."
  value       = { for key, mount_target in module.mount_target : key => mount_target.mount_target_private_ip_ids }
}

output "mount_target_ip_addresses" {
  description = "Primary private IP addresses for mount targets keyed by input map key."
  value       = { for key, mount_target in module.mount_target : key => mount_target.mount_target_ip_address }
}

output "mount_target_fqdns" {
  description = "Mount target DNS names keyed by input map key when hostname labels and subnet DNS are available."
  value       = { for key, mount_target in module.mount_target : key => mount_target.mount_target_fqdn }
}

output "mount_target_mount_addresses" {
  description = "Preferred NFS server addresses keyed by input map key; FQDN when available, otherwise private IP address."
  value       = { for key, mount_target in module.mount_target : key => mount_target.mount_target_mount_address }
}

output "compartment_ocid" {
  description = "Compartment OCID used by all filesystems and mount targets."
  value       = var.compartment_ocid
}

output "availability_domain" {
  description = "Availability Domain used by all filesystems and mount targets."
  value       = var.availability_domain
}

output "subnet_ocid" {
  description = "Subnet OCID used by all mount targets."
  value       = var.subnet_ocid
}

output "export_ocids" {
  description = "Export OCIDs keyed by input map key."
  value       = { for key, export in module.export : key => export.export_ocid }
}

output "export_set_ocids" {
  description = "Export set OCIDs used by exports keyed by input map key."
  value       = { for key, export in module.export : key => export.export_set_ocid }
}

output "export_paths" {
  description = "Export paths keyed by input map key."
  value       = { for key, export in module.export : key => export.export_path }
}

output "nfs_mount_sources" {
  description = "Ready-to-use NFS mount sources keyed by input map key in the form <mount-address>:<export-path>."
  value = {
    for key, export in module.export :
    key => format("%s:%s", module.mount_target[key].mount_target_mount_address, export.export_path)
  }
}

output "effective_source_cidrs" {
  description = "Effective source CIDRs keyed by input map key."
  value       = local.effective_source_cidrs
}
