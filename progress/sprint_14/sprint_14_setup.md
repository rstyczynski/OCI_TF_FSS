# Sprint 14 - Setup

Status: Complete

## Contract

- Rules source: `RUPStrikesBack/rules/generic/` plus `RUP_patch.md`.
- Mode: YOLO.
- Test: unit, integration.
- Regression: none.
- Generated Terraform review roots stay under `progress/sprint_14/generated_tf/`.

## Analysis

- PBI-027 converts legacy Kubernetes/NFS PV report files into Terraform variable files.
- Source templates are `etc/pv-template1-details`, `etc/pv-template2-details`, and `etc/pv-template3-details`.
- Product target is the current `terraform/modules/fss_stack_sprint12/` input shape.
- Integration must apply the generated variables with the Sprint 12 stack, not only run `terraform validate`.

## YOLO Decisions

- Implement the converter as a Python script under `tools/` because the source is an unstructured report, while Terraform should consume structured generated HCL.
- Use one mount target per distinct legacy `server` value.
- Use one filesystem per PV and one `primary` export per filesystem.
- Preserve original PV name, server, storageclass, and path in freeform tags.
