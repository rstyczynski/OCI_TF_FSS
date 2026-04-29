# Sprint 11 - Operator Manual

Status: Complete

## Minimal v2 Stack

Use `terraform/modules/fss_v2_stack` when the operator wants the stack to derive the availability domain and use Oracle-managed filesystem encryption.

The generated Terraform examples in `progress/sprint_11/generated_tf/` are the executable reference for this sprint.

## Validate Minimal Example

```bash
cd progress/sprint_11/generated_tf/it1_minimal_validate
terraform init
terraform validate
```

## Apply Full Example

```bash
cd progress/sprint_11/generated_tf/it2_full_apply
terraform init
terraform apply
terraform output -json filesystems
terraform output -json mount_targets
terraform output -json nfs_mount_sources
```

## Teardown

```bash
cd progress/sprint_11/generated_tf/it2_full_apply
terraform destroy
```

## Evidence

- Minimal validation and full apply/teardown were executed by `tests/integration/test_fss_sprint11_v2.sh`.
- Passing log: `progress/sprint_11/test_run_A3_integration_final_20260429_075510.log`.
