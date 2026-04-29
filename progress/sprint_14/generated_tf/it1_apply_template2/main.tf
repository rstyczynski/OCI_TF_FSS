terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

variable "compartment_ocid" {
  type = string
}

variable "subnet_ocid" {
  type = string
}

module "fss" {
  source = "../../../../terraform/modules/fss_stack_sprint12"

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid
  mount_targets    = var.mount_targets
  filesystems      = var.filesystems
}

variable "mount_targets" {
  type = any
}

variable "filesystems" {
  type = any
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
