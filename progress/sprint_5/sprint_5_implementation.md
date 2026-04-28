# Sprint 5 - Implementation Notes

## Implementation Overview

**Sprint Status:** implemented

**Backlog Items:**

- PBI-007. FSS module - expose kms_key_id argument at mandatory variables - implemented
- PBI-008. FSS module - expose rest of all available arguments at with default values - implemented
- PBI-009. Create higher level module that accepts map of arguments to support multiple FSS with all mount points and exports - implemented

## PBI-007. FSS module - expose kms_key_id argument at mandatory variables

Status: implemented

Implemented `terraform/modules/fss_sprint5_filesystem/` with mandatory `kms_key_id`. The Sprint 5 integration harness includes `_ensure_sprint5_mek`, which creates or ensures an FSS MEK in the Sprint 1 Vault and stores recoverable runtime state under `progress/sprint_5/scaffold/fss-mek/`.

## PBI-008. FSS module - expose rest of all available arguments at with default values

Status: implemented

The Sprint 5 filesystem module exposes optional scalar arguments with `null` defaults, tag maps, optional `locks`, and optional `timeouts` dynamic blocks. Mandatory and optional variables are clearly separated in `variables.tf`.

`id` is not exposed as an input because Terraform rejects it in resource configuration even though the provider schema marks it optional/computed. It remains available as the computed `filesystem_ocid` output.

## PBI-009. Create higher level module that accepts map of arguments to support multiple FSS with all mount points and exports

Status: implemented

Implemented `terraform/modules/fss_sprint5_stack/` as a composition module. It accepts a `filesystems` map, creates one Sprint 5 filesystem, Sprint 4 mount target, and Sprint 4 export per key, and returns output maps keyed by the same stable names.

Per-entry `mount_target_display_name` is optional and defaults to `fss-mt-${each.key}`. Per-entry `source_cidr` is optional when `default_source_cidr` is provided.

## Test Implementation

Filled `tests/integration/test_fss_sprint5_tf.sh`:

- IT-1 verifies missing `kms_key_id` fails Terraform validation.
- IT-2 provisions one filesystem with the Sprint 5 MEK and an optional tag argument.
- IT-3 provisions two full FSS stack entries from one map input.

Generated Terraform roots are written under `progress/sprint_5/generated_tf/` and `main.tf` files are preserved for operator review.

## Construction Verification

- `terraform fmt -check -recursive terraform/modules/fss_sprint5_filesystem terraform/modules/fss_sprint5_stack`
- `bash -n tests/integration/test_fss_sprint5_tf.sh`
- `terraform validate` for both Sprint 5 modules
- IT-1 missing KMS key error path

Evidence log:

- `progress/sprint_5/test_run_construction_static_20260428_091301.log`

## Known Issues

- Quality gates are not run yet. Managed-mode approval is required before Phase 4.
