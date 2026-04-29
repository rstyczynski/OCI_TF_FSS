terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
}

variable "subnet_ocid" {
  description = "Subnet OCID where the FSS mount target will be created."
  type        = string
}

module "fss" {
  source = "../.."

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid

  mount_targets = {
    primary = {}
  }

  filesystems = {
    data = {
      display_name = "fss-data"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/data"
        }
      }
    }
  }
}

output "filesystems" {
  value = module.fss.filesystems
}

output "mount_targets" {
  value = module.fss.mount_targets
}

output "nfs_mount_sources" {
  value = module.fss.nfs_mount_sources
}

output "kms_key_mode" {
  value = module.fss.kms_key_mode
}

output "availability_domain_source" {
  value = module.fss.availability_domain_source
}
