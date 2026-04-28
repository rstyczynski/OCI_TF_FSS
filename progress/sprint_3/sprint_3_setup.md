# Sprint 3 - Setup

## Contract

### Sprint context

- Sprint: 3 - simplify sprint 2 product
- Status: Progress
- Mode: managed
- Test: integration
- Regression: integration
- Backlog Items:
  - PBI-001. Terraform module for FSS filesystem
  - PBI-006. Terraform architecture rules for agentic development

### Rules and procedures acknowledged

- Root instructions: `AGENTS.md`
- Local clarifications: `RUP_patch.md`
- RUP rules: `RUPStrikesBack/rules/generic/`
- Manager procedure: `RUPStrikesBack/.claude/commands/rup-manager.md`
- Sprint 2 Terraform rules baseline: `progress/sprint_2/sprint_2_tf_rules.md`

### Implementor responsibilities

- Preserve existing Sprint 2 rename work in the dirty worktree.
- Implement only Sprint 3 scope after design approval.
- Do not modify Product Owner-owned status tokens except allowed progress-board tracking.
- Produce timestamped log artifacts for any executed gate.
- In managed mode, stop after design until Product Owner accepts it; stop again after construction until Product Owner accepts running quality gates.

### Open questions

- None for setup.

## Analysis

### PBI-001. Terraform module for FSS filesystem

- **Requirement summary:** Produce a simplified Sprint 3 filesystem module at `terraform/modules/fss_sprint3`.
- **Sprint 3 simplification goals:** remove AD randomization, remove `name_prefix`, remove dynamic tag recognition/merge logic, and use Terraform lifecycle handling for Oracle-managed defined tags.
- **Dependencies:** Sprint 2 module behavior and tests provide the baseline; Sprint 3 must diverge deliberately toward a smaller interface.
- **Testing:** Integration tests should apply the module in `/oci_tf_fss`, assert `filesystem_ocid`, verify required arguments fail fast, and verify no persistent drift from Oracle-managed tags after lifecycle ignore behavior.
- **Risk:** Ignoring all `defined_tags` changes can also ignore user-defined tag drift if exposed as a module input. The design should avoid a `defined_tags` input unless explicitly needed.

### PBI-006. Terraform architecture rules for agentic development

- **Requirement summary:** Update Terraform rules so AD randomization, dynamic tag recognition, and `name_prefix` become experimental patterns only used on clear request.
- **Dependencies:** `progress/sprint_2/sprint_2_tf_rules.md`
- **Testing:** Documentation/process artifact can be verified by reviewing `progress/sprint_3/sprint_3_tf_rules.md` and referencing it from Sprint 3 design.

### Overall sprint assessment

- **Feasibility:** High. OCI Terraform provider supports direct FSS filesystem creation with explicit `availability_domain`, `compartment_ocid`, and `display_name`.
- **Estimated complexity:** Moderate. The module is simpler than Sprint 2, but tests must avoid false positives from OCI-managed tag behavior.
- **Prerequisites met:** Yes. Sprint 1 foundation state exists and Sprint 2 integration harness patterns are available.
- **Readiness for design:** Confirmed ready.
