# Sprint 13 - Setup

Status: Complete

## Contract

- Rules source: `RUPStrikesBack/rules/generic/` plus `RUP_patch.md`.
- Mode: managed.
- Test: integration.
- Regression: none.
- Generated Terraform review roots stay under `progress/sprint_13/generated_tf/`.

## Analysis

- PBI-023 packages the current FSS stack for OCI Resource Manager.
- Baseline implementation is `terraform/modules/fss_stack_sprint12/`, which already contains the current stack root, lower-level package-local modules, and executable examples.
- OCI Resource Manager schema documents must be YAML, must live at the Terraform configuration root, and variable types must match the associated Terraform configuration.
- The stack module exposes nested map/object variables that are strong Terraform interfaces but poor direct console inputs.

## Managed Decisions Required

- Use a simplified Resource Manager root that maps console-friendly scalar inputs into the stack module's `mount_targets` and `filesystems` maps.
- Keep the full map-based stack module unchanged.
- Validate the schema package with Resource Manager, not only local Terraform validation.
