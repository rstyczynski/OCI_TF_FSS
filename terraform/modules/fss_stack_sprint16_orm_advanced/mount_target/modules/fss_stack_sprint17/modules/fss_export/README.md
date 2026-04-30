# FSS Export Module

## Purpose

Creates one OCI File Storage export that connects a filesystem to a mount target export set.

## Required Inputs

| Name | Description |
|---|---|
| `export_set_ocid` | Export set OCID from a mount target. |
| `file_system_ocid` | Filesystem OCID to export. |
| `path` | NFS export path. |
| `source_cidr` | Client IPv4 CIDR allowed by the export option. |

## Optional Inputs

| Name | Default |
|---|---:|
| `access` | `READ_WRITE` |
| `allowed_auth` | `["SYS"]` |
| `identity_squash` | `ROOT` |
| `anonymous_uid` | `65534` |
| `anonymous_gid` | `65534` |
| `is_anonymous_access_allowed` | `false` |
| `require_privileged_source_port` | `false` |

## Outputs

Key outputs include:

- `export_ocid`
- `export_set_ocid`
- `file_system_ocid`
- `export_path`
- export option values applied to the resource

## Example

```hcl
module "export" {
  source           = "../fss_export"
  export_set_ocid  = module.mt.mount_target_export_set_ocid
  file_system_ocid = module.fs.filesystem_ocid
  path             = "/data"
  source_cidr      = var.subnet_cidr
}
```

