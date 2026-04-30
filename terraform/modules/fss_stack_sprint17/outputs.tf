output "mount_targets" {
  description = "Complete mount target outputs keyed by input map key. Entries with external_ocid are referenced and not created."
  value = {
    for key, mt in local.resolved_mount_targets : key => {
      ocid            = mt.ocid
      display_name    = mt.display_name
      export_set_ocid = mt.export_set_ocid
      private_ip_ids  = mt.private_ip_ids
      ip_address      = mt.ip_address
      fqdn            = mt.fqdn
      mount_address   = mt.mount_address

      availability_domain = mt.availability_domain
      subnet_ocid         = mt.subnet_ocid
      compartment_ocid    = var.compartment_ocid
      external_ocid       = mt.external_ocid

      # Without try, any mount target with logging disabled would break terraform output / plan evaluation.
      logging = try({
        log_group_ocid     = oci_logging_log.mount_target[key].log_group_id
        log_ocid           = oci_logging_log.mount_target[key].id
        log_display_name   = oci_logging_log.mount_target[key].display_name
        service            = oci_logging_log.mount_target[key].configuration[0].source[0].service
        resource           = oci_logging_log.mount_target[key].configuration[0].source[0].resource
        category           = oci_logging_log.mount_target[key].configuration[0].source[0].category
        is_enabled         = oci_logging_log.mount_target[key].is_enabled
        retention_duration = oci_logging_log.mount_target[key].retention_duration
      }, null)

      availability_domain_source = var.availability_domain != null ? "explicit" : local.default_subnet_availability_domain != null ? "subnet" : "random"
    }
  }
}

output "mount_target_ocids" {
  description = "Mount target OCIDs keyed by input map key."
  value       = { for key, mt in local.resolved_mount_targets : key => mt.ocid }
}

output "mount_target_ip_addresses" {
  description = "Primary private IP addresses for mount targets keyed by input map key."
  value       = { for key, mt in local.resolved_mount_targets : key => mt.ip_address }
}

output "mount_target_mount_addresses" {
  description = "Preferred NFS server addresses keyed by input map key; FQDN when available, otherwise private IP address."
  value       = { for key, mt in local.resolved_mount_targets : key => mt.mount_address }
}

output "mount_target_log_group_ocids" {
  description = "Log group OCIDs keyed by mount target input key for targets with logging enabled."
  value       = { for key, log in oci_logging_log.mount_target : key => log.log_group_id }
}

output "mount_target_log_ocids" {
  description = "Log OCIDs keyed by mount target input key for targets with logging enabled."
  value       = { for key, log in oci_logging_log.mount_target : key => log.id }
}

output "filesystems" {
  description = "Complete filesystem outputs keyed by input map key, with nested export summaries."
  value = {
    for fs_key, fs in module.filesystem : fs_key => {
      filesystem_ocid         = fs.filesystem_ocid
      filesystem_display_name = fs.filesystem_display_name
      kms_key_id              = fs.kms_key_id == "" ? null : fs.kms_key_id
      kms_key_mode            = local.kms_key_mode
      compartment_ocid        = var.compartment_ocid
      availability_domain     = local.default_effective_availability_domain
      exports = {
        for composite_key, pair in local.exports_flat :
        pair.export_key => {
          export_ocid      = module.export[composite_key].export_ocid
          path             = module.export[composite_key].export_path
          mount_target_key = pair.export.mount_target_key
          source_cidr      = local.effective_sources[composite_key]
          identity_squash  = module.export[composite_key].identity_squash
          nfs_mount_source = format(
            "%s:%s",
            local.resolved_mount_targets[pair.export.mount_target_key].mount_address,
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
      local.resolved_mount_targets[pair.export.mount_target_key].mount_address,
      module.export[composite_key].export_path
    )
  }
}

output "effective_availability_domain" {
  description = "Default Availability Domain selected for filesystems and for mount targets that do not set mount_targets[*].availability_domain."
  value       = local.default_effective_availability_domain
}

output "availability_domain_source" {
  description = "How the default effective Availability Domain was selected: explicit, subnet, or random."
  value       = var.availability_domain != null ? "explicit" : local.default_subnet_availability_domain != null ? "subnet" : "random"
}

output "effective_kms_key_id" {
  description = "KMS key OCID supplied to filesystems; null means OCI-managed encryption."
  value       = var.kms_key_id
}

output "kms_key_mode" {
  description = "CUSTOMER_MANAGED when kms_key_id is supplied, otherwise ORACLE_MANAGED."
  value       = local.kms_key_mode
}

output "default_source_cidr" {
  description = "Default CIDR used by exports that omit source."
  value       = var.default_source_cidr
}

