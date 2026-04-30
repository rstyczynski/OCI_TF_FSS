module "filesystem" {
  source = "./modules/fss_filesystem"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = var.filesystem_display_name
  kms_key_id          = var.kms_key_id
  freeform_tags       = var.freeform_tags
  defined_tags        = var.defined_tags
}

module "export" {
  for_each = var.enabled_exports

  source = "./modules/fss_export"

  export_set_ocid  = var.export_set_ocid
  file_system_ocid = module.filesystem.filesystem_ocid
  path             = each.value.path
  source_cidr      = each.value.source_cidr

  access                         = each.value.access
  allowed_auth                   = ["SYS"]
  identity_squash                = each.value.identity_squash
  anonymous_uid                  = var.anonymous_uid
  anonymous_gid                  = var.anonymous_gid
  is_anonymous_access_allowed    = false
  require_privileged_source_port = var.require_privileged_source_port
}
