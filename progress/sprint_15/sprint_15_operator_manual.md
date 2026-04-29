# Sprint 15 - Operator Manual

Status: Draft

## Purpose

Sprint 15 provides two OCI Resource Manager stack roots:

- `terraform/modules/fss_stack_sprint15_orm_advanced/mount_target/`
- `terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export/`

Use the mount target stack first, then use the filesystem/export stack to create a filesystem with one or more exports against that mount target.

## Upload Order

1. Upload `mount_target/` as a Resource Manager stack.
2. Apply it and record `mount_target_ocid`.
3. Upload `filesystem_export/` as a Resource Manager stack.
4. Select the mount target in the Resource Manager form.
5. Enable optional exports with the chained `Add another export` checkboxes.
6. Apply and read `nfs_mount_sources`.
7. Destroy `filesystem_export/`, then destroy `mount_target/`.

## CLI Packaging Pattern

Run from the repository root:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
PACKAGE_OUT="${REPO_ROOT}/progress/sprint_15/generated_tf/manual"
mkdir -p "${PACKAGE_OUT}"

pushd "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/mount_target"
zip -qr "${PACKAGE_OUT}/fss-mount-target.zip" .
popd

pushd "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export"
zip -qr "${PACKAGE_OUT}/fss-filesystem-export.zip" .
popd
```

Evidence: package snippet executed successfully from a module subdirectory in `progress/sprint_15/operator_manual_package_git_root_20260429_173629.log`.

Sprint 15 quality gates execute the Resource Manager apply/destroy paths with sprint-scoped artifacts under `progress/sprint_15/generated_tf/`.
