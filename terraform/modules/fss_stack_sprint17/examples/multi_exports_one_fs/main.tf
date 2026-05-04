# Example: one filesystem, multiple exports at different NFS paths.
#
# This example provisions one mount target and one filesystem with two exports:
#   /vol1 and /vol2
#
# OCI FSS behavior (verified by Sprint 19 integration experiment):
#   Both /vol1 and /vol2 expose the SAME filesystem root.
#   Writing a file via /vol1 makes it immediately visible via /vol2.
#   The export path is an NFS alias for the filesystem root — OCI FSS does
#   NOT scope each export to a distinct subtree.
#
# Use this topology when:
#   - You need the same data accessible at multiple NFS paths (e.g. for
#     different client mount conventions without data isolation).
#
# Do NOT use this topology when:
#   - Each path should hold independent data (use separate filesystems instead).

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
  required_version = ">= 1.5.0"
}

module "fss" {
  source = "../.."

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid

  mount_targets = {
    primary = {
      display_name = "fss-shared-mt"
    }
  }

  filesystems = {
    shared = {
      display_name = "fss-shared-fs"
      exports = {
        vol1 = {
          mount_target_key = "primary"
          path             = "/vol1"
          identity_squash  = "NONE"
        }
        vol2 = {
          mount_target_key = "primary"
          path             = "/vol2"
          identity_squash  = "NONE"
        }
      }
    }
  }
}

output "nfs_mount_sources" {
  description = "NFS mount strings for each export. Both expose the same filesystem root."
  value       = module.fss.nfs_mount_sources
}

output "mount_target_mount_address" {
  description = "NFS server address for the mount target."
  value       = module.fss.mount_target_mount_addresses
}
