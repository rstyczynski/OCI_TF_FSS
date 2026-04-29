resource "oci_file_storage_export" "this" {
  export_set_id  = var.export_set_ocid
  file_system_id = var.file_system_ocid
  path           = var.path

  export_options {
    source                         = var.source_cidr
    access                         = var.access
    allowed_auth                   = var.allowed_auth
    identity_squash                = var.identity_squash
    anonymous_uid                  = var.anonymous_uid
    anonymous_gid                  = var.anonymous_gid
    is_anonymous_access_allowed    = var.is_anonymous_access_allowed
    require_privileged_source_port = var.require_privileged_source_port
  }
}
