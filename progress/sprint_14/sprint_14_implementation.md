# Sprint 14 - Implementation

Status: Complete

## PBI-027. Add legacy PV report to FSS stack variables converter

Implemented:

- `tools/convert_pv_report_to_fss_tfvars.py`
- `tests/unit/test_pv_report_converter.sh`
- `tests/integration/test_pv_report_converter.sh`
- `tests/manifests/component_pv_report_converter.manifest`

The converter parses legacy report files and emits `mount_targets` and `filesystems` variables for `terraform/modules/fss_stack_sprint12/`.

Generated operator-review artifacts:

- `progress/sprint_14/generated_tf/template1.auto.tfvars`
- `progress/sprint_14/generated_tf/it1_apply_template2/generated.auto.tfvars`
- `progress/sprint_14/generated_tf/it1_apply_template2/main.tf`

## Mapping

- distinct legacy `server` -> one `mount_targets` entry
- PV -> one filesystem entry
- PV `path` -> `exports.primary.path`
- legacy `PV Name`, `server`, `storageclass`, and `path` -> filesystem freeform tags

## YOLO Decisions

- Integration apply uses `etc/pv-template2-details` because it is the smallest real template and still proves the converter output can create a live mount target, filesystem, export, and mount source through Sprint 12.
- Larger templates are covered by unit conversion tests to avoid unnecessary OCI resource cost and runtime.
