# Sprint 5 Generated Terraform

Sprint 5 integration tests generate executable Terraform root modules under this directory:

- `it1_missing_kms_key/main.tf`
- `it2_filesystem_kms_optional/main.tf`
- `it3_stack_multi_entry/main.tf`

The generated `main.tf` files are kept for operator review. Runtime byproducts such as `.terraform/`, state files, lock files, and binary plans are ignored.
