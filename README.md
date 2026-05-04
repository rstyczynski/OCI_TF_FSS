# OCI TF FSS

Terraform components to create and manage OCI File Storage Service.

## Usage

Start with the executable examples:

- `terraform/modules/fss_stack_sprint12/examples/basic_fss/` provisions one mount target, one filesystem, and one export with only `compartment_ocid` and `subnet_ocid`.
- `terraform/modules/fss_stack_sprint12/examples/multi_fss_with_logging/` shows multiple mount targets, multiple filesystems, multiple exports, and mount target logging.

The Sprint 12 product root is `terraform/modules/fss_stack_sprint12/`. Its reusable lower-level wrappers live under `terraform/modules/fss_stack_sprint12/modules/`.

## Legacy PV Report Conversion

Use `tools/convert_pv_report_to_fss_tfvars.py` to convert legacy Kubernetes/NFS PV reports into `fss_stack_sprint12` variables.

Prerequisite: run from the repository root with Python 3 available.

```bash
tools/convert_pv_report_to_fss_tfvars.py \
  etc/pv-template1-details \
  -o progress/sprint_14/generated_tf/template1.auto.tfvars
```

The generated file contains `mount_targets` and `filesystems` maps. Each distinct legacy `server` becomes one mount target, and each PV becomes one filesystem with one `primary` export that preserves the legacy `path`.

## Recent Updates

### Sprint 1 - Foundation infrastructure for system-level tests

**Status:** implemented

**Backlog Items Implemented:**

- **PBI-005**: Foundation infrastructure for system-level FSS tests - tested

**Key Features Added:**

- Integration test that provisions a public SSH-accessible test client baseline in `/oci_tf_fss` using `oci_scaffold`
- `tools/go_remote.sh` — SSH to the foundation compute using scaffold state (see `progress/sprint_1/sprint_1_operator_manual.md`)
- Quality gates with committed, timestamped test logs

**Documentation:**

- Setup: `progress/sprint_1/sprint_1_setup.md`
- Design: `progress/sprint_1/sprint_1_design.md`
- Implementation: `progress/sprint_1/sprint_1_implementation.md`
- Tests: `progress/sprint_1/sprint_1_tests.md`
- Operator manual (`infra_setup`, `go_remote`, teardown): `progress/sprint_1/sprint_1_operator_manual.md`

### Sprint 2 - FSS filesystem module + Terraform rules

**Status:** implemented

**Backlog Items Implemented:**

- **PBI-001**: Terraform module for FSS filesystem - tested
- **PBI-006**: Terraform architecture rules for agentic development - tested

**Key Features Added:**

- Terraform module `terraform/modules/fss_sprint2/` with minimal interface and stable outputs
- Integration test that applies the module in `/oci_tf_fss` and asserts the filesystem OCID output

**Documentation:**

- Setup: `progress/sprint_2/sprint_2_setup.md`
- Design: `progress/sprint_2/sprint_2_design.md`
- Implementation: `progress/sprint_2/sprint_2_implementation.md`
- Tests: `progress/sprint_2/sprint_2_tests.md`

### Sprint 3 - Simplified FSS filesystem module

**Status:** tested

**Backlog Items Implemented:**

- **PBI-001**: Terraform module for FSS filesystem - tested
- **PBI-006**: Terraform architecture rules for agentic development - tested

**Key Features Added:**

- Terraform module `terraform/modules/fss_sprint3/` with explicit `compartment_ocid`, `availability_domain`, and `display_name` inputs
- Lifecycle handling scoped to Oracle-managed `defined_tags` keys: `Oracle-Tags.CreatedBy` and `Oracle-Tags.CreatedOn`
- Terraform architecture rules that move AD randomization, dynamic tag recognition, and `name_prefix` naming into experimental patterns

**Documentation:**

- Setup: `progress/sprint_3/sprint_3_setup.md`
- Design: `progress/sprint_3/sprint_3_design.md`
- Implementation: `progress/sprint_3/sprint_3_implementation.md`
- Tests: `progress/sprint_3/sprint_3_tests.md`
- Operator manual: `progress/sprint_3/sprint_3_operator_manual.md`
- Terraform rules: `progress/sprint_3/sprint_3_tf_rules.md`

### Sprint 4 - FSS mount target, export, and NPA

