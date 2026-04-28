# Sprint 8 - Setup

## Contract

- Rules read from `AGENTS.md`, `RUP_patch.md`, and `RUPStrikesBack/rules/generic/`.
- Sprint is managed, so construction must wait for design approval.
- Quality evidence must be timestamped under `progress/sprint_8/`.
- Operator manual is mandatory and runnable snippets need evidence when executed.
- Existing local change in `terraform/modules/fss_sprint7_stack/outputs.tf` is preserved and treated as user-owned unless Sprint 8 must integrate with it.

## Analysis

### PBI-016. Add logging to mount targets

Status: analysed

OCI Logging supports File Storage service logs. Local OCI CLI discovery returned service id `filestorage`, resource type `mounttarget`, and category `nfslogs`. Terraform provider schema confirms `oci_logging_log_group` and `oci_logging_log` resources and requires service logs to use `configuration.source` with `source_type = "OCISERVICE"`.

The current product baseline is Sprint 7 stack at `terraform/modules/fss_sprint7_stack`, because Sprint 7 replaced the Sprint 5 flat stack with first-class mount targets and nested filesystem exports. Sprint 8 should create a new module version rather than mutate the Sprint 7 baseline, keeping sprint products stable.

### Feasibility

Feasible. The stack can optionally create a log group and one service log per mount target with logging enabled. Integration tests can apply a mount target with logging enabled, verify the log resource via Terraform outputs and `oci logging log get`, then query `oci logging-search search-logs` after a generated NFS mount/write operation.

### Open risks

- OCI service logs may not emit immediately. Tests should verify log configuration deterministically and treat log event search as bounded with retries.
- The exact log event payload is service-owned, so tests should assert discoverability and at least one returned event when available, while recording raw OCI CLI output for operator review.
