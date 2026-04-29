# Sprint 13 - Implementation

Status: Complete

## PBI-023. Package current FSS stack package for OCI Resource Manager

Implemented Resource Manager packaging at:

- `terraform/modules/fss_stack_sprint13_orm/`

The package contains:

- `main.tf` - wraps `../fss_stack_sprint12` and maps scalar Resource Manager inputs into the current stack's `mount_targets` and `filesystems` maps.
- `variables.tf` - console-friendly inputs for the common one mount target, one filesystem, one export topology.
- `outputs.tf` - Resource Manager-visible mount, filesystem, export, and summary outputs.
- `versions.tf` - Terraform and provider requirements.
- `schema.yaml` - OCI Resource Manager Console variable groups, variable metadata, and output groups.
- `README.md` - packaging and CLI execution notes.

## Implementation Notes

- The current product package remains `terraform/modules/fss_stack_sprint12/`.
- The Resource Manager package is a separate Terraform root because `schema.yaml` must live at the Terraform configuration root.
- The package zip must include both `terraform/modules/fss_stack_sprint13_orm/` and `terraform/modules/fss_stack_sprint12/`; Resource Manager is invoked with working directory `terraform/modules/fss_stack_sprint13_orm`.
- The OCI provider is configured with `region = var.region`. This is required by the Resource Manager runner using Instance Principal authentication.

## Generated Review Artifacts

- `progress/sprint_13/generated_tf/orm_package_static/`
- `progress/sprint_13/generated_tf/orm_package_upload/`
- `progress/sprint_13/generated_tf/orm_package_apply/`

Binary zip files are generated under the same directories for execution but ignored by git.
