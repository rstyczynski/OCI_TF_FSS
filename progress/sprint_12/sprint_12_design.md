# Sprint 12 - Design

Status: Accepted

Mode: YOLO

## PBI-024. Repackage FSS stack with examples and modules layout

Status: Accepted

### Requirement

Repackage the current FSS stack baseline into an operator-oriented layout:

- `terraform/modules/fss_stack_sprint12/`
- `terraform/modules/fss_stack_sprint12/examples/basic_fss/`
- `terraform/modules/fss_stack_sprint12/examples/multi_fss_with_logging/`
- `terraform/modules/fss_stack_sprint12/modules/fss_filesystem/`
- `terraform/modules/fss_stack_sprint12/modules/fss_mount_target/`
- `terraform/modules/fss_stack_sprint12/modules/fss_export/`

### Design

- `terraform/modules/fss_stack_sprint12` is copied from the current stack baseline and rewired to package-local lower-level modules.
- `examples/basic_fss` is taken from the basic README example and requires only `compartment_ocid` and `subnet_ocid`.
- `examples/multi_fss_with_logging` is taken from the full README example.
- README documentation points to example roots as executable documentation.

### Testing Strategy

#### Recommended Sprint Parameters

- Test: integration
- Regression: none

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|---|---|---|---|
| Validate examples | Terraform providers | Every example under `examples/` validates | < 2 min |
| Apply basic example | OCI foundation subnet and compartment | Basic example provisions one mount target, one filesystem, one export, and expected outputs | 3-6 min |

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: YOLO

### Integration Tests

#### IT-1: Examples validate

- What it verifies: checked-in examples validate and use package root `terraform/modules/fss_stack_sprint12`.
- Target file: `tests/integration/test_fss_sprint12_examples.sh`

#### IT-2: Basic example applies

- What it verifies: `terraform/modules/fss_stack_sprint12/examples/basic_fss` provisions a usable FSS stack with minimal arguments.
- Target file: `tests/integration/test_fss_sprint12_examples.sh`

### Traceability

| Backlog Item | Integration Tests |
|---|---|
| PBI-024 | IT-1, IT-2 |
