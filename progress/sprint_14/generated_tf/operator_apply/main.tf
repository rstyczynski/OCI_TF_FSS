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
  type        = string
  description = "Target OCI compartment OCID."
}

variable "subnet_ocid" {
  type        = string
  description = "Subnet OCID where generated mount targets will be created."
}

variable "mount_targets" {
  type        = any
  description = "Generated mount target map from the legacy PV report converter."
}

variable "filesystems" {
  type        = any
  description = "Generated filesystem/export map from the legacy PV report converter."
}

module "fss" {
  source = "../../../../terraform/modules/fss_stack_sprint12"

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid
  mount_targets    = var.mount_targets
  filesystems      = var.filesystems
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
