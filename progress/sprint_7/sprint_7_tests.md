# Sprint 7 — Test Execution Results

## Summary

| Gate | Result | Retries | Pass Rate |
|------|--------|---------|-----------|
| A3 Integration | PASS | 0 | 100% |

Regression: none (per PLAN.md).

## Artifacts

| Gate | Log File |
|------|----------|
| Skeleton red | `progress/sprint_7/test_run_skeleton_red_20260428_164054.log` |
| A3 Integration | `progress/sprint_7/test_run_A3_integration_20260428_164808.log` |

## Test Results

### IT-1: New variable structure passes static validation

**Status:** PASS

`terraform validate` exited 0 with "Success! The configuration is valid." for a root module using `fss_sprint7_stack` with two mount targets and two filesystems each having two cross-referenced exports.

### IT-2: Stack applies with cross-referenced mount targets and filesystems

**Status:** PASS

Full apply created 8 OCI resources (2 mount targets, 2 filesystems, 4 exports). All assertions passed:

- Both `mt_primary` and `mt_secondary` mount target OCIDs non-empty.
- Both `fs_alpha` and `fs_beta` filesystem OCIDs non-empty.
- `nfs_mount_sources` contains exactly 4 entries.
- `fs_alpha.exports` and `fs_beta.exports` each contain exactly 2 nested export entries.
- `fs_alpha / export_to_secondary` → `identity_squash = NONE` ✓
- `fs_beta / export_to_primary` → `identity_squash = NONE` ✓
- `fs_alpha / export_to_primary` → `identity_squash = ROOT` ✓
- `fs_beta / export_to_secondary` → `identity_squash = ROOT` ✓
- All `nfs_mount_source` strings match `<addr>:<path>` pattern ✓

Destroy completed cleanly: 8 resources destroyed.

## Failures

None.
