# Sprint 13 - Design

Status: Accepted

Mode: managed

## PBI-023. Package current FSS stack package for OCI Resource Manager

Status: Accepted

### Requirement

Package the current FSS stack package, `terraform/modules/fss_stack_sprint12/`, so operators can deploy it from OCI Resource Manager without writing Terraform. The Resource Manager packaging must include `schema.yaml`, present mandatory and optional inputs clearly in the OCI Console, create a deployable stack, and expose mount information in Resource Manager outputs.

### Source Constraints

- OCI Resource Manager schema documents are YAML files located at the Terraform configuration root.
- Schema variable types must match the associated Terraform variable declarations.
- Resource Manager supports schema variables, variable groups, outputs, and output groups for console presentation.
- Dynamic controls exist for OCI compartment, subnet, KMS key, and related OCID selectors.

### Design

Create Resource Manager packaging for the current package without changing the existing `fss_stack_sprint12` stack interface. The Resource Manager-specific Terraform root is:

- `terraform/modules/fss_stack_sprint13_orm/`
- `terraform/modules/fss_stack_sprint13_orm/main.tf`
- `terraform/modules/fss_stack_sprint13_orm/variables.tf`
- `terraform/modules/fss_stack_sprint13_orm/outputs.tf`
- `terraform/modules/fss_stack_sprint13_orm/versions.tf`
- `terraform/modules/fss_stack_sprint13_orm/schema.yaml`
- `terraform/modules/fss_stack_sprint13_orm/README.md`

The ORM package is a thin Terraform root around `../fss_stack_sprint12`:

- It exposes console-friendly variables for the common topology: one mount target, one filesystem, one export.
- It maps those variables into the stack module's `mount_targets` and `filesystems` maps internally.
- It configures the OCI provider with an explicit `region` variable because Resource Manager runs the provider with Instance Principal authentication and requires a region.
- It keeps optional inputs for display names, export path, source CIDR, hostname label, NSGs, optional KMS key, optional mount target logging, tags, and NFS export behavior.
- It does not replace the full map-based stack. Operators who need multiple mount targets or multiple exports continue to use `terraform/modules/fss_stack_sprint12/` directly.

### Schema Approach

Use a simplified fixed-topology schema instead of freeform JSON strings for `mount_targets` and `filesystems`.

Reasoning:

- The Terraform stack's nested map type is correct for code users but awkward for Resource Manager Console users.
- JSON string inputs would move validation from Terraform types into ad hoc decoding and would be harder for operators to fill correctly.
- A single-mount/single-filesystem package is enough for the Resource Manager console path and still exercises the same underlying stack implementation.

### Output Contract

The ORM package exposes at least:

- `nfs_mount_sources`
- `mount_targets`
- `filesystems`
- `exports`
- `resource_manager_summary`

`schema.yaml` declares key outputs so mount addresses and export paths are visible from the Resource Manager job page.

### Testing Strategy

#### Recommended Sprint Parameters

- Test: integration
- Regression: none

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|---|---|---|---|
| Static package validation | Terraform and YAML parser | ORM package validates locally; `schema.yaml` parses and declares required sections | < 1 min |
| Resource Manager stack package upload | OCI Resource Manager CLI | `oci resource-manager stack create` accepts the generated zip without schema validation errors | 1-2 min |
| Resource Manager apply/destroy | OCI Resource Manager CLI, Sprint 1 foundation subnet and compartment | Apply job completes, outputs include `nfs_mount_sources`, destroy job completes | 5-10 min |

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: ORM package validates locally

- What it verifies: Terraform root validates, `schema.yaml` parses, mandatory variables are exposed, and outputs are declared.
- Target file: `tests/integration/test_fss_sprint13_orm.sh`

#### IT-2: ORM stack upload succeeds

- What it verifies: a zip of `terraform/modules/fss_stack_sprint13_orm/` can be accepted by OCI Resource Manager as a stack.
- Target file: `tests/integration/test_fss_sprint13_orm.sh`

#### IT-3: ORM apply and destroy jobs succeed

- What it verifies: Resource Manager apply creates the FSS stack, `nfs_mount_sources` is visible in job outputs, and destroy cleans up.
- Target file: `tests/integration/test_fss_sprint13_orm.sh`

### Traceability

| Backlog Item | Integration Tests |
|---|---|
| PBI-023 | IT-1, IT-2, IT-3 |

## Approval Gate

Approved by operator before construction.
