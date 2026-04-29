# Sprint 14 - Test Execution Results

Status: Complete

## Summary

| Gate | Result | Log File |
|---|---|---|
| A2 Unit | PASS | `progress/sprint_14/test_run_A2_unit_20260429_130459.log` |
| A3 Integration | PASS | `progress/sprint_14/test_run_A3_integration_20260429_130514.log` |

Regression: none (per PLAN.md).

## Results

- A2 unit first attempt failed in `progress/sprint_14/test_run_A2_unit_20260429_130343.log`; the converter key normalization was corrected and rerun.
- A2 unit rerun converted all three templates, validated expected counts, and verified malformed report handling.
- A3 integration converted `etc/pv-template2-details`, generated a Terraform root under `progress/sprint_14/generated_tf/it1_apply_template2/`, applied `terraform/modules/fss_stack_sprint12`, verified one mount target, one filesystem, one export, and one NFS mount source, then destroyed all four created resources.

## Integration Proof

The integration log includes the Sprint 12 stack output:

```text
pv_static_007__primary = "10.0.0.105:/legacy-nas-b/tenant-gamma/pv-static-007"
```

Teardown proof:

```text
Destroy complete! Resources: 4 destroyed.
```
