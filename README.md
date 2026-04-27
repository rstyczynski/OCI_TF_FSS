# OCI TF FSS

Terraform components to create and manage OCI File Storage Service.

## Recent Updates

### Sprint 1 - Foundation infrastructure for system-level tests

**Status:** implemented

**Backlog Items Implemented:**

- **PBI-005**: Foundation infrastructure for system-level FSS tests - tested

**Key Features Added:**

- Integration test that provisions a public SSH-accessible test client baseline in `/oci_tf_fss` using `oci_scaffold`
- `tools/go_remote.sh` — SSH to the foundation compute using scaffold state (see `progress/sprint_1/sprint_1_operator_manual.md`)
- Quality gates with committed, timestamped test logs

**Documentation:**

- Setup: `progress/sprint_1/sprint_1_setup.md`
- Design: `progress/sprint_1/sprint_1_design.md`
- Implementation: `progress/sprint_1/sprint_1_implementation.md`
- Tests: `progress/sprint_1/sprint_1_tests.md`
- Operator manual (`infra_setup`, `go_remote`, teardown): `progress/sprint_1/sprint_1_operator_manual.md`

### Sprint 2 - FSS filesystem module + Terraform rules

**Status:** implemented

**Backlog Items Implemented:**

- **PBI-001**: Terraform module for FSS filesystem - tested
- **PBI-006**: Terraform architecture rules for agentic development - tested

**Key Features Added:**

- Terraform module `terraform/modules/fss_filesystem/` with minimal interface and stable outputs
- Integration test that applies the module in `/oci_tf_fss` and asserts the filesystem OCID output

**Documentation:**

- Setup: `progress/sprint_2/sprint_2_setup.md`
- Design: `progress/sprint_2/sprint_2_design.md`
- Implementation: `progress/sprint_2/sprint_2_implementation.md`
- Tests: `progress/sprint_2/sprint_2_tests.md`
  