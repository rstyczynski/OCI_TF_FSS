terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

variable "compartment_ocid" {}
variable "subnet_ocid" {}
variable "subnet_cidr" {}
variable "kms_key_id" {}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

module "stack" {
  source              = "../../../terraform/modules/fss_sprint5_stack"
  compartment_ocid    = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = var.subnet_ocid
  kms_key_id          = var.kms_key_id
  default_source_cidr = var.subnet_cidr

  filesystems = {
    myfs = {
      filesystem_display_name = "my-fss-filesystem"
      export_path             = "/mydata"
      identity_squash         = "NONE"
      freeform_tags = {
        environment = "dev"
      }
    }
  }
}

output "mount_target_mount_addresses" {
  value = module.stack.mount_target_mount_addresses
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}
