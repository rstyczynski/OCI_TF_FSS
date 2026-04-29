terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fss" {
  source              = "../../../../terraform/modules/fss_v1_stack"
  compartment_ocid    = "ocid1.compartment.oc1..example"
  availability_domain = "example:AD-1"
  subnet_ocid         = "ocid1.subnet.oc1..example"
  kms_key_id          = "ocid1.key.oc1..example"
  default_source_cidr = "10.0.0.0/24"

  filesystems = {
    alpha = {
      filesystem_display_name = "fss-alpha"
      export_path             = "/alpha"
      identity_squash         = "NONE"
      freeform_tags = {
        environment = "dev"
      }
    }
    beta = {
      filesystem_display_name   = "fss-beta"
      mount_target_display_name = "fss-beta-mt"
      export_path               = "/beta"
      source_cidr               = "10.0.0.0/24"
    }
  }
}

output "filesystems" {
  value = module.fss.filesystems
}

output "nfs_mount_sources" {
  value = module.fss.nfs_mount_sources
}
