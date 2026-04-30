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
    primary = {
      display_name = "fss-primary"
    }
  }
}

output "mount_targets" {
  value = module.fss.mount_targets
}

output "mount_target_ocids" {
  value = module.fss.mount_target_ocids
}