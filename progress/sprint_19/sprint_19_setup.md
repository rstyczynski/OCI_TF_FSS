# Sprint 19 - Setup

## Contract Review

Rules reviewed: `RUPStrikesBack/rules/generic/`, `RUP_patch.md`, `PROJECT_RULES.md`.

Sprint 19 is YOLO mode. All decisions logged here.

## Analysis

### PBI-035. OCI FSS export path scoping experiment and multi_exports_one_fs example

**Question:** When a single OCI FSS filesystem has two exports with different paths (`/vol1`, `/vol2`), does each NFS client see the same filesystem root, or a distinct subtree?

**Approach:** Empirical integration test against the Sprint 1 foundation (compartment, subnet, foundation compute with SSH access via OCI Vault secret). Apply 1 MT + 1 FS + 2 exports, mount both on the foundation compute, write a sentinel file via one mount, verify via the other.

**Foundation dependency:** `progress/sprint_1/scaffold/infra/state-infra.json` — provides `compartment.ocid`, `subnet.ocid`, `subnet.cidr_block`, `compute.public_ip`, `secret.ocid`.

**Product:** `terraform/modules/fss_stack_sprint17/examples/multi_exports_one_fs/` — added to the canonical stack module and reachable via `terraform/packages/fss_stack`.

**Compatibility:** Additive only. No existing examples or module code touched.

YOLO decisions: none required — scope is clear and foundation is in place.
