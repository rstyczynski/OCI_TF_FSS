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
  source              = "../../../../terraform/modules/fss_sprint7_stack"
  compartment_ocid    = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = "ocid1.subnet.oc1.eu-zurich-1.aaaaaaaaidkhv3o7xq3igisuy3v2t3z4eccnftkrzsomm5kvhs2u2dhggp2q"
  kms_key_id          = "ocid1.key.oc1.eu-zurich-1.fju67xzlaachm.ab5heljrnxhi352pdvg3crh3izc6ymgliboz6td6xuf5s3eea2vzd2djqysq"
  default_source_cidr = "10.0.0.0/24"

  mount_targets = {
    mt_primary = {
      display_name = "fss-sprint7-mt-primary"
    }
    mt_secondary = {
      display_name = "fss-sprint7-mt-secondary"
    }
  }

  filesystems = {
    fs_alpha = {
      display_name = "fss-sprint7-alpha"
      freeform_tags = {
        sprint = "7"
        test   = "it2"
      }
      exports = {
        export_to_primary = {
          mount_target_key = "mt_primary"
          path             = "/sprint7-alpha-primary"
        }
        export_to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/sprint7-alpha-secondary"
          identity_squash  = "NONE"
        }
      }
    }
    fs_beta = {
      display_name = "fss-sprint7-beta"
      freeform_tags = {
        sprint = "7"
        test   = "it2"
      }
      exports = {
        export_to_primary = {
          mount_target_key = "mt_primary"
          path             = "/sprint7-beta-primary"
          identity_squash  = "NONE"
        }
        export_to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/sprint7-beta-secondary"
          identity_squash  = "ROOT"
        }
      }
    }
  }
}

output "mount_targets" {
  value = module.stack.mount_targets
}

output "filesystems" {
  value = module.stack.filesystems
}

output "mount_target_ocids" {
  value = module.stack.mount_target_ocids
}

output "filesystem_ocids" {
  value = module.stack.filesystem_ocids
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}

output "export_paths" {
  value = module.stack.export_paths
}
