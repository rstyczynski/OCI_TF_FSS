terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "stack" {
  source           = "../../../../terraform/modules/fss_v2_stack"
  compartment_ocid = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
  subnet_ocid      = "ocid1.subnet.oc1.eu-zurich-1.aaaaaaaaidkhv3o7xq3igisuy3v2t3z4eccnftkrzsomm5kvhs2u2dhggp2q"

  mount_targets = {
    mt_primary = {
      display_name = "fss-v2-mt-primary"
      logging = {
        enabled            = true
        log_group_name     = "fss-v2-primary-logs"
        log_display_name   = "fss-v2-primary-nfs"
        retention_duration = 30
        freeform_tags = {
          release = "v2"
          entry   = "mt_primary"
        }
      }
    }
    mt_secondary = {
      display_name = "fss-v2-mt-secondary"
    }
  }

  filesystems = {
    fs_data = {
      display_name = "fss-v2-data"
      freeform_tags = {
        release = "v2"
        entry   = "fs_data"
      }
      exports = {
        to_primary = {
          mount_target_key = "mt_primary"
          path             = "/v2-data-primary"
          identity_squash  = "NONE"
        }
        to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/v2-data-secondary"
        }
      }
    }
    fs_backup = {
      display_name = "fss-v2-backup"
      freeform_tags = {
        release = "v2"
        entry   = "fs_backup"
      }
      exports = {
        to_primary = {
          mount_target_key = "mt_primary"
          path             = "/v2-backup"
        }
      }
    }
  }
}

output "filesystems" {
  value = module.stack.filesystems
}

output "filesystem_ocids" {
  value = module.stack.filesystem_ocids
}

output "mount_targets" {
  value = module.stack.mount_targets
}

output "mount_target_ocids" {
  value = module.stack.mount_target_ocids
}

output "export_paths" {
  value = module.stack.export_paths
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}

output "mount_target_log_ocids" {
  value = module.stack.mount_target_log_ocids
}

output "effective_availability_domain" {
  value = module.stack.effective_availability_domain
}

output "availability_domain_source" {
  value = module.stack.availability_domain_source
}

output "effective_kms_key_id" {
  value = module.stack.effective_kms_key_id
}

output "kms_key_mode" {
  value = module.stack.kms_key_mode
}

output "default_source_cidr" {
  value = module.stack.default_source_cidr
}
