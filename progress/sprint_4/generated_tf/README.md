# Sprint 4 Generated Terraform

Sprint 4 integration tests generate executable Terraform root modules under this directory:

- `it1_mount_target/main.tf`
- `it2_export/main.tf`
- `it3_path_analyzer/main.tf`

The generated `main.tf` files are intentionally kept outside `progress/sprint_4/tf_state/` so operators can review the exact Terraform code used by the tests. Runtime files such as `.terraform/`, `terraform.tfstate`, binary plans, lock files, and `tf_test_artifacts/` are ignored.