**Status:** tested

**Backlog Items Implemented:**

- **PBI-002**: Terraform module for FSS mount target - tested
- **PBI-003**: Terraform module for FSS export - tested
- **PBI-004**: Network Path Analyzer test for FSS availability - tested

**Key Features Added:**

- `terraform/modules/fss_sprint4_mount_target/` — mount target with `subnet_ocid`, optional `hostname_label` and `nsg_ids`; exposes `mount_target_mount_address` (FQDN or IP fallback)
- `terraform/modules/fss_sprint4_export/` — export linking a filesystem to a mount target export set with configurable NFS options
- Network Path Analyzer integration test via `oci_scaffold`

**Documentation:**

- Design: `progress/sprint_4/sprint_4_design.md`
- Implementation: `progress/sprint_4/sprint_4_implementation.md`
- Tests: `progress/sprint_4/sprint_4_tests.md`
- Terraform rules: `progress/sprint_4/sprint_4_tf_rules.md`

### Sprint 5 - FSS extended configuration and stack module

**Status:** tested

**Backlog Items Implemented:**

- **PBI-007**: FSS module with mandatory KMS key - tested
- **PBI-008**: Full optional filesystem argument surface - tested
- **PBI-009**: Higher-level stack module for multiple FSS entries from a map - tested

**Key Features Added:**

- `terraform/modules/fss_sprint5_filesystem/` — filesystem with mandatory `kms_key_id` and full optional argument surface
- `terraform/modules/fss_sprint5_stack/` — composition module: one map input creates N filesystems, mount targets, and exports with `nfs_mount_sources` output
- IAM dynamic group and KMS-use policy automation for customer-managed encryption keys

**Documentation:**

- Design: `progress/sprint_5/sprint_5_design.md`
- Implementation: `progress/sprint_5/sprint_5_implementation.md`
- Tests: `progress/sprint_5/sprint_5_tests.md`
- Terraform rules: `progress/sprint_5/sprint_5_tf_rules.md`

### Sprint 6 - FSS mount and administration

**Status:** tested

**Backlog Items Implemented:**

- **PBI-010**: Mount FSS exports on a compute instance - tested
- **PBI-011**: Administrator tasks on mounted FSS exports - tested

**Key Features Added:**

- Automated NFS client install, mount directory creation, and export mounting on the foundation compute instance
- Administrator task validation: directory creation, ownership/permission changes, file operations, remount, and cleanup

**Documentation:**

- Design: `progress/sprint_6/sprint_6_design.md`
- Implementation: `progress/sprint_6/sprint_6_implementation.md`
- Tests: `progress/sprint_6/sprint_6_tests.md`
- Operator manual: `progress/sprint_6/sprint_6_operator_manual.md`

### Sprint 7 - FSS stack variable refactor

**Status:** tested

**Backlog Items Implemented:**

- **PBI-019**: Refactor stack filesystem variable — supersedes PBI-015 - tested

**Key Features Added:**

- `terraform/modules/fss_sprint7_stack/` — decoupled `mount_targets` and `filesystems` map inputs; each filesystem carries a nested `exports` map with `mount_target_key` references; true M:N topology supported
- `identity_squash` output added to `fss_sprint4_export` (additive, backward compatible)
- Composite `filesystems` output includes per-export `identity_squash` read from the OCI-applied value
- `nfs_mount_sources` keyed by stable composite key `fs__export`

**Documentation:**

- Setup: `progress/sprint_7/sprint_7_setup.md`
- Design: `progress/sprint_7/sprint_7_design.md`
- Implementation: `progress/sprint_7/sprint_7_implementation.md`
- Tests: `progress/sprint_7/sprint_7_tests.md`
- Documentation: `progress/sprint_7/sprint_7_documentation.md`

### Sprint 12 - FSS stack examples and modules layout

**Status:** tested

**Backlog Items Implemented:**

- **PBI-024**: Repackage FSS stack with examples and modules layout - tested

**Key Features Added:**

- `terraform/modules/fss_stack_sprint12/` — operator-facing package: stack root, lower-level modules under `modules/`, and two executable examples under `examples/`
- `examples/basic_fss/` — minimal example requiring only `compartment_ocid` and `subnet_ocid`; AD derived automatically; Oracle-managed encryption by default
- `examples/multi_fss_with_logging/` — full example with two mount targets, two filesystems, three exports, OCI Logging, and mixed `identity_squash` policies

