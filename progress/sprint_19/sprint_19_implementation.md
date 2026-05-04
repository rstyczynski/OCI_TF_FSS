# Sprint 19 - Implementation Notes

## PBI-035. OCI FSS export path scoping experiment and multi_exports_one_fs example

Status: Implemented

### Experiment result

**SAME-ROOT**: OCI FSS exposes the same filesystem root at both `/vol1` and `/vol2`. A sentinel file written via the `/vol1` mount was immediately visible via the `/vol2` mount. The export path is an NFS alias for the filesystem root — OCI FSS does NOT scope each export to a distinct subtree.

This means the `1-MT / 1-FS / N-exports` topology shares data across all export paths. It cannot substitute for per-PV isolated filesystems in a migration context.

### What was created

**`terraform/modules/fss_stack_sprint17/examples/multi_exports_one_fs/`**

- `main.tf` — provisions 1 mount target + 1 filesystem + 2 exports (`/vol1`, `/vol2`). Documents the SAME-ROOT behavior in comments with explicit guidance on when to use and when NOT to use this topology.
- `variables.tf` — `compartment_ocid`, `subnet_ocid`.

The example is reachable via the stable package path: `terraform/packages/fss_stack/examples/multi_exports_one_fs/`.

### Test artifacts

Integration experiment workdir: `progress/sprint_19/generated_tf/fss_subdir_experiment/`
- `tf_test_artifacts/apply.log` — Terraform apply output showing 6 resources created
- `tf_test_artifacts/mount.log` — both `/vol1` and `/vol2` mounted (MOUNTS OK)
- `tf_test_artifacts/write.log` — sentinel file written via `/vol1`
- `tf_test_artifacts/result.txt` — contains `YES` (visible via `/vol2`)
- `tf_test_artifacts/destroy.log` — all 6 resources destroyed

### YOLO decisions

None required. Scope was clear, result was unambiguous.
