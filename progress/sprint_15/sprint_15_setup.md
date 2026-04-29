# Sprint 15 - Setup

Status: Complete

## Contract

- Rules source: `RUPStrikesBack/rules/generic/` plus `RUP_patch.md`.
- Mode: managed.
- Test: smoke, integration.
- Regression: none.
- Managed checkpoint: stop for Product Owner design approval before construction.
- Generated Terraform and Resource Manager review roots stay under `progress/sprint_15/generated_tf/`.

## Analysis

Sprint 15 implements:

- `PBI-026. Add Resource Manager mount target stack`
- `PBI-028. Add Resource Manager filesystem stack with chained exports`

The current Sprint 13 Resource Manager package supports a friendly single-topology form for one mount target, one filesystem, and one export. Sprint 15 starts the advanced package set with focused Resource Manager stacks for mount target creation and filesystem creation with chained optional exports.

The target baseline is the current `terraform/modules/fss_stack_sprint12/` product and its lower-level modules under `terraform/modules/fss_stack_sprint12/modules/`.

## Existing Constraints

- Resource Manager schema dynamic dropdown support is limited to documented supported resource types.
- Oracle documents `oci:mount:target:id` with required `compartmentId` and `availabilityDomain` dependencies.
- Export-only Resource Manager workflow is split into future `PBI-029`; Sprint 15 does not need existing filesystem selection.
