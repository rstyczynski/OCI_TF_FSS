# Sprint 1 - Design

## PBI-005. Foundation infrastructure for system-level FSS tests

Status: Proposed

### Requirement Summary

Provide a reusable foundation environment for system-level testing of the FSS modules using `oci_scaffold`, so later sprints can validate end-to-end accessibility (not only Terraform plan/apply success).

### Feasibility Analysis

**API Availability:**

- `oci_scaffold` provides idempotent ensure/cycle scripts for network, compute, and path analyzer resources, driven via OCI CLI and a JSON state file.
- This backlog item is feasible using the `oci_scaffold` integration-test framework as the provisioning mechanism for test baseline resources.

**Technical Constraints:**

- All resources must be created under the compartment path specified in `PLAN.md`: `/oci_tf_fss`.
- `oci_scaffold` is shell/OCI-CLI based (not Terraform). The foundation will therefore be provisioned via `oci_scaffold` scripts, while later sprints deliver Terraform modules.
- Integration tests may be **NOT RUN** in environments without OCI credentials; per `RUP_patch.md`, any such claim must be explicitly recorded with evidence and reasons during Phase 4.

**Risk Assessment:**

- Credential / tenancy access gaps can block actual integration runs.
- Compartment path creation might require permissions; if missing, foundation provisioning cannot proceed.
- Creating compute instances may incur cost; teardown must be enforced or explicitly acknowledged.

### Design Overview

**Architecture:**

Use `oci_scaffold` as the authoritative provisioning mechanism for “test baseline” resources used by integration/system tests:

- Network baseline (VCN/subnet/route/security list) suitable for later mounting tests.
- Optional compute baseline (test client instance) for future mount validation.
- Path analyzer baseline to support network reachability checks (later sprint PBI-004).

**Key Components:**

1. `oci_scaffold/` submodule: provides `cycle-*` and `resource/ensure-*` scripts.
2. `tests/run.sh`: repository test runner used by quality gates.
3. `tests/integration/test_foundation.sh`: integration tests for foundation provisioning.

**Data Flow:**

`tests/run.sh --integration` → runs `tests/integration/test_foundation.sh:*` → calls into `oci_scaffold` scripts (in later implementation) → verifies expected baseline outputs (network OCIDs, compute identifiers).

### Technical Specification

**Provisioning contract (foundation outputs)**

The foundation must provide (at minimum):

- Network identifiers: subnet OCID (and VCN OCID if needed).
- Compute identifiers: instance OCID and IP (for later mount testing), if a test client is provisioned.
- Compartment: all resources in `/oci_tf_fss`.

**Planned `oci_scaffold` usage (design intent)**

- Prefer reusing existing `oci_scaffold` cycles where possible:
  - `cycle-subnet.sh` or `cycle-subnet-nat.sh` for network baseline
  - `cycle-compute.sh` for test client baseline
- Ensure the compartment path is set to `/oci_tf_fss` for all runs.

**Error Handling:**

- If the compartment path cannot be resolved/created, stop integration run and surface the OCI error.
- If provisioning partially succeeds, state file must reflect it; teardown must be possible (or explicitly deferred and recorded).

### Implementation Approach

1. Introduce integration test skeletons that define the expected foundation behavior (red-first).
2. Implement the skeletons by invoking `oci_scaffold` with a deterministic `NAME_PREFIX` and `COMPARTMENT_PATH=/oci_tf_fss`.
3. Record provisioning outputs for reuse in later sprints’ integration tests.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — this sprint defines system-level foundation behavior; unit tests are not meaningful.
- **Regression:** integration — until unit tests exist, the integration suite is the primary safety net.

#### Unit Test Targets

None.

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|----------|----------------------------|------------------|--------------|
| Provision foundation baseline | OCI CLI auth, permissions for `/oci_tf_fss`, quota | Network and (optionally) compute baseline created; identifiers available | 2-10 min |

#### Smoke Test Candidates

None.

**Success Criteria:**

- Foundation environment provisioning can be executed predictably and produces the identifiers required by later FSS tests.

### Integration Notes

**Dependencies:**

- `oci` CLI configured and authenticated.
- Permissions to create and destroy resources in `/oci_tf_fss`.

**Compatibility:**

- Later Terraform modules will consume the foundation subnet(s) and/or test client context for mount/export validation.

### Documentation Requirements

- The integration test must document prerequisites (OCI auth, compartment path) and expected outputs in its test specification.

### Design Decisions

- Use `oci_scaffold` for baseline environment provisioning (shell + OCI CLI) to unblock system-level tests before Terraform modules exist.

### Open Design Questions

- Whether the foundation should always provision a compute test client in Sprint 1, or defer compute provisioning until Sprint 3 when mount/export are available.

## YOLO Mode Decisions

Not applicable (managed mode).

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Provision foundation baseline (network + optional compute)

- **Preconditions:** OCI CLI authenticated; permissions to create resources in `/oci_tf_fss`; `jq` available.
- **Steps:** run the foundation provisioning logic (implemented via `oci_scaffold`) with a deterministic `NAME_PREFIX`.
- **Expected Outcome:** baseline resources exist and identifiers are available for downstream tests.
- **Verification:** test asserts that required identifiers are non-empty and that resources are in expected lifecycle state.
- **Target file:** `tests/integration/test_foundation.sh`

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
|--------------|-------|------------|-------------------|
| PBI-005 | — | — | IT-1 |

