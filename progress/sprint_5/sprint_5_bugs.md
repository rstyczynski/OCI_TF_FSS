# Sprint 5 - Bugs

## BUG-001. Provider schema reports id as configurable, Terraform rejects it

**Item:** PBI-008
**Severity:** medium
**Status:** fixed

- **Symptom**: `terraform validate` failed for `terraform/modules/fss_sprint5_filesystem` with `Invalid or unknown key` on `id = var.id`.
- **Root cause**: The OCI provider schema reports `id` as optional/computed, but Terraform rejects `id` in resource configuration for `oci_file_storage_file_system`.
- **Fix**: Removed `id` from Sprint 5 input variables and resource configuration; kept the computed resource ID exposed as `filesystem_ocid`.
- **Verification**: `progress/sprint_5/test_run_construction_static_20260428_091301.log` shows both Sprint 5 modules validate successfully.
