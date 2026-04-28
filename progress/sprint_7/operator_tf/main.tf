terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

variable "compartment_ocid"    {}
variable "subnet_ocid"         {}
variable "default_source_cidr" {}
variable "kms_key_id"          {}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

module "fss" {
  source              = "../../../terraform/modules/fss_sprint7_stack"
  compartment_ocid    = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = var.subnet_ocid
  kms_key_id          = var.kms_key_id
  default_source_cidr = var.default_source_cidr

  mount_targets = {
    primary = {
      display_name = "fss-mt-primary"
    }
    secondary = {
      display_name = "fss-mt-secondary"
    }
  }

  filesystems = {
    fs_data = {
      display_name = "fss-data"
      exports = {
        to_primary = {
          mount_target_key = "primary"
          path             = "/data"
          identity_squash  = "NONE"
        }
        to_secondary = {
          mount_target_key = "secondary"
          path             = "/data"
        }
      }
    }
    fs_backup = {
      display_name = "fss-backup"
      exports = {
        to_primary = {
          mount_target_key = "primary"
          path             = "/backup"
        }
      }
    }
  }
}

output "mount_targets"      { value = module.fss.mount_targets }
output "filesystems"        { value = module.fss.filesystems }
output "nfs_mount_sources"  { value = module.fss.nfs_mount_sources }
