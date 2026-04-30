# FSS Filesystem Module

## Purpose

Creates one OCI File Storage filesystem.

## Required Inputs

| Name | Description |
|---|---|
| `compartment_ocid` | Target OCI compartment OCID. |
| `availability_domain` | Availability Domain for the filesystem. |
| `display_name` | Filesystem display name. |
| `kms_key_id` | KMS key OCID used to encrypt the filesystem. |

## Optional Inputs

Optional inputs expose provider-supported filesystem settings while preserving default behavior when omitted:

- `are_quota_rules_enabled`
- `clone_attach_status`
- `detach_clone_trigger`
- `filesystem_snapshot_policy_id`
- `is_lock_override`
- `source_snapshot_id`
- `freeform_tags`
- `defined_tags`
- `locks`
- `timeouts`

## Outputs

Key outputs include:

- `filesystem_ocid`
- `filesystem_display_name`
- `kms_key_id`
- `freeform_tags`
- `defined_tags`

## Example

```hcl
module "fs" {
  source              = "../fss_filesystem"
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "fss-data"
  kms_key_id          = var.kms_key_id
}
```

