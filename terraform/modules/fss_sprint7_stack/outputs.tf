output "mount_targets" {
  description = "Complete mount target outputs keyed by input map key."
  value = {
    for key, mt in module.mount_target : key => {
      mount_target_ocid            = mt.mount_target_ocid
      mount_target_display_name    = mt.mount_target_display_name
      mount_target_export_set_ocid = mt.mount_target_export_set_ocid
      mount_target_private_ip_ids  = mt.mount_target_private_ip_ids
      mount_target_ip_address      = mt.mount_target_ip_address
      mount_target_fqdn            = mt.mount_target_fqdn
      mount_target_mount_address   = mt.mount_target_mount_address
      availability_domain          = var.availability_domain
      subnet_ocid                  = var.subnet_ocid
      compartment_ocid             = var.compartment_ocid
    }
  }
}

output "mount_target_ocids" {
  description = "Mount target OCIDs keyed by input map key."
  value       = { for key, mt in module.mount_target : key => mt.mount_target_ocid }
}

output "mount_target_ip_addresses" {
  description = "Primary private IP addresses for mount targets keyed by input map key."
  value       = { for key, mt in module.mount_target : key => mt.mount_target_ip_address }
}

output "mount_target_mount_addresses" {
  description = "Preferred NFS server addresses keyed by input map key; FQDN when available, otherwise private IP address."
  value       = { for key, mt in module.mount_target : key => mt.mount_target_mount_address }
}

output "filesystems" {
  description = "Complete filesystem outputs keyed by input map key, with nested export summaries."
  value = {
    for fs_key, fs in module.filesystem : fs_key => {
      filesystem_ocid         = fs.filesystem_ocid
      filesystem_display_name = fs.filesystem_display_name
      kms_key_id              = var.kms_key_id
      compartment_ocid        = var.compartment_ocid
      availability_domain     = var.availability_domain
      exports = {
        for composite_key, pair in local.exports_flat :
        pair.export_key => {
          export_ocid      = module.export[composite_key].export_ocid
          path             = module.export[composite_key].export_path
          mount_target_key = pair.export.mount_target_key
          identity_squash  = module.export[composite_key].identity_squash
          nfs_mount_source = format(
            "%s:%s",
            module.mount_target[pair.export.mount_target_key].mount_target_mount_address,
            module.export[composite_key].export_path
          )
        }
        if pair.fs_key == fs_key
      }
    }
  }
}

output "filesystem_ocids" {
  description = "Filesystem OCIDs keyed by input map key."
  value       = { for key, fs in module.filesystem : key => fs.filesystem_ocid }
}

output "export_paths" {
  description = "Export paths keyed by composite key fs__export."
  value       = { for key, exp in module.export : key => exp.export_path }
}

output "nfs_mount_sources" {
  description = "NFS mount sources in <mount-address>:<export-path> form, keyed by composite key fs__export."
  value = {
    for composite_key, pair in local.exports_flat :
    composite_key => format(
      "%s:%s",
      module.mount_target[pair.export.mount_target_key].mount_target_mount_address,
      module.export[composite_key].export_path
    )
  }
}
