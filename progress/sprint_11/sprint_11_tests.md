# Sprint 11 - Tests

Status: Passed

## Quality Gates

- A3 integration: PASS
- Regression: none

## Artifacts

- PASS: `progress/sprint_11/test_run_A3_integration_final_20260429_075510.log`
- FLAKY/INFRA: `progress/sprint_11/test_run_A3_integration_20260429_075011.log`
- FLAKY/INFRA: `progress/sprint_11/test_run_A3_integration_retry_20260429_075031.log`
- PASS before final output normalization: `progress/sprint_11/test_run_A3_integration_retry2_20260429_075204.log`

## Results

- `test_IT1_minimal_v2_example_validates`: passed. Minimal v2 example validates without `availability_domain`, `kms_key_id`, or `default_source_cidr`.
- `test_IT2_full_v2_stack_applies`: passed. Applied two mount targets, two filesystems, three exports, one File Storage log, Oracle-managed encryption, default export source `0.0.0.0/0`, and AD selection through the Sprint 2 randomization path.
- Terraform teardown destroyed all 10 live resources.

## Flaky Failures

- First two A3 runs failed during provider installation with GitHub `502 Bad Gateway` for the OCI provider zip. No resources were created. The test harness now seeds a local Terraform plugin cache from existing sprint provider installs, and the final gate passed.
