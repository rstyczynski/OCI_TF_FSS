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
  source              = "../../../../terraform/modules/fss_sprint8_stack"
  compartment_ocid    = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = "ocid1.subnet.oc1.eu-zurich-1.aaaaaaaaidkhv3o7xq3igisuy3v2t3z4eccnftkrzsomm5kvhs2u2dhggp2q"
  kms_key_id          = "ocid1.key.oc1.eu-zurich-1.fju67xzlaachm.ab5heljrnxhi352pdvg3crh3izc6ymgliboz6td6xuf5s3eea2vzd2djqysq"
  default_source_cidr = "10.0.0.0/24"

  mount_targets = {
    mt_logged = {
      display_name = "fss-sprint8-mt-logged"
      logging = {
        enabled            = true
        log_group_name     = "fss-sprint8-mt-logs"
        log_display_name   = "fss-sprint8-mt-nfs"
        retention_duration = 30
        freeform_tags = {
          sprint = "8"
          test   = "logging"
        }
      }
    }
  }

  filesystems = {
    fs_logged = {
      display_name = "fss-sprint8-logged"
      freeform_tags = {
        sprint = "8"
        test   = "logging"
      }
      exports = {
        export_logged = {
          mount_target_key = "mt_logged"
          path             = "/sprint8-logging"
          identity_squash  = "NONE"
        }
      }
    }
  }
}

output "mount_targets" {
  value = module.stack.mount_targets
}

output "mount_target_ocids" {
  value = module.stack.mount_target_ocids
}

output "mount_target_log_group_ocids" {
  value = module.stack.mount_target_log_group_ocids
}

output "mount_target_log_ocids" {
  value = module.stack.mount_target_log_ocids
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}
