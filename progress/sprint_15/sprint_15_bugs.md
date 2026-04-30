# Sprint 15 — Bugs

## BUG-10: Operator manual missing OCI Resource Manager CLI chapter

**Item:** PBI-026, PBI-028
**Severity:** high
**Status:** fixed

- **Symptom**: `sprint_15_operator_manual.md` covers the direct `terraform apply` path only. Sprint 15 stacks are designed for OCI Resource Manager; operators who use ORM via the CLI (`oci resource-manager stack create`, job polling, state extraction) have no documented path.
- **Root cause**: ORM CLI workflow was only covered implicitly by the A3 integration test script; it was never surfaced as an operator chapter.
- **Fix**: Add an "ORM CLI" chapter to the operator manual with copy/paste commands for: package, create stack, apply job, poll job, extract outputs from job state, destroy job, delete stack — for both stacks in order.
- **Verification**: Chapter is marked EXECUTED with reference to `test_run_A3_integration_20260430_095710.log` (the A3 gate already exercised every ORM CLI command in this path).

**Resolution:** Fixed 2026-04-30.

## BUG-9: Operator manual missing complete deploy/apply/destroy CLI workflow

**Item:** PBI-026, PBI-028
**Severity:** high
**Status:** fixed

- **Symptom**: `sprint_15_operator_manual.md` contains only the zip packaging snippet. No commands exist for: prerequisite validation, stack deployment (`terraform apply`), reading outputs, NFS mount verification, or stack destroy. P8 (RUP_patch.md) requires every snippet to be executed or explicitly marked NOT RUN with a reason.
- **Root cause**: Operator manual was created with packaging content only; deploy workflow was never drafted.
- **Fix**: Add complete Deploy, Outputs, Mount, and Destroy sections. Mark all new snippets `NOT RUN — requires live OCI environment and credentials` per P8.
- **Verification**: Manual contains end-to-end workflow; every snippet is either marked EXECUTED with log reference or NOT RUN with explicit reason.

**Resolution:** Fixed 2026-04-30.

## BUG-8: ORM root outputs.tf files do not re-expose all outputs from the fss_stack intermediate modules

**Item:** PBI-026, PBI-028
**Severity:** medium
**Status:** fixed

- **Symptom**: `mount_target/outputs.tf` does not expose `availability_domain` and `subnet_ocid` as standalone outputs even though `fss_stack_sprint15_mount_target` provides them. `filesystem_export/outputs.tf` does not expose `filesystem_display_name` even though `fss_stack_sprint15_filesystem_export` provides it. Values are reachable only inside summary objects.
- **Root cause**: ORM root outputs were written selectively rather than forwarding every output from the intermediate stack module.
- **Fix**: Add the three missing standalone outputs to the respective root `outputs.tf` files.
- **Verification**: `terraform validate` — Success on both roots.

**Resolution:** Fixed 2026-04-30.

## BUG-7: mount_target schema.yaml uses flat Tags group instead of per-tag variableGroups

**Item:** PBI-026
**Severity:** medium
**Status:** fixed

- **Symptom**: `mount_target/schema.yaml` places all tag variables in a single flat "Tags" variableGroup. `filesystem_export/schema.yaml` models each optional export as its own variableGroup ("Export 1" … "Export 6") with the next "Add another" checkbox at the bottom of each group, making the chained pattern visible in the ORM UI. The mount target tag section does not follow this pattern.
- **Root cause**: Tags were written as one flat group without reference to the per-section dynamic pattern used for exports.
- **Fix**: Replace the single "Tags" variableGroup with ten individual tag groups ("Tag 1" … "Tag 10"). Each group holds the key, value, and the "Add another tag" checkbox for the next slot. Groups 2–10 variables carry `visible: ${add_tag_N}` conditions, consistent with filesystem's per-export chained pattern.
- **Verification**: `schema.yaml` lint passes; ORM upload shows Tag 1 visible by default and subsequent tag groups revealed by each "Add another tag" toggle.

**Resolution:** Fixed 2026-04-30.

## BUG-6: Sprint 15 ORM stacks call sub-modules directly — missing intermediate fss_stack module layer

**Item:** PBI-026, PBI-028
**Severity:** high
**Status:** fixed

