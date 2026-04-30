# Sprint 17 - Implementation Notes

## PBI-031 / PBI-032. Externally managed mount targets + per-mount-target placement overrides

Status: Pending

Implemented `terraform/modules/fss_stack_sprint17` as a Sprint 12–compatible stack module with the following extensions:

- `mount_targets[*].external_ocid`: when set, the stack does not create a mount target; it resolves mount target details via data sources and uses the resolved `export_set_id` for exports.
- `mount_targets[*].subnet_ocid` and `mount_targets[*].availability_domain`: optional per-mount-target placement overrides (defaulting to stack-level values when omitted).

Added validation-only example at `terraform/modules/fss_stack_sprint17/examples/external_mount_target_validate_only`.

Packaging: `terraform/modules/fss_stack_sprint17` is self-sufficient and embeds its Terraform sub-modules under `terraform/modules/fss_stack_sprint17/modules/` (no dependency on sibling module directories).

