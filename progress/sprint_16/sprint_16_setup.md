# Sprint 16 - Setup

## Contract Review

Status: Accepted

Sprint 16 implements PBI-030, which fixes the critical BUG-11 identified at the end of Sprint 15. No ambiguities require clarification. All constraints are fully specified.

**Canonical source module (unmodifiable):** `terraform/modules/fss_stack_sprint12/`

**Defective modules to replace:**

- `mount_target/modules/fss_stack_sprint15_mount_target/` → replace with verbatim copy of `fss_stack_sprint12/`
- `filesystem_export/modules/fss_stack_sprint15_filesystem_export/` → replace with verbatim copy of `fss_stack_sprint12/`

**Rule (from Sprint 13 pattern):** the intermediate module embedded in an ORM stack zip MUST be `fss_stack_sprint12`, copied as-is, not a new sprint-specific module. This module is externally managed and must not be modified.

## Analysis

**Previous sprint state (Sprint 15 — Failed):**

- `mount_target/main.tf` calls `module "fss_stack" { source = "./modules/fss_stack_sprint15_mount_target" }` — WRONG
- `filesystem_export/main.tf` calls `module "fss_stack" { source = "./modules/fss_stack_sprint15_filesystem_export" }` — WRONG
- Both custom intermediate modules wrap `fss_mount_target`, `fss_filesystem`, `fss_export` sub-modules directly

**Sprint 13 reference (correct pattern):**

- `fss_stack_sprint13_orm/main.tf` calls `module "fss" { source = "./modules/fss_stack_sprint12" }`
- `fss_stack_sprint12/` is embedded verbatim under `modules/`
- `fss_stack_sprint12` itself calls `fss_mount_target`, `fss_filesystem`, `fss_export` sub-modules

**Sprint 16 target state:**

- `mount_target/modules/fss_stack_sprint12/` — verbatim copy of canonical `fss_stack_sprint12/`
- `filesystem_export/modules/fss_stack_sprint12/` — verbatim copy of canonical `fss_stack_sprint12/`
- `mount_target/main.tf` calls `module "fss_stack" { source = "./modules/fss_stack_sprint12" }` with `mount_targets` map (single entry) and `filesystems = {}`
- `filesystem_export/main.tf` calls `fss_filesystem` and `fss_export` sub-modules directly from within the embedded `fss_stack_sprint12/modules/` tree, because the filesystem_export stack operates against an existing mount target and cannot call the full `fss_stack_sprint12` (which always creates new mount targets)

**Compatibility with existing quality gates:**

Sprint 15 smoke (`test_fss_sprint15_orm_advanced.sh`) and integration (`test_fss_sprint15_orm_advanced.sh`) tests must pass without modification. The schema, variables, and outputs of both ORM roots are unchanged; only the module layer changes.
