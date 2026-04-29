# Sprint 15 — Bugs

## BUG-1: fss-filesystem-export.zip packaged from wrong directory

**Item:** PBI-028
**Severity:** critical
**Status:** open

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

## BUG-2: Quality gates never executed — sprint marked implemented prematurely

**Item:** PBI-026, PBI-028
**Severity:** high
**Status:** open

- **Symptom**: `sprint_15_tests.md` shows `Status: Pending` with no gate rows filled and no timestamped log files under `progress/sprint_15/`. PROGRESS_BOARD shows `implemented` and PLAN.md shows `Status: Progress`, but no A1 smoke or A3 integration gate has been run.
- **Root cause**: Sprint 15 was declared implemented without executing quality gates. Violates P1 (RUP_patch.md): a gate is only executed if a timestamped log exists.
- **Fix**: After BUG-1 is fixed, run quality gates in order: A1 smoke (`terraform validate` on both stacks), then A3 integration (ORM stack upload or `terraform apply` with static mock inputs). Capture timestamped logs under `progress/sprint_15/` and update `sprint_15_tests.md`.
- **Verification**: `sprint_15_tests.md` contains PASS rows with log file references; `PROGRESS_BOARD.md` updated to `tested`.
