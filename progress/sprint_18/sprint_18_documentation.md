# Sprint 18 — Documentation

## Summary

Sprint 18 introduces `terraform/packages/` as the stable operator-facing release directory for Terraform modules. Three stable symlinks retroactively cover all current operator-facing products. Two project rules (R1, R2) encode the release pattern so future sprints apply it automatically.

## What was delivered

**`terraform/packages/`** — new release directory:

| Stable name | Points to | Operator use |
|---|---|---|
| `fss_stack` | `../modules/fss_stack_sprint17` | General FSS stack |
| `fss_stack_orm` | `../modules/fss_stack_sprint13_orm` | OCI Resource Manager basic |
| `fss_stack_orm_advanced` | `../modules/fss_stack_sprint16_orm_advanced` | OCI Resource Manager advanced |

**`PROJECT_RULES.md`** — two new rules:

- R1 (Module Release Rule): Documentor creates/updates `terraform/packages/<stable_name>` symlink at Phase 5.
- R2 (Stable Release Name field): Design doc carries `Stable release name:` before Phase 3.

## Quality gates

| Gate | Result | Evidence |
|---|---|---|
| A1 Smoke | PASS | `progress/sprint_18/test_run_A1_smoke_20260503_110859.log` |
| D1 Operator Manual | PASS | `progress/sprint_18/operator_manual_validate_20260503_110913.log` |

## Sprint documents

- Setup: `progress/sprint_18/sprint_18_setup.md`
- Design: `progress/sprint_18/sprint_18_design.md`
- Implementation: `progress/sprint_18/sprint_18_implementation.md`
- Tests: `progress/sprint_18/sprint_18_tests.md`
- Operator manual: `progress/sprint_18/sprint_18_operator_manual.md`

## Release pointer

This sprint introduces the release pointer mechanism itself; no single `Stable release name:` applies. Future sprints will record their stable name in the design doc per R2.

## Backlog traceability

- PBI-033: `progress/backlog/PBI-033/`
