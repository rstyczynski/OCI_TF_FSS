# Sprint 12 — Test Execution Results

## Summary

| Gate           | Result | Retries | Pass Rate |
|----------------|--------|---------|-----------|
| A3 Integration | PASS   | 0       | 100%      |

Regression: none (per PLAN.md).

## Artifacts

| Gate           | Log File                                                           |
|----------------|--------------------------------------------------------------------|
| A3 Integration | `progress/sprint_12/test_run_A3_integration_20260429_084147.log`   |

## Test Results

### IT-1: Examples validate

**Status:** PASS

`terraform validate` exited 0 with "The configuration is valid." for both `examples/basic_fss` and `examples/multi_fss_with_logging`. Both examples resolve their module source to the package root `fss_stack_sprint12`.

### IT-2: Basic example applies

**Status:** PASS

Full apply of `examples/basic_fss` with only `compartment_ocid` and `subnet_ocid` provided:

- 4 resources created: `random_shuffle`, mount target, filesystem, export
- `availability_domain_source = "random"` — AD derived via randomization (regional subnet, no explicit AD)
- `kms_key_mode = "ORACLE_MANAGED"` — no `kms_key_id` supplied
- `nfs_mount_sources["data__primary"] = "10.0.0.6:/data"` ✓
- Destroy completed cleanly: 4 resources destroyed

**Note:** Initial teardown used a helper that lacked `-var` flags. Fixed in the test file after the run; manual destroy confirmed all 4 resources removed.

## Failures

None.
