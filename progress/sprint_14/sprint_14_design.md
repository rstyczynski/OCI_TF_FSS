# Sprint 14 - Design

Status: Accepted

Mode: YOLO

## PBI-027. Add legacy PV report to FSS stack variables converter

Status: Accepted

### Requirement

Create a conversion tool that reads legacy Kubernetes/NFS PV report files and emits `.auto.tfvars` compatible with `terraform/modules/fss_stack_sprint12/`.

### Input Contract

The converter supports reports shaped like:

- one or more node tables with `NAME STATUS ROLES AGE VERSION ZONE`
- zero or more `##########` separators
- one or more PV blocks containing:
  - `PV Name: <name>`
  - `path: <legacy export path>`
  - `server: <legacy NFS server>`
  - `storageclass: <storage class>`

### Output Contract

The converter emits HCL variables:

- `mount_targets`: one entry per distinct legacy `server`
- `filesystems`: one entry per PV
- each filesystem has one nested `exports.primary`
- each export uses the legacy `path` as the FSS export path
- tags preserve legacy PV name, server, storageclass, and path

Generated map keys are deterministic and Terraform-safe.

### Testing Strategy

#### Recommended Sprint Parameters

- Test: unit, integration
- Regression: none

#### Unit Test Targets

| Component | Functions to Test | Key Inputs & Edge Cases | Isolation |
|---|---|---|---|
| `tools/convert_pv_report_to_fss_tfvars.py` | parse report and render HCL | all templates, malformed blocks, key sanitization | local files only |

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|---|---|---|---|
| Apply generated variables | Sprint 1 foundation compartment/subnet, OCI Terraform provider | Generated tfvars apply with Sprint 12 stack, outputs match PV/export counts, destroy succeeds | 3-8 min |

## Test Specification

Sprint Test Configuration:

- Test: unit, integration
- Mode: YOLO

### Unit Tests

#### UT-1: Template conversion

- Input: `etc/pv-template1-details`, `etc/pv-template2-details`, `etc/pv-template3-details`
- Expected output: valid HCL with deterministic `mount_targets` and `filesystems` maps.
- Target file: `tests/unit/test_pv_report_converter.sh`

#### UT-2: Malformed report handling

- Input: incomplete PV block.
- Expected output: converter exits non-zero and reports missing fields.
- Target file: `tests/unit/test_pv_report_converter.sh`

### Integration Tests

#### IT-1: Generated variables apply with Sprint 12 stack

- Preconditions: Sprint 1 foundation state exists.
- Steps: convert `etc/pv-template2-details`, generate Terraform root under `progress/sprint_14/generated_tf/it1_apply_template2`, apply `terraform/modules/fss_stack_sprint12`, verify outputs, destroy.
- Expected outcome: one mount target, one filesystem, one export, one NFS mount source.
- Target file: `tests/integration/test_pv_report_converter.sh`

### Traceability

| Backlog Item | Unit Tests | Integration Tests |
|---|---|---|
| PBI-027 | UT-1, UT-2 | IT-1 |
