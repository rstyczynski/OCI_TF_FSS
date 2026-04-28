# Sprint 4 - Test Evidence

## Quality Gate Approval

Managed-mode quality gate approval was accepted in `progress/sprint_4/sprint_4_openquestions.md`.

## A3 New-Code Integration Gate

Command:

```bash
tests/run.sh --integration --new-only progress/sprint_4/new_tests.manifest
```

Final result: PASS.

Evidence log:

- `progress/sprint_4/test_run_A3_integration_20260428_081015.log`

Summary:

- `test_IT1_mount_target_happy_path`: PASS
- `test_IT2_export_happy_path`: PASS
- `test_IT3_path_analyzer_reachability`: PASS
- Suite summary: `pass=3 fail=0`

NPA proof from A3:

- Result: `SUCCEEDED`
- Source: `10.0.0.39`
- Destination: `10.0.0.142:2049`
- Log lines: `progress/sprint_4/test_run_A3_integration_20260428_081015.log:834-835`

## B3 Full Integration Regression Gate

Command:

```bash
tests/run.sh --integration
```

Final result: PASS.

Evidence log:

- `progress/sprint_4/test_run_B3_integration_20260428_081543.log`

Summary:

- `test_foundation.sh`: PASS
- `test_fss_sprint2_tf.sh`: PASS
- `test_fss_sprint3_tf.sh`: PASS
- `test_fss_sprint4_tf.sh`: PASS
- Suite summary: `pass=4 fail=0`

NPA proof from B3:

- Result: `SUCCEEDED`
- Source: `10.0.0.39`
- Destination: `10.0.0.94:2049`
- Log lines: `progress/sprint_4/test_run_B3_integration_20260428_081543.log:2042-2043`

## Failed A3 Attempts

Two earlier A3 attempts failed before the NPA endpoint model was corrected:

- `progress/sprint_4/test_run_A3_integration_20260428_075851.log`: NPA used the default subnet source and IP destination; result `FAILED`.
- `progress/sprint_4/test_run_A3_integration_20260428_080452.log`: NPA used the foundation compute source IP but still used an IP destination; result `FAILED`.

The final implementation uses the foundation compute VNIC as source and the mount target VNIC as destination while preserving TCP/2049 as the target service port.
