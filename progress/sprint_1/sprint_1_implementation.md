# Sprint 1 - Implementation Notes

## Implementation Overview

**Sprint Status:** under_construction

**Backlog Items:**

- PBI-005. Foundation infrastructure for system-level FSS tests — under_construction

## PBI-005. Foundation infrastructure for system-level FSS tests

Status: under_construction

### Implementation Summary

Implemented the Sprint 1 foundation integration test to provision a public SSH-accessible test client using `oci_scaffold` patterns in the `/oci_tf_fss` compartment path. The test provisions the required baseline resources idempotently and validates operator SSH connectivity and cloud-init completion.

### Code Artifacts

| Artifact | Purpose | Status | Tested |
|----------|---------|--------|--------|
| `tools/infra_setup.sh` | `sprint1_foundation_infra_setup`: Vault/KMS/secret, network, compute | Complete | Phase 4 gates (`sprint_1_tests.md`) |
| `tools/go_remote.sh` | SSH to foundation compute using scaffold state (Vault or local key) | Complete | — |
| `tests/integration/test_foundation.sh` | Provision foundation baseline and validate SSH | Complete | Phase 4 gates (`sprint_1_tests.md`) |
| `tests/run.sh` | Test runner for RUP quality gates | Complete | Phase 4 gates (`sprint_1_tests.md`) |
| `progress/sprint_1/sprint_1_operator_manual.md` | Operator paths, teardown, env vars | Complete | — |

### User Documentation

#### Prerequisites

- OCI CLI configured and authenticated (`oci`).
- `jq`, `ssh`, `ssh-keygen` available (`infra_setup` uses RSA PEM keys: **`ssh-keygen -m PEM`**).
- Permissions to create resources in compartment path `/oci_tf_fss`.

#### Usage

Run the Sprint 1 new integration test (new-only):

```bash
tests/run.sh --integration --new-only progress/sprint_1/new_tests.manifest
```

To keep resources for operator interaction (skip teardown), run:

```bash
SKIP_TEARDOWN=true SPRINT1_NAME_PREFIX=infra COMPARTMENT_PATH=/oci_tf_fss \
  tests/run.sh --integration --new-only progress/sprint_1/new_tests.manifest
```

OCI scaffold state defaults to **`progress/sprint_1/scaffold/<NAME_PREFIX>/`** (see **`RUP_patch.md`** P7); Terraform tests use **`progress/sprint_1/tf_state/`** separately.

Expected output includes **`INFO: workdir=.../progress/sprint_1/scaffold/...`**, **`SSH public key file`**, and (when Vault-backed) that the private key is **not** kept under **`state-<prefix>-key`** on disk. SSH for acceptance uses a key materialized from **`oci secrets secret-bundle get`** (see **`sprint_1_operator_manual.md`**). For interactive use after provisioning, operators can run **`./tools/go_remote.sh`** from the repo root (same key materialization rules as **`infra_setup.sh`**).

### Known Issues

- If OCI credentials are not available in the environment running the tests, Phase 4 gates must be recorded as NOT RUN with reasons per `RUP_patch.md`.

## Sprint Implementation Summary

### Overall Status

under_construction

