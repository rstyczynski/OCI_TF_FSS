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
  description = "Default subnet OCID used by the stack."
  type        = string
}

variable "external_mount_target_ocid" {
  description = "Existing mount target OCID to reference (ocid1.mounttarget...)."
  type        = string
}

variable "mount_target_subnet_ocid" {
  description = "Optional override subnet OCID for the referenced mount target entry. Defaults to subnet_ocid."
  type        = string
  default     = null
}

variable "mount_target_availability_domain" {
  description = "Optional AD override for the referenced mount target entry. Set this when the mount target subnet is AD-specific."
  type        = string
  default     = null
}

module "fss" {
  source = "../.."

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid

  mount_targets = {
    existing_mt = {
      external_ocid = var.external_mount_target_ocid
      subnet_ocid   = coalesce(var.mount_target_subnet_ocid, var.subnet_ocid)

      # availability_domain can be set when the subnet is AD-specific.
      availability_domain = var.mount_target_availability_domain
    }
  }

  filesystems = {
    data = {
      display_name = "data"
      exports = {
        primary = {
          mount_target_key = "existing_mt"
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

