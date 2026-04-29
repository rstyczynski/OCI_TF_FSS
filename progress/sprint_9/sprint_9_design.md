# Sprint 9 - Design

Status: Accepted

Mode: YOLO

## PBI-013. Pack sprint 5 terraform stack and lower level modules into v1 module

Status: Accepted

### Requirement

Provide stable v1 module paths that package the proven Sprint 5 behavior and supporting lower-level modules. Operators should be able to consume the v1 stack without referencing sprint-numbered module names.

### Module Set

```text
terraform/modules/fss_v1_filesystem/
terraform/modules/fss_v1_mount_target/
terraform/modules/fss_v1_export/
terraform/modules/fss_v1_stack/
```

### Compatibility Baseline

The v1 stack keeps the Sprint 5 interface:

- shared `compartment_ocid`, `availability_domain`, `subnet_ocid`, and `kms_key_id`
- `default_source_cidr`
- `filesystems` map keyed by stable operator names
- one filesystem, mount target, and export per map entry
- the same composite and atomic outputs proven by Sprint 5 tests

### Implementation Decision

YOLO decision: package v1 as copied modules rather than thin wrappers. This avoids making the stable v1 product depend internally on sprint-numbered module paths while preserving behavior. Future changes can evolve v1 directly or introduce v2.

Risk: copied modules can drift from sprint modules. Mitigation: v1 is intentionally a release baseline, not a moving alias.

## PBI-014. Prepare comprehensive user documentation for v1 modules

Status: Accepted

### Requirement

Each v1 module must include practical README documentation covering:

- purpose
- required inputs
- optional inputs
- outputs
- examples
- notes for operators

The stack README must include a copy/paste root module example and teardown instructions.

## Test Specification

### Integration Tests

#### IT-1: v1 stack validates and applies

- Generate Terraform root under `progress/sprint_9/generated_tf/it1_v1_stack_apply/`.
- Apply `fss_v1_stack` with two filesystem entries.
- Assert all per-entry outputs contain `alpha` and `beta`.
- Assert default source CIDR inheritance works.
- Save plan, apply logs, outputs, and destroy logs for review.

#### IT-2: v1 documented example validates

- Generate Terraform root under `progress/sprint_9/generated_tf/it2_documented_example_validate/`.
- Use the same shape as the README example with placeholder OCIDs.
- Run `terraform init` and `terraform validate`.

### Regression

None. Sprint 9 creates new v1 module paths and does not mutate existing sprint module paths.