**Documentation:**

- Setup: `progress/sprint_12/sprint_12_setup.md`
- Design: `progress/sprint_12/sprint_12_design.md`
- Implementation: `progress/sprint_12/sprint_12_implementation.md`
- Tests: `progress/sprint_12/sprint_12_tests.md`
- Operator manual: `progress/sprint_12/sprint_12_operator_manual.md`

### Sprint 19 - OCI FSS export path scoping experiment

**Status:** tested

**Backlog Items Implemented:**

- **PBI-035**: OCI FSS export path scoping experiment and multi_exports_one_fs example - tested

**Key Findings:**

- OCI FSS export `path` is an NFS alias for the filesystem root — **not** a subtree scope
- A file written via one export path is immediately visible via all other export paths on the same filesystem (SAME-ROOT, verified on live OCI)
- The `1-MT / 1-FS / N-exports` topology shares data across all paths; use separate filesystems for data isolation

**Key Features Added:**

- `terraform/packages/fss_stack/examples/multi_exports_one_fs/` — example demonstrating 1 mount target, 1 filesystem, 2 export paths, with documented SAME-ROOT behavior

**Documentation:**

- Setup: `progress/sprint_19/sprint_19_setup.md`
- Design: `progress/sprint_19/sprint_19_design.md`
- Implementation: `progress/sprint_19/sprint_19_implementation.md`
- Tests: `progress/sprint_19/sprint_19_tests.md`
- Operator manual: `progress/sprint_19/sprint_19_operator_manual.md`
- Documentation: `progress/sprint_19/sprint_19_documentation.md`

### Sprint 18 - Stable release pointers for terraform/packages

**Status:** tested

**Backlog Items Implemented:**

- **PBI-033**: Stable release pointers for terraform/packages - tested

**Key Features Added:**

- `terraform/packages/` — stable operator-facing release directory; symlinks point from stable names into versioned sprint directories in `terraform/modules/`
- `terraform/packages/fss_stack` → `fss_stack_sprint17`
- `terraform/packages/fss_stack_orm` → `fss_stack_sprint13_orm`
- `terraform/packages/fss_stack_orm_advanced` → `fss_stack_sprint16_orm_advanced`
- `PROJECT_RULES.md` R1 (Module Release Rule) and R2 (Stable Release Name field) enforce this pattern for all future sprints

**Documentation:**

- Setup: `progress/sprint_18/sprint_18_setup.md`
- Design: `progress/sprint_18/sprint_18_design.md`
- Implementation: `progress/sprint_18/sprint_18_implementation.md`
- Tests: `progress/sprint_18/sprint_18_tests.md`
- Operator manual: `progress/sprint_18/sprint_18_operator_manual.md`
- Documentation: `progress/sprint_18/sprint_18_documentation.md`

### Sprint 17 - Externally managed mount targets and per-mount-target placement overrides

**Status:** tested

**Backlog Items Implemented:**

- **PBI-031**: fss_stack_sprint12 — support externally managed mount targets in exports - tested
- **PBI-032**: fss stack — allow per-mount-target placement overrides (subnet / availability domain) - tested

**Key Features Added:**

- `terraform/modules/fss_stack_sprint17/` — extends the Sprint 12 stack with `mount_targets[*].external_ocid` (reference an existing mount target by OCID instead of creating one), `mount_targets[*].subnet_ocid`, and `mount_targets[*].availability_domain` (per-entry placement overrides)
- Exports continue to reference mount targets by key (`mount_target_key`) regardless of whether the target is managed or external
- Input validation for `external_ocid` format and placement consistency
- BUG-12 fix: reuses an existing OCI Logging log group by display name to avoid 409-Conflict on repeated applies; mirrored into Sprint 16 vendored copies

**Documentation:**

- Setup: `progress/sprint_17/sprint_17_setup.md`
- Design: `progress/sprint_17/sprint_17_design.md`
- Implementation: `progress/sprint_17/sprint_17_implementation.md`
- Tests: `progress/sprint_17/sprint_17_tests.md`
- Operator manual: `progress/sprint_17/sprint_17_operator_manual.md`
- Documentation: `progress/sprint_17/sprint_17_documentation.md`
