# Sprint 11 - Design

Status: Accepted

Mode: YOLO

## PBI-021. Create v2 stack with optimized mandatory parameters

Status: Accepted

### Requirement

Create `terraform/modules/fss_v2_stack` from the current v1 stack behavior and reduce mandatory operator input.

### Interface

Mandatory:

- `compartment_ocid`
- `subnet_ocid`

Optional:

- `availability_domain`, default `null`
- `kms_key_id`, default `null`
- `default_source_cidr`, default `0.0.0.0/0`
- `mount_targets`, default `{}`
- `filesystems`, default `{}`

### Availability Domain Selection

- Read the subnet with `data.oci_core_subnet`.
- If `availability_domain` is explicitly provided, use it.
- Else if the subnet has an AD value, use the subnet AD.
- Else use Sprint 2 randomization: sorted AD list plus `random_shuffle`.

### Encryption

- Pass `kms_key_id = null` to the filesystem module when omitted.
- OCI File Storage then uses Oracle-managed encryption.
- Expose effective KMS mode in composite outputs.

### Export Source

- Default source CIDR is `0.0.0.0/0`.
- Per-export `source` still overrides the module default.

## PBI-022. Complete v2 stack package and README

Status: Accepted

### Requirement

Document v2 as the operator-facing successor to v1 and keep executable Terraform examples visible under the sprint home directory.

### Documentation

`terraform/modules/fss_v2_stack/README.md` must include:

- purpose
- mandatory inputs
- optional inputs
- mount target and filesystem entry shapes
- outputs
- minimal example
- full example with logging
- v1 to v2 migration notes

## Testing Strategy

### Recommended Sprint Parameters

- Test: integration
- Regression: none

### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|---|---|---|---|
| Minimal v2 validate | Terraform providers | Minimal example validates without AD, KMS, or default CIDR | < 2 min |
| Full v2 apply | OCI foundation subnet and compartment | Creates two mount targets, two filesystems, three exports, one log, proves outputs | 5-10 min |

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: YOLO

### Integration Tests

#### IT-1: Minimal v2 example validates

- What it verifies: v2 accepts no `availability_domain`, no `kms_key_id`, and no `default_source_cidr`.
- Target file: `tests/integration/test_fss_sprint11_v2.sh`
- Generated root: `progress/sprint_11/generated_tf/it1_minimal_validate/`

#### IT-2: Full v2 stack applies

- What it verifies: v2 creates the latest stack shape, uses default export CIDR, and exposes effective AD/KMS/logging outputs.
- Target file: `tests/integration/test_fss_sprint11_v2.sh`
- Generated root: `progress/sprint_11/generated_tf/it2_full_apply/`

### Traceability

| Backlog Item | Integration Tests |
|---|---|
| PBI-021 | IT-1, IT-2 |
| PBI-022 | IT-1, IT-2 |
