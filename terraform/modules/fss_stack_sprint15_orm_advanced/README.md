# FSS Advanced Resource Manager Package

This package contains focused OCI Resource Manager roots for operators who want console-driven FSS workflows without editing Terraform maps.

## Stacks

### `mount_target/`

Creates one FSS mount target.

Primary outputs:

- `mount_target_ocid`
- `export_set_ocid`
- `mount_address`
- `ip_address`
- `logging`
- `mount_target_summary`

### `filesystem_export/`

Creates one FSS filesystem and one to six exports against an existing mount target.

The first export is always enabled and requires an explicit export path. Exports 2-6 are controlled by chained `Add another export` checkboxes in the Resource Manager UI. When an optional export is enabled, its path must be provided explicitly.

Primary outputs:

- `filesystem_ocid`
- `export_ocids`
- `export_paths`
- `nfs_mount_sources`
- `filesystem_export_summary`

## Operator Flow

1. Upload and apply `mount_target/`.
2. Copy the mount target OCID or select the created mount target in the `filesystem_export/` stack.
3. Upload and apply `filesystem_export/`.
4. Read `nfs_mount_sources` from the Resource Manager job outputs.
5. Destroy `filesystem_export/` first, then `mount_target/`.

## Notes

- `filesystem_export/` uses Resource Manager's `oci:mount:target:id` selector for mount target selection.
- Resource Manager does not provide true dynamic pages, so optional exports use a bounded chained-checkbox pattern.
- The export-only day-2 workflow is tracked separately as `PBI-029`.
