# Sprint 18 - Implementation Notes

## PBI-033. Stable release pointers for terraform/packages

Status: Implemented

### What was created

**`terraform/packages/` directory** with three stable symlinks:

| Stable name | Points to |
|---|---|
| `fss_stack` | `../modules/fss_stack_sprint17` |
| `fss_stack_orm` | `../modules/fss_stack_sprint13_orm` |
| `fss_stack_orm_advanced` | `../modules/fss_stack_sprint16_orm_advanced` |

**`PROJECT_RULES.md`** — two new rules added:

- R1 (Module Release Rule): Documentor MUST create/update `terraform/packages/<stable_name>` symlink at Phase 5 for every sprint delivering an operator-facing module.
- R2 (Stable Release Name field): Design doc MUST carry `Stable release name:` before Phase 3.

### Usage

Operators reference the stable name instead of the sprint-suffixed path:

```bash
# Instead of:
terraform -chdir=terraform/modules/fss_stack_sprint17 plan

# Operators use:
terraform -chdir=terraform/packages/fss_stack plan
```

In a Terraform root that consumes the stack as a module:

```hcl
module "fss" {
  source = "../../terraform/packages/fss_stack"

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid
}
```

### Commits

- `aff6abc` feat: (PBI-033) add stable module release pointers and project rules R1/R2
- `785c0ee` fix: (PBI-033) move stable release pointers to terraform/packages/
