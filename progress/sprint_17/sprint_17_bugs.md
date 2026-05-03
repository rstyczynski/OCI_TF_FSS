# Sprint 17 — Bugs

## BUG-12: Existing logging resources with same display name cause 409 conflicts

**Item:** PBI-032
**Severity:** high
**Status:** fixed

- **Symptom**: OCI Resource Manager apply fails with `409-Conflict, A log group in the compartment already uses this display name. Use a different name.` The failure occurs at `module.fss_stack.oci_logging_log_group.mount_target["primary"]` in `modules/fss_stack_sprint17/main.tf` on the `oci_logging_log_group` resource.
- **Root cause**: `fss_stack_sprint17` creates a logging log group by display name when `logging.enabled=true` and `logging.log_group_id` is omitted. OCI Logging requires the log group display name to be unique in the compartment. The module does not first look up an existing log group by the requested display name. The same design risk applies to the service log resource under the resolved log group.
- **Fix**: Updated `terraform/modules/fss_stack_sprint17` to resolve existing logging resources before creating them. If a requested log group name already exists in the target compartment, the module reuses that log group ID instead of creating a new one. If a requested service log display name already exists in the resolved log group, the module reuses that log ID instead of creating a duplicate after validating that the existing log is the expected File Storage NFS service log for the same mount target resource/category. The same fix was mirrored into the Sprint 16 vendored `fss_stack_sprint17` copies.
- **Verification**: `progress/sprint_17/bug12_validate_20260502_195501.log` validates the canonical Sprint 17 module and both Sprint 16 vendored ORM roots after the logging reuse fix. A1 smoke passed in `progress/sprint_17/test_run_A1_smoke_bug12_20260502_200524.log`. A3 integration passed in `progress/sprint_17/test_run_A3_integration_bug12_20260502_200530.log`, verifying live reuse of a pre-existing OCI Logging log group display name, creation of the File Storage NFS service log under that reused group, output consistency, and cleanup of temporary OCI resources.

## BUG-13: logging interface has log_group_id bypass but no equivalent log_id bypass

**Item:** PBI-032
**Severity:** medium
**Status:** fixed

- **Symptom**: Operators who already have an existing OCI Logging log OCID cannot bypass log lookup/creation. Only `log_group_id` exists for skipping log group management; there is no `log_id` to skip log management. The interface is asymmetric: supplying an existing log group OCID short-circuits group handling, but supplying an existing log OCID is impossible.
- **Root cause**: BUG-12 fix (lookup-before-create) added `log_group_id` as an explicit bypass for log groups but omitted the symmetric `log_id` bypass for logs. The `logging` object in `variables.tf` was not extended at that time.
- **Fix**: Add `log_id = optional(string)` to the `logging` object in `variables.tf`. In `main.tf`, exclude entries with `log_id != null` from `logging_lookup_logs` and `logging_created_logs`. In `resolved_mount_target_logging`, resolve `log_ocid` as `coalesce(mt.logging.log_id, existing_log_ids[key], oci_logging_log.mount_target[key].id)`. Mirror the same fix into Sprint 16 vendored copies.
- **Verification**: A1 smoke PASS — `progress/sprint_17/test_run_A1_smoke_bug13_20260503_083329.log`. A3 integration PASS — `progress/sprint_17/test_run_A3_integration_bug13_20260503_084751.log`: pre-created OCI log group + CUSTOM log, applied stack with `log_id` bypass, verified output OCID matches pre-created log, verified log count in group remained 1 (no new log created).
