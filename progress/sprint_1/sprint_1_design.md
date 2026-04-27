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
- Compute identifiers: instance OCID and IP, plus an SSH key usable by the operator to connect to the instance.
- Compartment: all resources in `/oci_tf_fss`.

**Planned `oci_scaffold` usage (design intent)**

- Prefer reusing existing `oci_scaffold` cycles where possible:
  - `cycle-subnet.sh` or `cycle-subnet-nat.sh` for network baseline
  - `cycle-compute.sh` for test client baseline
- Reuse `oci_scaffold` patterns for compute access and secret material handling (SSH key generation; vault/key/secret lifecycle) when they are needed for system-level testing.
- Ensure the compartment path is set to `/oci_tf_fss` for all runs.

**Reusable `oci_scaffold` approach (compute + vault/secret)**

The foundation design intentionally mirrors the way `oci_scaffold` already provisions integration-test stacks, so later system tests can use the same mechanics and expectations.

- **Compartment path enforcement**
  - Use `resource/ensure-compartment.sh` behavior: given a full path (e.g. `/oci_tf_fss`), it creates missing segments idempotently and records the final OCID in state as `.compartment.ocid`.
  - All subsequent ensure scripts take `.inputs.oci_compartment` (OCID) as the compartment for created resources.

- **Deterministic state + parallel safety**
  - State file naming is driven by `NAME_PREFIX`: default `STATE_FILE="${PWD}/state-${NAME_PREFIX}.json"` (from `do/oci_scaffold.sh`).
  - This allows parallel test runs by using different `NAME_PREFIX` values without collisions.

- **Compute instance provisioning pattern**
  - Reuse `cycle-compute.sh` approach:
    - Generate an SSH keypair if the instance is being created (and refuse to proceed if instance exists but key is missing).
    - Seed state inputs including:
      - `.inputs.oci_compartment` (final compartment OCID for `/oci_tf_fss`)
      - `.inputs.name_prefix` (used for resource names)
      - `.inputs.subnet_prohibit_public_ip=false` and security list ingress CIDR to allow operator SSH access
      - `.inputs.compute_ssh_authorized_keys_file` pointing to the generated public key
    - Provision network prerequisites then `resource/ensure-compute.sh` to create/adopt an instance.
    - Record compute outputs in state:
      - `.compute.ocid`, `.compute.private_ip`, optional `.compute.public_ip`
    - Validate SSH connectivity as part of system-level acceptance:
      - operator can `ssh -i state-<NAME_PREFIX>-key opc@<public-ip>` and run basic commands

- **Vault / key / secret provisioning pattern**
  - Reuse `cycle-vault.sh` approach for secrets needed by system tests (when applicable):
    - `resource/ensure-vault.sh` creates or adopts a vault and records `.vault.ocid` and `.vault.mgmt_endpoint`
    - `resource/ensure-key.sh` creates or adopts a KMS key under the vault endpoint and records `.key.ocid`
    - `resource/ensure-secret.sh` creates or updates a secret (base64 content) and records `.secret.ocid` / `.secret.name`
  - This pattern supports scheduled-deletion recovery (cancel deletion when re-running within the retention window), which is important for retry-safe integration test loops.

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

- None (decision: provision a public SSH-accessible compute test client in Sprint 1).

### Foundation Network Profile (Sprint 1 decision)

The foundation environment provisions a **publicly reachable test client** so the operator can SSH and interact with FSS tooling:

- Compute instance has a **public IP** and is reachable on SSH from the operator network.
- Network includes an **Internet Gateway (IGW)** to support public access.
- This choice is made solely to satisfy the operator requirement for SSH access; it is not a statement that FSS itself requires internet/OSN.

## YOLO Mode Decisions

Not applicable (managed mode).

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Provision foundation baseline (network + optional compute)

- **Preconditions:** OCI CLI authenticated; permissions to create resources in `/oci_tf_fss`; `jq` available.
- **Steps:** run the foundation provisioning logic (implemented via `oci_scaffold`) with a deterministic `NAME_PREFIX`, following the same patterns as `cycle-compute.sh` and (when secrets are required) `cycle-vault.sh`.
- **Expected Outcome:** baseline resources exist, identifiers are available for downstream tests, and the operator can connect to the test client via SSH.
- **Verification:** test asserts required identifiers are non-empty and performs an SSH readiness check to the instance (connect + run `true` / `hostname`).
- **Target file:** `tests/integration/test_foundation.sh`

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
|--------------|-------|------------|-------------------|
| PBI-005 | — | — | IT-1 |

