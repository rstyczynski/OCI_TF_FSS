# Sprint 19 — Documentation

## Summary

Sprint 19 definitively answered whether OCI FSS export paths scope clients to filesystem subtrees: **they do not**. Both `/vol1` and `/vol2` expose the same filesystem root. This was verified by a live integration experiment on the Sprint 1 foundation infrastructure.

A `multi_exports_one_fs` example was added to `terraform/modules/fss_stack_sprint17/examples/` documenting the confirmed behavior with explicit guidance on when this topology is and is not appropriate.

## Experiment finding

**SAME-ROOT**: OCI FSS export `path` is an NFS mount alias, not a subtree scope. A file written via one export path is immediately visible via all other export paths pointing to the same filesystem.

**Implication for PV migration (Sprint 14):** The existing `1-PV → 1-FS` converter design is correct for data isolation. A `1-FS / N-exports` topology would share data across all PV paths — not the intended migration behavior.

## What was delivered

- `terraform/modules/fss_stack_sprint17/examples/multi_exports_one_fs/` — new example with SAME-ROOT behavior documented
- `tests/smoke/test_pbi035_multi_exports.sh` — smoke test
- `tests/integration/test_fss_export_subdir_experiment.sh` — integration experiment

## Release pointer

This sprint adds an example to the existing `fss_stack_sprint17` module. The stable package `terraform/packages/fss_stack` already points to that module — no symlink update needed.

## Quality gates

| Gate | Result | Evidence |
|---|---|---|
| A1 Smoke | PASS | `progress/sprint_19/test_run_A1_smoke_20260504_141758.log` |
| A3 Integration | PASS | `progress/sprint_19/test_run_A3_integration_20260504_141912.log` |
| D1 Operator Manual | PASS | `progress/sprint_19/operator_manual_validate_20260504_142211.log` |

## Sprint documents

- Setup: `progress/sprint_19/sprint_19_setup.md`
- Design: `progress/sprint_19/sprint_19_design.md`
- Implementation: `progress/sprint_19/sprint_19_implementation.md`
- Tests: `progress/sprint_19/sprint_19_tests.md`
- Operator manual: `progress/sprint_19/sprint_19_operator_manual.md`

## Backlog traceability

- PBI-035: `progress/backlog/PBI-035/`
