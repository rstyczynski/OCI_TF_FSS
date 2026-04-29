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

Sprint 15 implements `PBI-026. Add advanced multi-topology Resource Manager package`.

The current Sprint 13 Resource Manager package supports a friendly single-topology form for one mount target, one filesystem, and one export. PBI-026 asks for a more advanced package set that avoids raw `mount_targets` and `filesystems` map editing while supporting multi-topology workflows through focused Resource Manager stacks.

The target baseline is the current `terraform/modules/fss_stack_sprint12/` product and its lower-level modules under `terraform/modules/fss_stack_sprint12/modules/`.

## Existing Constraints

- Resource Manager schema dynamic dropdown support is limited to documented supported resource types.
- Oracle documents `oci:mount:target:id` with required `compartmentId` and `availabilityDomain` dependencies.
- I do not see a documented Resource Manager schema type for File Storage filesystem OCID selection. The design therefore treats filesystem selection as a managed-mode risk and proposes a safe fallback.
