# Sprint 3 - Design

## PBI-001. Terraform module for FSS filesystem

Status: Approved

### Requirement Summary

Create a simplified Terraform module for an OCI FSS filesystem at `terraform/modules/fss_sprint3`. The Sprint 3 module replaces Sprint 2 add-on behavior with explicit Terraform inputs and a smaller interface.

### Feasibility Analysis

**API Availability:**

- OCI Terraform provider supports `oci_file_storage_file_system` with `availability_domain`, `compartment_id`, and `display_name`.
- Terraform supports resource `lifecycle` blocks for ignoring provider-populated attributes such as Oracle-managed `defined_tags`.

**Technical Constraints:**

- Product path must be `terraform/modules/fss_sprint3`.
- Remove AD randomization: caller must provide `availability_domain`.
- Remove `name_prefix`: caller must provide `display_name`.
- Remove dynamic tag recognition/merge logic: do not read existing FSS resources for tag preservation.
- Use lifecycle ignore handling for Oracle-managed tags instead of dynamic recognition.

**Risk Assessment:**

- Lifecycle ignore must target only the Oracle-managed defined tag keys, so user-managed defined tags are not broadly masked.
- Integration tests require OCI credentials and permissions for `/oci_tf_fss`.

### Design Overview

**Architecture:**

- Add a new module directory `terraform/modules/fss_sprint3/`.
- The module creates exactly one OCI FSS filesystem.
- Required inputs are explicit and minimal: `compartment_ocid`, `availability_domain`, and `display_name`.
- Optional inputs: `freeform_tags` and `defined_tags`, both default `{}`.
- No random provider, no AD data source, no file-system lookup data source, no `name_prefix`.

**Key Components:**

1. `terraform/modules/fss_sprint3/versions.tf` - Terraform/provider constraints.
2. `terraform/modules/fss_sprint3/variables.tf` - explicit required inputs, freeform tags, and defined tags.
3. `terraform/modules/fss_sprint3/main.tf` - one `oci_file_storage_file_system` resource with lifecycle ignore for Oracle-managed `defined_tags` keys.
4. `terraform/modules/fss_sprint3/outputs.tf` - stable outputs.

### Technical Specification

**Resources:**

- `oci_file_storage_file_system.this`

**Inputs:**

- `compartment_ocid` (required)
- `availability_domain` (required)
- `display_name` (required)
- `freeform_tags` (optional, default `{}`)
- `defined_tags` (optional, default `{}`)

**Outputs:**

- `filesystem_ocid`
- `filesystem_display_name`
- `availability_domain`

**Lifecycle handling:**

Use:

```hcl
lifecycle {
  ignore_changes = [
    defined_tags["Oracle-Tags.CreatedBy"],
    defined_tags["Oracle-Tags.CreatedOn"]
  ]
}
```

The module will not use dynamic tag recognition in Sprint 3. This keeps Oracle-managed defined tags out of Terraform drift without masking all `defined_tags` changes.

### Implementation Approach

1. Create `terraform/modules/fss_sprint3/` with the simplified module.
2. Update Sprint 3 integration tests by filling the Phase 2 skeletons.
3. Create `progress/sprint_3/sprint_3_tf_rules.md` with Sprint 3 rule changes and an `Experimental patterns` section.
4. Update documentation/operator manual after quality gates.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration - module must apply in OCI and verify outputs.
- **Regression:** integration - existing Terraform filesystem regression must still pass.
- **Regression scope:** omit; run full integration regression per `PLAN.md`.

#### Unit Test Targets

None. This repo currently tests Terraform modules through integration scripts.

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|----------|-----------------------------|------------------|--------------|
| Missing required inputs fail | Terraform only | `terraform validate` fails when required inputs are omitted | < 1 min |
| Happy path apply | OCI credentials, Terraform, `/oci_tf_fss` permissions | Filesystem is created and outputs are present | 1-5 min |
| Tag lifecycle idempotency | OCI credentials, Terraform, `/oci_tf_fss` permissions | Updating a harmless mutable field after Oracle-managed tag propagation succeeds with `defined_tags = {}` and no defined-tag conflict | 1-5 min |

