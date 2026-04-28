terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fs" {
  source              = "../../../../terraform/modules/fss_sprint5_filesystem"
  compartment_ocid    = "ocid1.compartment.oc1..example"
  availability_domain = "example:AD-1"
  display_name        = "fss-sprint5-missing-kms"
}
