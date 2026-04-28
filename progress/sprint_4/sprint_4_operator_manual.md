# Sprint 4 - Operator Manual

## Purpose

Sprint 4 provides the lower-level Terraform modules needed to expose an OCI File Storage Service filesystem through NFS:

- `terraform/modules/fss_sprint4_mount_target`
- `terraform/modules/fss_sprint4_export`

Use the mount target module to create the NFS server endpoint in a subnet. Use the export module to attach a filesystem to the mount target export set at an NFS export path.

## Mount Target Module

Module path:

```hcl
module "mount_target" {
  source = "../../terraform/modules/fss_sprint4_mount_target"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid
  display_name        = "example-fss-mt"

  hostname_label = "example-fss"
  nsg_ids        = var.nsg_ids
}
```

Required inputs:

- `compartment_ocid`
- `availability_domain`
- `subnet_ocid`
- `display_name`

Optional inputs:

- `hostname_label`
- `nsg_ids`
- `freeform_tags`
- `defined_tags`

Important outputs:

- `mount_target_ocid`: OCI mount target OCID.
- `mount_target_export_set_ocid`: export set OCID to pass into the export module.
- `mount_target_private_ip_ids`: OCI private IP OCIDs for network diagnostics.
- `mount_target_ip_address`: primary private IP address assigned to the mount target.
- `mount_target_fqdn`: DNS name when `hostname_label` is set and the subnet has DNS enabled.
- `mount_target_mount_address`: preferred NFS server address; FQDN when available, otherwise private IP address.

## Export Module

Module path:

```hcl
module "export" {
  source = "../../terraform/modules/fss_sprint4_export"

  export_set_ocid  = module.mount_target.mount_target_export_set_ocid
  file_system_ocid = module.filesystem.filesystem_ocid
  path             = "/example"
  source_cidr      = var.client_source_cidr
}
```

Required inputs:

- `export_set_ocid`
- `file_system_ocid`
- `path`
- `source_cidr`

Common optional inputs:

- `access`
- `allowed_auth`
- `identity_squash`
- `anonymous_uid`
- `anonymous_gid`
- `is_anonymous_access_allowed`
- `require_privileged_source_port`

Important outputs:

- `export_ocid`
- `export_path`
- `export_set_ocid`
- `file_system_ocid`

## Mount Source

The value operators need for a Linux NFS mount is:

```text
<mount_target_mount_address>:<export_path>
```

Example:

```bash
sudo mount -t nfs -o vers=3,nolock <mount_target_mount_address>:<export_path> /mnt/fss
```

If DNS is configured for the subnet and `hostname_label` is set, `mount_target_mount_address` uses the FQDN. Otherwise it uses the mount target private IP address.

## Network Validation

Sprint 4 validates network reachability with OCI Network Path Analyzer from the Sprint 1 foundation compute VNIC to the mount target VNIC on TCP/2049. The NPA report is recorded in:

```text
progress/sprint_4/sprint_4_npa_report.md
```

This proves network reachability to the FSS mount target. It does not perform an operating-system NFS mount; later sprint work covers actual client mounting.

## Generated Terraform

Sprint 4 integration test roots are kept for review under:

```text
progress/sprint_4/generated_tf/
```

These files show the exact Terraform roots used by the sprint tests. Runtime Terraform byproducts are ignored, but the generated `main.tf` files remain available for operator review.
