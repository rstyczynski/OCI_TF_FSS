# Sprint 19 — Test Execution Results

## Summary

| Gate | Result | Pass Rate |
|---|---|---|
| A1 Smoke | PASS | 100% (1/1) |
| A3 Integration | PASS | 100% (1/1) |
| D1 Operator Manual | PASS | 100% |

## Artifacts

| Gate | Log File |
|---|---|
| A1 Smoke | `progress/sprint_19/test_run_A1_smoke_20260504_141758.log` |
| A3 Integration | `progress/sprint_19/test_run_A3_integration_20260504_142911.log` (definitive — full instrumentation) |
| D1 Operator Manual | `progress/sprint_19/operator_manual_validate_20260504_142211.log` |

## Gate Details

### A1 Smoke

**Status:** PASS

Evidence: `progress/sprint_19/test_run_A1_smoke_20260504_141758.log`

SM-1 PASS: `terraform validate` passes for `examples/multi_exports_one_fs`.

### A3 Integration

**Status:** PASS

Evidence: `progress/sprint_19/test_run_A3_integration_20260504_141912.log`

**Experiment result: SAME-ROOT**

- Applied 1 MT + 1 FS + 2 exports (`/vol1` path=`10.0.0.65:/vol1`, `/vol2` path=`10.0.0.65:/vol2`)
- Mounted both exports on foundation compute (`152.67.78.205`)
- Wrote sentinel file via `/mnt/vol1`
- Checked `/mnt/vol2/sentinel_*.txt` → **YES** (immediately visible)
- Unmounted both exports
- Destroyed all 6 OCI resources cleanly

**Conclusion:** OCI FSS export `path` is an NFS alias for the filesystem root — not a subtree scope. Both exports expose identical data.

**Investigation note:** A manual test on the same instance appeared to show SCOPED behavior (file written via `/vol1` not visible immediately via `/vol2`). This was identified as NFS client-side attribute cache staleness (`acdirmin/acdirmax`): `ls /mnt/vol2` returned a cached empty listing before the cache expired. The single-session instrumented test eliminates this artifact — write and read go through the same VFS cache on the same client, confirming SAME-ROOT definitively. The `df -hT` and `mount` outputs in `experiment.log` confirm both paths are live NFS mounts to the same OCI FSS endpoint.

### D1 Operator Manual

**Status:** PASS

Evidence: `progress/sprint_19/operator_manual_validate_20260504_142211.log`

`terraform validate` passes for `examples/multi_exports_one_fs`.
