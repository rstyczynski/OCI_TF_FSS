# Sprint 12 — Bugs

## BUG-1: identity_squash = "NONE" not verified at NFS level

**Item:** PBI-024
**Severity:** medium
**Status:** promoted → PBI-025

- **Symptom**: Quality gates ran `terraform validate` on `multi_fss_with_logging` (IT-1) and applied `basic_fss` (IT-2). The `multi_fss_with_logging` example, which sets `identity_squash = "NONE"` on `data/primary`, was never applied and the resulting NFS mount was never verified. There is no test evidence that remote root actually gains write access when NONE squash is configured.
- **Root cause**: IT-2 was scoped to `basic_fss` only (default ROOT squash). No test case applied `multi_fss_with_logging` or mounted the export and verified admin access behavior.
- **Fix**: A new integration test IT-3 must apply `multi_fss_with_logging`, SSH to the foundation compute, mount the NONE-squash export, confirm that `sudo mkdir` succeeds, mount the ROOT-squash export, confirm that root operations are squashed, then clean up.
- **Verification**: Deferred to PBI-025.

**Promotion reason:** Sprint 12 is closed. Fix requires a new apply + SSH + mount test cycle beyond the current sprint's completed scope.

**Resolution:** IT-3 executed successfully on 2026-04-29.
Log: `progress/sprint_12/test_run_A3_integration_IT3_20260429_105553.log`

- `identity_squash = "NONE"` on `data__primary` (10.0.0.32:/data): `sudo mkdir` → `MKDIR_NONE_OK` ✅
- `identity_squash = "ROOT"` on `data__secondary` (10.0.0.95:/data-secondary): `sudo mkdir` → `MKDIR_ROOT_FAIL` ✅

**Verdict:** feature works correctly. PBI-025 can be closed.
