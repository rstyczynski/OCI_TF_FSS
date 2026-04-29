terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fss" {
  source           = "../../../../terraform/modules/fss_v2_stack"
  compartment_ocid = "ocid1.compartment.oc1..example"
  subnet_ocid      = "ocid1.subnet.oc1..example"

  mount_targets = {
    primary = {}
  }

  filesystems = {
    data = {
      display_name = "fss-v2-data"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/data"
        }
      }
    }
  }
}

output "availability_domain_source" {
  value = module.fss.availability_domain_source
}

output "kms_key_mode" {
  value = module.fss.kms_key_mode
}

output "default_source_cidr" {
  value = module.fss.default_source_cidr
}
