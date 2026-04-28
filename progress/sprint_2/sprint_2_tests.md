# Sprint 2 — Test Execution Results

## Summary

| Gate           | Result | Retries | Pass Rate |
|----------------|--------|---------|-----------|
| A3 Integration | PASS   | 2       | 100%      |
| A3 Integration rename verification | PASS | 1 | 100% |
| B3 Integration | PASS   | 0       | 100%      |

## Artifacts

- **A3 Integration**: `progress/sprint_2/test_run_defaults_path_20260427_201241.log`
- **A3 Integration rename verification (failed retry)**: `progress/sprint_2/test_run_A3_integration_20260428_065525.log`
- **A3 Integration rename verification (pass)**: `progress/sprint_2/test_run_A3_integration_20260428_065658.log`
- **B3 Integration**: `progress/sprint_2/test_run_B3_integration_20260427_184520.log`

## Failures (if any)

### Retry 1-2 — A3 Integration

- **Note:** Sprint 2 tests have been reindexed and expanded. See the latest A3 evidence log above.

### Retry 1 — A3 Integration rename verification

- **Failure log:** `progress/sprint_2/test_run_A3_integration_20260428_065525.log`
- **Issue:** `IT-3` saw immediate Oracle-managed `defined_tags` propagation after create and treated that known provider behavior as an unexpected no-change-plan diff.
- **Fix:** `IT-3` now tolerates only the narrow Oracle-managed `defined_tags` update and keeps `IT-5` as the refreshed tag idempotency assertion.
- **Result:** Passed on retry in `progress/sprint_2/test_run_A3_integration_20260428_065658.log`.
