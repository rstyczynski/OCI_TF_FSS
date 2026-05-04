# Sprint 19 - Design

## PBI-035. OCI FSS export path scoping experiment and multi_exports_one_fs example

Status: Accepted

Stable release name: N/A — adds an example to the existing `fss_stack_sprint17` module; no new module created; `terraform/packages/fss_stack` symlink already points to it.

### Experiment design

Provision using `terraform/packages/fss_stack`:

```hcl
mount_targets = {
  primary = { display_name = "fss-subdir-exp-mt" }
}

filesystems = {
  shared = {
    display_name = "fss-subdir-exp-fs"
    exports = {
      vol1 = { mount_target_key = "primary", path = "/vol1", identity_squash = "NONE" }
      vol2 = { mount_target_key = "primary", path = "/vol2", identity_squash = "NONE" }
    }
  }
}
```

On the foundation compute:

1. Mount `<mt_addr>:/vol1` at `/mnt/vol1`
2. Mount `<mt_addr>:/vol2` at `/mnt/vol2`
3. Write `/mnt/vol1/sentinel.txt`
4. Check if `/mnt/vol2/sentinel.txt` exists

**Expected outcomes:**

| Result | Meaning |
|---|---|
| File visible via `/vol2` | Same filesystem root exposed at both paths — no subdirectory scoping |
| File NOT visible via `/vol2` | OCI FSS scopes each export to a distinct subtree |

### Example to add

`terraform/modules/fss_stack_sprint17/examples/multi_exports_one_fs/main.tf` — demonstrates 1 MT + 1 FS + 2 exports, documents the observed behavior in comments.

### Testing Strategy

Test: smoke, integration. Regression: none.

## Test Specification

Sprint Test Configuration:
- Test: smoke, integration
- Mode: YOLO

### Smoke Tests

#### SM-1: multi_exports_one_fs example passes terraform validate

- **What it verifies:** New example is syntactically valid
- **Pass criteria:** `terraform validate` exits 0
- **Target file:** `tests/smoke/test_pbi035_multi_exports.sh`

### Integration Tests

#### IT-1: OCI FSS export path scoping experiment

- **Preconditions:** Sprint 1 foundation state at `progress/sprint_1/scaffold/infra/state-infra.json`
- **Steps:** Apply stack → mount `/vol1` and `/vol2` → write sentinel → check → unmount → destroy
- **Expected Outcome:** Definitive SAME-ROOT or SCOPED result recorded in `artifacts_dir/result.txt`
- **Target file:** `tests/integration/test_fss_export_subdir_experiment.sh`

### Traceability

| Backlog Item | Smoke | Integration |
|---|---|---|
| PBI-035 | SM-1 | IT-1 |