#### Smoke Test Candidates

None. Sprint `Test:` is integration only.

**Success Criteria:**

- New-code integration gate passes for Sprint 3 tests.
- Regression integration gate passes.
- Sprint 3 Terraform rules document moves Sprint 2 add-on techniques into an experimental section.

### Integration Notes

**Dependencies:**

- Sprint 1 foundation state can resolve `/oci_tf_fss` compartment.
- Sprint 2 test helpers can be reused conceptually, but Sprint 3 tests should target `fss_sprint3`.

**Compatibility:**

- Sprint 2 module remains available as `terraform/modules/fss_sprint2`.
- Sprint 3 module is intentionally a new product path, not an in-place edit of Sprint 2.

### Documentation Requirements

- Update README recent updates for Sprint 3 after gates.
- Add `progress/sprint_3/sprint_3_operator_manual.md`.
- Add `progress/sprint_3/sprint_3_tf_rules.md`.

### Open Design Questions

- None.

## PBI-006. Terraform architecture rules for agentic development

Status: Proposed

### Requirement Summary

Revise the Sprint 2 Terraform rules so AD randomization, dynamic tag recognition, and name-prefix derived naming are not default agentic patterns. Keep them documented only under `Experimental patterns` for use on explicit request.

### Feasibility Analysis

**API Availability:**

- N/A. This is a documentation/process artifact.

**Technical Constraints:**

- Rules must be clear enough to guide Sprint 4 and later Terraform module work.
- Existing Sprint 2 rules remain historical; Sprint 3 creates a new rules artifact.

### Design Overview

- Create `progress/sprint_3/sprint_3_tf_rules.md`.
- Promote explicit required inputs for module values that affect resource identity or replacement.
- Move AD randomization, dynamic tag recognition/merge, and name-prefix derived display names into `Experimental patterns`.

### Testing Strategy

Covered by Sprint 3 integration traceability and document review.

### Open Design Questions

- None.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Error path - missing required inputs fail

- **Preconditions:** Terraform installed.
- **Steps:** run `terraform validate` with the module called without `compartment_ocid`, `availability_domain`, and `display_name`.
- **Expected Outcome:** validation fails.
- **Verification:** validate returns non-zero.
- **Target file:** `tests/integration/test_fss_sprint3_tf.sh`

#### IT-2: Happy path - apply creates filesystem with explicit inputs

- **Preconditions:** Terraform installed; OCI creds configured; permissions for `/oci_tf_fss`.
- **Steps:** resolve compartment and AD, apply module with explicit `display_name`.
- **Expected Outcome:** apply succeeds and output `filesystem_ocid` is non-empty.
- **Verification:** parse Terraform outputs.
- **Target file:** `tests/integration/test_fss_sprint3_tf.sh`

#### IT-3: Tag lifecycle idempotency

- **Preconditions:** Terraform installed; OCI creds configured; permissions for `/oci_tf_fss`.
- **Steps:**
  1. Apply module with explicit inputs and `defined_tags = {}`.
  2. Wait 10 seconds for Oracle-managed tags to appear.
  3. Update a harmless mutable field (`display_name`; OCI FSS has no Terraform `description` argument) while keeping `defined_tags = {}`.
- **Expected Outcome:** update plan/apply succeeds and does not try to remove `Oracle-Tags.CreatedBy` or `Oracle-Tags.CreatedOn`.
- **Verification:** update apply exits 0; post-update plan exits 0.
- **Target file:** `tests/integration/test_fss_sprint3_tf.sh`

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
|--------------|-------|------------|-------------------|
| PBI-001 | - | - | IT-1, IT-2, IT-3 |
| PBI-006 | - | - | IT-3 plus document review |
