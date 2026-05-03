# Sprint 18 — Operator Manual

This manual covers the `terraform/packages/` stable release directory introduced in Sprint 18.

## Prerequisites

- Terraform >= 1.5
- OCI Terraform provider prerequisites configured (tenancy/user/region/auth)
- Repository cloned locally

## Quick validate (no OCI credentials required)

Confirm each stable package name is syntactically valid:

```bash
terraform -chdir=terraform/packages/fss_stack validate
```

Evidence: `progress/sprint_18/operator_manual_validate_<TS>.log`

```bash
terraform -chdir=terraform/packages/fss_stack_orm validate
```

```bash
terraform -chdir=terraform/packages/fss_stack_orm_advanced validate
```

## Check current release pointers

```bash
ls -la terraform/packages/
```

Expected output:

```
fss_stack             -> ../modules/fss_stack_sprint17
fss_stack_orm         -> ../modules/fss_stack_sprint13_orm
fss_stack_orm_advanced-> ../modules/fss_stack_sprint16_orm_advanced
```

## Using a stable package as a module source

```hcl
module "fss" {
  source = "../../terraform/packages/fss_stack"

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid
}
```

## Updating a release pointer (Documentor, Phase 5)

When a new sprint delivers an updated stack (e.g. Sprint 19 produces `fss_stack_sprint19`):

```bash
cd terraform/packages
ln -sfn ../modules/fss_stack_sprint19 fss_stack
ls -la fss_stack
terraform -chdir=fss_stack validate
```
