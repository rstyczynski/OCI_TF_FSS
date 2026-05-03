# Sprint 17 - Tests

## Quality gates

Status: PASS

### Final check

**Status:** PASS

Evidence: `progress/sprint_17/final_check_20260430_154857.log`

### A1 Smoke (new code)

**Status:** PASS

Evidence: `progress/sprint_17/test_run_A1_smoke_20260430_151303.log`

### A3 Integration (new code)

**Status:** PASS

Evidence: `progress/sprint_17/test_run_A3_integration_20260430_152421.log`

### D1 Operator Manual

**Status:** PASS

Evidence: `progress/sprint_17/operator_manual_validate_20260430_151136.log`

### BUG-12 Validation

**Status:** PASS

Evidence: `progress/sprint_17/bug12_validate_20260502_195501.log`

Scope: targeted Terraform validation for the BUG-12 logging reuse fix. It validates the canonical `terraform/modules/fss_stack_sprint17` module and both Sprint 16 vendored ORM roots after the lookup-before-create logging change.

### BUG-12 A1 Smoke Gate

**Status:** PASS

Evidence: `progress/sprint_17/test_run_A1_smoke_bug12_20260502_200524.log`

Scope: `tests/run.sh --smoke --new-only progress/sprint_17/new_tests.manifest`

### BUG-12 A3 Integration Gate

**Status:** PASS

Evidence: `progress/sprint_17/test_run_A3_integration_bug12_20260502_200530.log`

Scope: `tests/run.sh --integration --new-only progress/sprint_17/new_tests.manifest`

Result: verified that the module reuses a pre-existing OCI Logging log group with the requested display name, creates the File Storage NFS service log under that reused group, confirms logging output consistency, and tears down the temporary OCI resources.

Notes:

- Apply/destroy snippets in `progress/sprint_17/sprint_17_operator_manual.md` are marked **NOT RUN** because they require a live OCI environment and credentials.

### BUG-13 A1 Smoke Gate

**Status:** PASS

Evidence: `progress/sprint_17/test_run_A1_smoke_bug13_20260503_083329.log`

Scope: `tests/run.sh --smoke --new-only progress/sprint_17/new_tests.manifest` — verifies `log_id` field present in canonical and Sprint 16 vendored `variables.tf`, lookup/creation exclusion logic in `main.tf`, and `terraform validate` passes for all three modules.

### BUG-13 A3 Integration Gate

**Status:** PASS

Evidence: `progress/sprint_17/test_run_A3_integration_bug13_20260503_084751.log`

Scope: `tests/run.sh --integration --new-only progress/sprint_17/new_tests.manifest` — pre-created a CUSTOM log group + log via OCI CLI, applied `fss_stack_sprint17` with `logging.log_group_id` and `logging.log_id` set to the pre-created OCIDs, verified output `log_ocid` equals the pre-created log OCID (bypass worked), verified log count in group remained 1 (no new log created by Terraform), tore down mount target and pre-created OCI resources.
