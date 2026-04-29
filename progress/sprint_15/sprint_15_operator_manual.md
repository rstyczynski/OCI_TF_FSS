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

The integration test uses the same packaging pattern:

```bash
cd terraform/modules/fss_stack_sprint15_orm_advanced/mount_target
zip -qr /tmp/fss-mount-target.zip .
```

```bash
cd terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export
zip -qr /tmp/fss-filesystem-export.zip .
```

These snippets are intentionally descriptive. Sprint 15 quality gates execute the packaging and Resource Manager apply/destroy paths with sprint-scoped artifacts under `progress/sprint_15/generated_tf/`.
