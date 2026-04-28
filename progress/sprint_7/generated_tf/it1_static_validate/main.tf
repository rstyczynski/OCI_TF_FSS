terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "stack" {
  source              = "../../../../terraform/modules/fss_sprint7_stack"
  compartment_ocid    = "ocid1.compartment.oc1..example"
  availability_domain = "example:AD-1"
  subnet_ocid         = "ocid1.subnet.oc1..example"
  kms_key_id          = "ocid1.key.oc1..example"
  default_source_cidr = "10.0.0.0/24"

  mount_targets = {
    mt_primary = {
      display_name = "fss-sprint7-mt-primary"
    }
    mt_secondary = {
      display_name = "fss-sprint7-mt-secondary"
    }
  }

  filesystems = {
    fs_alpha = {
      display_name = "fss-sprint7-alpha"
      exports = {
        export_to_primary = {
          mount_target_key = "mt_primary"
          path             = "/sprint7-alpha-primary"
        }
        export_to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/sprint7-alpha-secondary"
          identity_squash  = "NONE"
        }
      }
    }
    fs_beta = {
      display_name = "fss-sprint7-beta"
      exports = {
        export_to_primary = {
          mount_target_key = "mt_primary"
          path             = "/sprint7-beta-primary"
          identity_squash  = "NONE"
        }
        export_to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/sprint7-beta-secondary"
          identity_squash  = "ROOT"
        }
      }
    }
  }
}