- **Symptom**: `mount_target/main.tf` calls `module "mount_target" { source = "./modules/fss_mount_target" }` directly. `filesystem_export/main.tf` calls `module "filesystem"` and `module "export"` directly. Sprint 13 (`fss_stack_sprint13_orm`) calls `module "fss" { source = "./modules/fss_stack_sprint12" }`, and `fss_stack_sprint12` in turn calls the sub-modules. Sprint 15 is missing the intermediate stack-module layer.
- **Root cause**: BUG-3 fix (2026-04-29) added only one module layer (ORM root → sub-modules). Sprint 13's two-layer architecture (ORM root → fss_stack module → sub-modules) was not replicated.
- **Fix**: Introduce an intermediate stack module for each Sprint 15 stack root:
  - `mount_target/modules/fss_stack_sprint15_mount_target/` — orchestrates `fss_mount_target` sub-module plus logging resources; ORM root delegates to it.
  - `filesystem_export/modules/fss_stack_sprint15_filesystem_export/` — orchestrates `fss_filesystem` and `fss_export` sub-modules; ORM root delegates to it.
- **Future simplification**: PBI-030 tracks the evaluation of removing the module layer entirely (reverting to direct resources). That is a separate decision and does not block this fix.
- **Verification**: `terraform validate` — Success on both roots. ORM root `main.tf` for each stack contains a single `module "fss_stack"` call; all OCI resource creation happens inside the intermediate stack modules.

**Resolution:** Fixed 2026-04-30. Architecture:
- `mount_target/` root → `modules/fss_stack_sprint15_mount_target/` → `modules/fss_mount_target/`
- `filesystem_export/` root → `modules/fss_stack_sprint15_filesystem_export/` → `modules/fss_filesystem/` + `modules/fss_export/`
- Zips: `fss-mount-target.zip` (18 files, 25 KB), `fss-filesystem-export.zip` (24 files, 41 KB)

## BUG-1: fss-filesystem-export.zip packaged from wrong directory

**Item:** PBI-028
**Severity:** critical
**Status:** fixed

- **Symptom**: `progress/sprint_15/generated_tf/manual/fss-filesystem-export.zip` contains `progress/sprint_15/generated_tf/manual/fss-mount-target.zip` nested inside it. Uploading this zip to OCI Resource Manager will fail or produce an invalid stack because the archive includes unrelated project files rather than just the ORM root (`main.tf`, `variables.tf`, `outputs.tf`, `schema.yaml`, `versions.tf`).
- **Root cause**: The zip was created by running `zip` from within `progress/sprint_15/generated_tf/manual/` (capturing the sibling `fss-mount-target.zip` in the archive) instead of from `terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export/`.
- **Fix**: Regenerate both zip files by zipping only the contents of the respective stack directories:

```bash
cd terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export
zip -r ../../../../progress/sprint_15/generated_tf/manual/fss-filesystem-export.zip \
  main.tf variables.tf outputs.tf schema.yaml versions.tf

cd ../mount_target
zip -r ../../../../progress/sprint_15/generated_tf/manual/fss-mount-target.zip \
  main.tf variables.tf outputs.tf schema.yaml versions.tf
```

- **Verification**: Unzip and confirm no `progress/` directory is present; `terraform validate` passes inside the extracted directory.

**Resolution:** Both zips regenerated correctly on 2026-04-29 using explicit file listing (no recursive, no exclude). Results:

- `fss-mount-target.zip`: 4.3 KB, 5 files (`main.tf variables.tf outputs.tf schema.yaml versions.tf`)
- `fss-filesystem-export.zip`: 5.1 KB, 5 files (`main.tf variables.tf outputs.tf schema.yaml versions.tf`)

Root cause of prior bad zip: macOS `zip -r` updates existing archives rather than replacing them, and `--exclude` patterns do not suppress the provider binary reliably. Fix: always `rm` existing zip first; zip explicit files by name rather than recursively.

## BUG-5: mount_target logging resources missing defined_tags — inconsistent with filesystem and Sprint 12 pattern

**Item:** PBI-026
**Severity:** medium
**Status:** fixed

- **Symptom**: `oci_logging_log_group.mount_target` and `oci_logging_log.mount_target` in `mount_target/main.tf` set `freeform_tags` but omit `defined_tags`. `module "mount_target"` and `module "filesystem"` in their respective stacks both pass `defined_tags = {}`. Sprint 12's full stack (`fss_stack_sprint12/main.tf`) also passes `defined_tags` to both logging resources.
- **Root cause**: Logging resources were written without `defined_tags` when the sprint 15 mount_target stack was originally implemented, inconsistent with the tag pattern applied everywhere else.
- **Fix**: Added `defined_tags = {}` to both `oci_logging_log_group.mount_target` and `oci_logging_log.mount_target` in `mount_target/main.tf`.
- **Verification**: `terraform validate` — Success.

