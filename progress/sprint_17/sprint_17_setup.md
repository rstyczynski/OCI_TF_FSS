# Sprint 17 - Setup

## Contract Review

Status: Proposed

Sprint 17 implements PBI-031 and PBI-032.

Goal: extend `terraform/modules/fss_stack_sprint12` so mount targets can be either stack-managed or externally managed, and so each mount target entry can override placement (subnet/availability domain) when needed. `filesystems[*].exports[*].mount_target_key` continues to reference a mount target by key as before, but the mount target entry may be external.

New input attribute:

- `mount_targets[*].external_ocid` (optional): when set, the stack must not create a mount target for that key and must instead use the existing mount target identified by this OCID.
 - `mount_targets[*].subnet_ocid` (optional): per-mount-target override of `var.subnet_ocid`.
 - `mount_targets[*].availability_domain` (optional): per-mount-target override of the stack effective availability domain.

Constraints:

- Sprint is `Mode: managed`.
- Keep sprint product in `terraform/modules/fss_stack_sprint17/`.
- Preserve backwards compatibility: existing Sprint 12 examples must validate unchanged.

## Analysis

Current `fss_stack_sprint12` export wiring assumes:

- every `mount_target_key` is a key in `var.mount_targets`
- exports obtain `export_set_ocid` via `module.mount_target[mount_target_key].mount_target_export_set_ocid`

To support external mount targets, the stack must resolve `export_set_id` (and for outputs also mount address) from the external mount target OCID without relying on stack-created mount target module outputs.

