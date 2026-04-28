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

module "fs" {
  source              = "../../../../terraform/modules/fss_sprint3"
  compartment_ocid    = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "fss-sprint4-it1-mount-target"
}

module "mt" {
  source              = "../../../../terraform/modules/fss_sprint4_mount_target"
  compartment_ocid    = "ocid1.compartment.oc1..aaaaaaaarg3czmfmagxnchqiaz7cptm4ngxyrlzevngts7lbpyu2pijogx2q"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = "ocid1.subnet.oc1.eu-zurich-1.aaaaaaaaidkhv3o7xq3igisuy3v2t3z4eccnftkrzsomm5kvhs2u2dhggp2q"
  display_name        = "fss-sprint4-mt-it1-mount-target"
}

data "oci_core_private_ip" "mount_target" {
  private_ip_id = module.mt.mount_target_private_ip_ids[0]
}

module "export" {
  source           = "../../../../terraform/modules/fss_sprint4_export"
  export_set_ocid  = module.mt.mount_target_export_set_ocid
  file_system_ocid = module.fs.filesystem_ocid
  path             = "/sprint4-it1-mount-target"
  source_cidr      = "10.0.0.0/24"
}

output "filesystem_ocid" {
  value = module.fs.filesystem_ocid
}

output "mount_target_ocid" {
  value = module.mt.mount_target_ocid
}

output "mount_target_export_set_ocid" {
  value = module.mt.mount_target_export_set_ocid
}

output "mount_target_private_ip_ids" {
  value = module.mt.mount_target_private_ip_ids
}

output "mount_target_private_ip" {
  value = data.oci_core_private_ip.mount_target.ip_address
}

output "mount_target_ip_address" {
  value = module.mt.mount_target_ip_address
}

output "mount_target_fqdn" {
  value = module.mt.mount_target_fqdn
}

output "mount_target_mount_address" {
  value = module.mt.mount_target_mount_address
}

output "mount_target_vnic_id" {
  value = data.oci_core_private_ip.mount_target.vnic_id
}

output "export_ocid" {
  value = module.export.export_ocid
}

output "export_path" {
  value = module.export.export_path
}

output "nfs_mount_source" {
  value = "${module.mt.mount_target_mount_address}:${module.export.export_path}"
}

output "source_cidr" {
  value = "10.0.0.0/24"
}
