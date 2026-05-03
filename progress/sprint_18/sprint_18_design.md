# Sprint 18 - Design

## PBI-033. Stable release pointers for terraform/packages

Status: Accepted

Stable release name: N/A (this sprint introduces the release pointer mechanism itself)

### Design

Create `terraform/packages/` as the operator-facing release directory containing stable symlinks:

```
terraform/packages/
  fss_stack             -> ../modules/fss_stack_sprint17
  fss_stack_orm         -> ../modules/fss_stack_sprint13_orm
  fss_stack_orm_advanced-> ../modules/fss_stack_sprint16_orm_advanced
```

Each symlink resolves to a self-contained sprint module. Terraform follows symlinks natively — `terraform -chdir=terraform/packages/fss_stack validate/plan/apply` works identically to using the sprint-suffixed path.

`PROJECT_RULES.md` gains two rules:

**R1 — Module Release Rule:** At Phase 5, Documentor MUST create or update a `terraform/packages/<stable_name>` symlink pointing to the sprint's `terraform/modules/<product>_sprint<N>/` directory.

**R2 — Stable Release Name field:** Every `sprint_N_design.md` delivering a Terraform module MUST include `Stable release name: <name>` before Phase 3.

### Testing Strategy

Test: smoke — static validation only; no OCI resources provisioned.

Smoke tests verify:
- SM-1: Each symlink in `terraform/packages/` exists and resolves to the correct sprint directory.
- SM-2: `terraform validate` passes through each stable name.
- SM-3: `PROJECT_RULES.md` contains R1 and R2 entries.

## Test Specification

Sprint Test Configuration:
- Test: smoke
- Mode: YOLO

### Smoke Tests

#### SM-1: Symlink targets correct sprint directories

- **What it verifies:** Each symlink in `terraform/packages/` resolves to the expected `terraform/modules/` directory.
- **Pass criteria:** `readlink` output matches expected target for all three symlinks.
- **Target file:** `tests/smoke/test_pbi033_stable_packages.sh`

#### SM-2: terraform validate passes through stable names

- **What it verifies:** Terraform accepts each stable package path as a valid module root.
- **Pass criteria:** `terraform validate` exits 0 for `fss_stack`, `fss_stack_orm`, `fss_stack_orm_advanced`.
- **Target file:** `tests/smoke/test_pbi033_stable_packages.sh`

#### SM-3: PROJECT_RULES.md contains R1 and R2

- **What it verifies:** The release rule and stable name field rule are codified.
- **Pass criteria:** `grep` finds R1 and R2 headings in `PROJECT_RULES.md`.
- **Target file:** `tests/smoke/test_pbi033_stable_packages.sh`

### Traceability

| Backlog Item | Smoke |
|---|---|
| PBI-033 | SM-1, SM-2, SM-3 |
