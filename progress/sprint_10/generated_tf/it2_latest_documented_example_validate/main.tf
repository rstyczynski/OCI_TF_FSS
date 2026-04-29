terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fss" {
  source              = "../../../../terraform/modules/fss_v1_stack"
  compartment_ocid    = "ocid1.compartment.oc1..example"
  availability_domain = "example:AD-1"
  subnet_ocid         = "ocid1.subnet.oc1..example"
  kms_key_id          = "ocid1.key.oc1..example"
  default_source_cidr = "10.0.0.0/24"

  mount_targets = {
    primary = {
      display_name = "fss-primary"
      logging = {
        enabled = true
      }
    }
    secondary = {
      display_name = "fss-secondary"
    }
  }

  filesystems = {
    data = {
      display_name = "fss-data"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/data"
          identity_squash  = "NONE"
        }
        secondary = {
          mount_target_key = "secondary"
          path             = "/data-secondary"
        }
      }
    }
    backup = {
      display_name = "fss-backup"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/backup"
        }
      }
    }
  }
}

output "mount_targets" {
  value = module.fss.mount_targets
}

output "filesystems" {
  value = module.fss.filesystems
}

output "nfs_mount_sources" {
  value = module.fss.nfs_mount_sources
}
