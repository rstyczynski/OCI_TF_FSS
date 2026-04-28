# Sprint 4 Generated Terraform

Sprint 4 integration tests generate executable Terraform root modules under this directory:

- `it1_mount_target/main.tf`
- `it2_export/main.tf`
- `it3_path_analyzer/main.tf`

The generated `main.tf` files are intentionally kept outside `progress/sprint_4/tf_state/` so operators can review the exact Terraform code used by the tests. Runtime files such as `.terraform/`, `terraform.tfstate`, binary plans, lock files, and `tf_test_artifacts/` are ignored.

Operator mount endpoint outputs are available from the Sprint 4 mount target module:

- `mount_target_ip_address`
- `mount_target_fqdn`
- `mount_target_mount_address`

For a complete NFS mount source, combine the preferred mount address with the export path:

```text
<mount_target_mount_address>:<export_path>
```
