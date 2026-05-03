# Project Rules — OCI TF FSS

This file contains rules specific to this repository. All agents MUST read and comply with these rules before starting any work.

These rules apply in addition to `RUPStrikesBack/rules/generic/` and `RUP_patch.md`.

## R1 — Module Release Rule

Sprints build Terraform products in `terraform/modules/<product>_sprint<N>/` as the versioned artifact. At Phase 5 (Documentor), every sprint that delivers an operator-facing Terraform module MUST create or update a stable symlink in `terraform/packages/` pointing to the sprint module directory (e.g. `terraform/packages/fss_stack -> ../modules/fss_stack_sprint18`). The stable name carries no sprint suffix and is the only path operators and regression tests may use; sprint-suffixed paths in `terraform/modules/` are reserved for sprint acceptance tests and historical audit.

Documentor release step:

```bash
cd terraform/packages
ln -sfn ../modules/fss_stack_sprint18 fss_stack
ls -la fss_stack
terraform -chdir=fss_stack validate
```

Record the symlink target in `sprint_N_documentation.md` under a "Release pointer" section and commit the symlink as part of the docs commit (git tracks symlinks natively).

## R2 — Stable Release Name field

Every `sprint_N_design.md` that delivers an operator-facing Terraform module MUST include a `Stable release name:` field before Phase 3 (Construction) begins. The Documentor uses this field at Phase 5 to create the R1 release symlink in `terraform/packages/`. Example:

```markdown
Stable release name: fss_stack
```
