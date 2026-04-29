terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
}

module "stack" {
  source              = "../../../../terraform/modules/fss_v1_stack"
  compartment_ocid    = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = "ocid1.subnet.oc1.eu-zurich-1.aaaaaaaaidkhv3o7xq3igisuy3v2t3z4eccnftkrzsomm5kvhs2u2dhggp2q"
  kms_key_id          = "ocid1.key.oc1.eu-zurich-1.fju67xzlaachm.ab5heljrnxhi352pdvg3crh3izc6ymgliboz6td6xuf5s3eea2vzd2djqysq"
  default_source_cidr = "10.0.0.0/24"

  mount_targets = {
    mt_primary = {
      display_name = "fss-v1-mt-primary"
      logging = {
        enabled            = true
        log_group_name     = "fss-v1-primary-logs"
        log_display_name   = "fss-v1-primary-nfs"
        retention_duration = 30
        freeform_tags = {
          release = "v1"
          entry   = "mt_primary"
        }
      }
    }
    mt_secondary = {
      display_name = "fss-v1-mt-secondary"
    }
  }

  filesystems = {
    fs_data = {
      display_name = "fss-v1-data"
      freeform_tags = {
        release = "v1"
        entry   = "fs_data"
      }
      exports = {
        to_primary = {
          mount_target_key = "mt_primary"
          path             = "/v1-data-primary"
          identity_squash  = "NONE"
        }
        to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/v1-data-secondary"
        }
      }
    }
    fs_backup = {
      display_name = "fss-v1-backup"
      freeform_tags = {
        release = "v1"
        entry   = "fs_backup"
      }
      exports = {
        to_primary = {
          mount_target_key = "mt_primary"
          path             = "/v1-backup"
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

output "mount_target_log_group_ocids" {
  value = module.stack.mount_target_log_group_ocids
}
