terraform {
  required_providers { oci = { source = "oracle/oci" } }
}

module "stack" {
  source = "/Users/rstyczynski/projects/OCI_TF_FSS/terraform/packages/fss_stack"

  compartment_ocid    = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
  subnet_ocid         = "ocid1.subnet.oc1.eu-zurich-1.aaaaaaaaidkhv3o7xq3igisuy3v2t3z4eccnftkrzsomm5kvhs2u2dhggp2q"
  availability_domain = "jJRq:EU-ZURICH-1-AD-1"

  mount_targets = {
    primary = { display_name = "fss-exp-mt-20260504142912" }
  }

  filesystems = {
    shared = {
      display_name = "fss-exp-fs-20260504142912"
      exports = {
        vol1 = { mount_target_key = "primary", path = "/vol1", identity_squash = "NONE" }
        vol2 = { mount_target_key = "primary", path = "/vol2", identity_squash = "NONE" }
      }
    }
  }
}

output "nfs_mount_sources" { value = module.stack.nfs_mount_sources }
