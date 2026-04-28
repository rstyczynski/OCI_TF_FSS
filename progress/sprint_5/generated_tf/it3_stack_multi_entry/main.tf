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
    alpha = {
      filesystem_display_name = "fss-sprint5-alpha"
      export_path             = "/sprint5-alpha"
      freeform_tags = {
        stack = "alpha"
      }
    }
    beta = {
      filesystem_display_name   = "fss-sprint5-beta"
      mount_target_display_name = "fss-sprint5-mt-beta"
      export_path               = "/sprint5-beta"
      source_cidr               = "10.0.0.0/24"
      freeform_tags = {
        stack = "beta"
      }
    }
  }
}

output "filesystem_ocids" {
  value = module.stack.filesystem_ocids
}

output "mount_target_ocids" {
  value = module.stack.mount_target_ocids
}

output "export_ocids" {
  value = module.stack.export_ocids
}

output "export_paths" {
  value = module.stack.export_paths
}

output "effective_source_cidrs" {
  value = module.stack.effective_source_cidrs
}
