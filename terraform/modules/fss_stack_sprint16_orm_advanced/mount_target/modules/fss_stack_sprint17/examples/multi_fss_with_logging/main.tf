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
  description = "Subnet OCID where mount targets will be created."
  type        = string
}

variable "availability_domain" {
  description = "Optional explicit Availability Domain. Leave null to derive from subnet or use AD randomization."
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key OCID. Leave null to use Oracle-managed encryption."
  type        = string
  default     = null
}

variable "default_source_cidr" {
  description = "Default export source CIDR."
  type        = string
  default     = "0.0.0.0/0"
}

module "fss" {
  source = "../.."

  compartment_ocid    = var.compartment_ocid
  subnet_ocid         = var.subnet_ocid
  availability_domain = var.availability_domain
  kms_key_id          = var.kms_key_id
  default_source_cidr = var.default_source_cidr

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

output "filesystems" {
  value = module.fss.filesystems
}

output "mount_targets" {
  value = module.fss.mount_targets
}

output "nfs_mount_sources" {
  value = module.fss.nfs_mount_sources
}

