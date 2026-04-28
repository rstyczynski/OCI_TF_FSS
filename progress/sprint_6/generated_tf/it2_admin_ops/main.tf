terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
}

module "stack" {
  source              = "../../../../terraform/modules/fss_sprint5_stack"
  compartment_ocid    = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = "ocid1.subnet.oc1.eu-zurich-1.aaaaaaaavsji5425xckgkwuxlzsxat3jdxx6bbrhprwi3dsgf6gr5f2aaudq"
  kms_key_id          = "ocid1.key.oc1.eu-zurich-1.fju67xzlaachm.ab5heljrnxhi352pdvg3crh3izc6ymgliboz6td6xuf5s3eea2vzd2djqysq"
  default_source_cidr = "10.0.0.0/24"

  filesystems = {
    sprint6test = {
      filesystem_display_name = "fss-sprint6-test"
      export_path             = "/sprint6-test"
      identity_squash         = "NONE"
      freeform_tags = {
        sprint = "6"
        test   = "mount"
      }
    }
  }
}

output "filesystems" {
  value = module.stack.filesystems
}

output "mount_target_mount_addresses" {
  value = module.stack.mount_target_mount_addresses
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}
