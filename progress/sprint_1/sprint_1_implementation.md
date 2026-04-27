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
| `tests/integration/test_foundation.sh` | Provision foundation baseline and validate SSH | Complete | No (Phase 4 gates) |
| `tests/run.sh` | Test runner for RUP quality gates | Complete | No (Phase 4 gates) |

### User Documentation

#### Prerequisites

- OCI CLI configured and authenticated (`oci`).
- `jq`, `ssh`, `ssh-keygen` available.
- Permissions to create resources in compartment path `/oci_tf_fss`.

#### Usage

Run the Sprint 1 new integration test (new-only):

```bash
tests/run.sh --integration --new-only progress/sprint_1/new_tests.manifest
```

To keep resources for operator interaction (skip teardown), run:

```bash
SKIP_TEARDOWN=true NAME_PREFIX=fss_foundation COMPARTMENT_PATH=/oci_tf_fss \
  tests/run.sh --integration --new-only progress/sprint_1/new_tests.manifest
```

Expected output includes an SSH command like:

```text
INFO: ssh command: ssh -i /tmp/.../state-fss_foundation-key opc@<public-ip>
```

### Known Issues

- If OCI credentials are not available in the environment running the tests, Phase 4 gates will be recorded as NOT RUN with reasons per `RUP_patch.md`.

## Sprint Implementation Summary

### Overall Status

under_construction

