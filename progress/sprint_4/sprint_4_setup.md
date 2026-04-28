# Sprint 4 - Setup

## Contract

### Sprint context

- Sprint: 4 - FSS mount target module
- Status: Progress
- Mode: managed
- Test: integration
- Regression: integration
- Backlog Items:
  - PBI-002. Terraform module for FSS mount target
  - PBI-003. Terraform module for FSS export
  - PBI-004. Network Path Analyzer test for FSS availability

### Rules and procedures acknowledged

- Root instructions: `AGENTS.md`
- Local clarifications: `RUP_patch.md`
- RUP rules: `RUPStrikesBack/rules/generic/`
- Manager procedure: `RUPStrikesBack/.claude/commands/rup-manager.md`
- Terraform module rules: `progress/sprint_3/sprint_3_tf_rules.md`

### Implementor responsibilities

- Preserve unrelated local edits in the dirty worktree.
- Keep Sprint 4 scope limited to mount target, export, and availability validation.
- In managed mode, stop after design until Product Owner approval.
- After construction, stop again for Product Owner approval before quality gates.
- Produce timestamped quality-gate logs under `progress/sprint_4/` for any executed gate.

### Open questions

- None blocking setup. Module paths are specified in the design for review.

## Analysis

### PBI-002. Terraform module for FSS mount target

- **Requirement summary:** Create a reusable Terraform module that provisions an OCI FSS mount target in a caller-provided subnet and availability domain.
- **Dependencies:** Sprint 1 foundation provides a subnet for integration tests. Sprint 3 filesystem module provides a simple filesystem that can be exported through the mount target.
- **Testing:** Integration should apply the module in OCI and assert mount target OCID, export set OCID, and at least one private IP identifier.
- **Risk:** Mount targets consume multiple subnet IPs and must be in the same availability domain as the filesystem for association.

### PBI-003. Terraform module for FSS export

- **Requirement summary:** Create a reusable Terraform module that provisions an OCI FSS export connecting a filesystem to a mount target export set at a caller-provided path.
- **Dependencies:** Requires a filesystem OCID and mount target export set OCID.
- **Testing:** Integration should create a filesystem, mount target, export, and assert export OCID/path outputs.
- **Risk:** Export options determine client visibility. The default must be explicit and suitable for the foundation subnet.

### PBI-004. Network Path Analyzer test for FSS availability

- **Requirement summary:** Add an availability validation that uses the existing `oci_scaffold` path analyzer helper because Terraform is not available for this validation.
- **Dependencies:** Requires foundation state and the mount target private IP created by Terraform.
- **Testing:** Integration should run path analyzer from the foundation subnet toward the mount target private IP on TCP/2049 and record a reachable or clearly classified result.
- **Risk:** Network Path Analyzer can be unavailable due to permissions or service behavior. If unavailable, the test must fail with a clear reason rather than silently pass.

### Overall sprint assessment

- **Feasibility:** High. OCI Terraform provider supports mount target and export resources. `oci_scaffold/resource/ensure-path_analyzer.sh` already wraps `oci vn-monitoring path-analysis get-path-analysis-adhoc`.
- **Estimated complexity:** Moderate. The main risk is wiring Terraform-created mount target IP output into the shell-based path analyzer while keeping generated Terraform test roots visible under `progress/sprint_4/generated_tf/` and oci_scaffold state under `progress/sprint_1/scaffold/`.
- **Prerequisites met:** Sprint 1 foundation and Sprint 3 filesystem module exist.
- **Readiness for design:** Confirmed ready.
