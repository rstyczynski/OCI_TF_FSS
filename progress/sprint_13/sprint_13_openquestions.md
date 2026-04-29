# Sprint 13 - Open Questions

Status: Closed

## OQ-1. Resource Manager topology scope

Recommended answer: implement a fixed-topology Resource Manager package for one mount target, one filesystem, and one export.

Reasoning: Resource Manager Console users get typed inputs and clear controls, while the full map-based `fss_stack_sprint12` module remains available for code users who need complex topologies.

Resolution: accepted and implemented in `terraform/modules/fss_stack_sprint13_orm/`.

## OQ-2. Resource Manager package path

Recommended answer: create `terraform/modules/fss_stack_sprint13_orm/`.

Reasoning: the schema must live at a Terraform root. Keeping a dedicated ORM root avoids weakening the main stack module interface for console-specific constraints.

Resolution: accepted and implemented.
