# Sprint 5 - Bugs

## BUG-001. Provider schema reports id as configurable, Terraform rejects it

**Item:** PBI-008
**Severity:** medium
**Status:** fixed

- **Symptom**: `terraform validate` failed for `terraform/modules/fss_sprint5_filesystem` with `Invalid or unknown key` on `id = var.id`.
- **Root cause**: The OCI provider schema reports `id` as optional/computed, but Terraform rejects `id` in resource configuration for `oci_file_storage_file_system`.
- **Fix**: Removed `id` from Sprint 5 input variables and resource configuration; kept the computed resource ID exposed as `filesystem_ocid`.
- **Verification**: `progress/sprint_5/test_run_construction_static_20260428_091301.log` shows both Sprint 5 modules validate successfully.

## BUG-002. FSS could not use Sprint 5 MEK without IAM policy prerequisites

**Item:** PBI-007
**Severity:** high
**Status:** fixed

- **Symptom**: A3 integration attempt failed in IT-2 and IT-3 with `404-NotAuthorizedOrNotFound` for the Sprint 5 KMS key when creating `oci_file_storage_file_system`.
- **Root cause**: The harness created the MEK but did not ensure the OCI File Storage customer-managed-key IAM prerequisites: filesystem dynamic group and KMS-use policy for the dynamic group plus the File Storage service principal.
- **Fix**: Extended the harness to create or update the filesystem dynamic group, write explicit KMS-use policy statements into Sprint 5 scaffold state, and call `oci_scaffold/resource/ensure-iam_policy.sh` instead of embedding direct policy creation in the test harness.
- **Verification**: `progress/sprint_5/test_run_A3_integration_20260428_095544.log` shows A3 passed after the fix with `pass=3 fail=0`.
