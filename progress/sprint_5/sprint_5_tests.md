# Sprint 5 - Test Execution Results

## Summary

| Gate | Result | Retries | Pass Rate |
|------|--------|---------|-----------|
| A3 Integration | PASS | 1 | 100% |
| B3 Integration | PASS | 0 | 100% |

Sprint 5 has `Test: integration` and `Regression: integration`, so only A3 and B3 gates are applicable.

## Artifacts

| Gate | Result | Log File |
|------|--------|----------|
| A3 Integration attempt 1 | FAIL | `progress/sprint_5/test_run_A3_integration_20260428_094845.log` |
| A3 Integration retry 1 | PASS | `progress/sprint_5/test_run_A3_integration_20260428_095544.log` |
| B3 Integration regression | PASS | `progress/sprint_5/test_run_B3_integration_20260428_095918.log` |

## Failures

### Retry 1 - A3 Integration

- **Test:** `test_fss_sprint5_tf.sh:test_IT2_filesystem_with_kms_and_optional_argument` and `test_IT3_stack_creates_multiple_entries`
- **Error:** OCI File Storage returned `404-NotAuthorizedOrNotFound` for the Sprint 5 KMS key during filesystem creation.
- **Classification:** Broken integration setup, not flaky. The first attempt consistently showed that the MEK existed but FSS was not authorized to use it.
- **Fix:** Added Sprint 5 IAM prerequisite setup: filesystem dynamic group plus explicit KMS-use policy statements applied through `oci_scaffold/resource/ensure-iam_policy.sh`.
- **Result:** A3 retry passed with `pass=3 fail=0`.

## Regression Notes

B3 ran the full integration suite:

- `test_foundation.sh`
- `test_fss_sprint2_tf.sh`
- `test_fss_sprint3_tf.sh`
- `test_fss_sprint4_tf.sh`
- `test_fss_sprint5_tf.sh`

The Sprint 4 Network Path Analyzer regression reported the FSS NFS path as reachable in `progress/sprint_5/test_run_B3_integration_20260428_095918.log`.