**Resolution:** Fixed 2026-04-29.

## BUG-4: mount_address coalesce fails — OCI list API does not return ip_address on mount target

**Item:** PBI-028
**Severity:** critical
**Status:** fixed

- **Symptom**: `Call to function "coalesce" failed: no non-null, non-empty-string arguments` at `local.mount_address` in `filesystem_export/main.tf`. `local.mount_target_fqdn` is null (no hostname label configured) and `local.selected_mount_target.ip_address` is `""`.
- **Root cause**: `oci_file_storage_mount_targets` (plural/list) data source calls OCI's `ListMountTargets` API which returns `MountTargetSummary` objects. Those do not include `ip_address` — that field is only returned by `GetMountTarget` (the singular resource API). The OCI Terraform provider has no singular `oci_file_storage_mount_target` data source.
- **Fix**: Add `data "oci_core_private_ip" "mount_target"` using `local.selected_mount_target.private_ip_ids[0]` (which IS returned by the list API) to resolve the IP address. Use `data.oci_core_private_ip.mount_target.ip_address` in `local.mount_address` instead of `local.selected_mount_target.ip_address`.
- **Verification**: `terraform validate` passes. Runtime: `coalesce` receives a non-empty IP from `oci_core_private_ip` data source.

**Resolution:** Fixed 2026-04-29.

## BUG-3: Sprint 15 stacks implemented with direct resources instead of Sprint 13 module architecture

**Item:** PBI-026, PBI-028
**Severity:** high
**Status:** fixed

- **Symptom**: `mount_target/main.tf` and `filesystem_export/main.tf` created OCI resources directly (`oci_file_storage_mount_target`, `oci_file_storage_file_system`, `oci_file_storage_export`) with no embedded child modules. Sprint 13 (`fss_stack_sprint13_orm`) delegates to `modules/fss_stack_sprint12/` which itself uses `modules/fss_mount_target/`, `modules/fss_filesystem/`, `modules/fss_export/`. Sprint 15 must follow the same pattern.
- **Root cause**: Implementation used a "flat/inline" approach chosen for simplicity rather than the established Sprint 13 module-based architecture.
- **Fix**: Embed Sprint 12 sub-modules in each Sprint 15 stack root:
  - `mount_target/modules/fss_mount_target/` — wraps `oci_file_storage_mount_target`
  - `filesystem_export/modules/fss_filesystem/` — wraps `oci_file_storage_file_system`
  - `filesystem_export/modules/fss_export/` — wraps `oci_file_storage_export`
  Update stack root `main.tf` files to call the modules. Logging and tag/export slot orchestration remain at the root level (consistent with Sprint 12 stack pattern).
- **Verification**: `terraform validate` passes on both stacks. Zips regenerated: `fss-mount-target.zip` (11 files), `fss-filesystem-export.zip` (16 files). Log: `operator_manual_package_modules_20260429_210911.log`.

**Resolution:** Fixed 2026-04-29. Both stacks refactored to module-based architecture. `terraform validate` — Success on both roots.

## BUG-2: Quality gates never executed — sprint marked implemented prematurely

**Item:** PBI-026, PBI-028
**Severity:** high
**Status:** fixed

- **Symptom**: `sprint_15_tests.md` shows `Status: Pending` with no gate rows filled and no timestamped log files under `progress/sprint_15/`. PROGRESS_BOARD shows `implemented` and PLAN.md shows `Status: Progress`, but no A1 smoke or A3 integration gate has been run.
- **Root cause**: Sprint 15 was declared implemented without executing quality gates. Violates P1 (RUP_patch.md): a gate is only executed if a timestamped log exists.
- **Fix**: After BUG-1 is fixed, run quality gates in order: A1 smoke (`terraform validate` on both stacks), then A3 integration (ORM stack upload or `terraform apply` with static mock inputs). Capture timestamped logs under `progress/sprint_15/` and update `sprint_15_tests.md`.
- **Verification**: `sprint_15_tests.md` contains PASS rows with log file references; `PROGRESS_BOARD.md` updated to `tested`.

**Resolution:** Fixed 2026-04-30. A1 PASS (`test_run_A1_smoke_20260430_095647.log`), A3 PASS (`test_run_A3_integration_20260430_095710.log`), D1 PASS (`operator_manual_integration_20260430_074500.log`).
