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

- Terraform module `terraform/modules/fss_sprint2/` with minimal interface and stable outputs
- Integration test that applies the module in `/oci_tf_fss` and asserts the filesystem OCID output

**Documentation:**

- Setup: `progress/sprint_2/sprint_2_setup.md`
- Design: `progress/sprint_2/sprint_2_design.md`
- Implementation: `progress/sprint_2/sprint_2_implementation.md`
- Tests: `progress/sprint_2/sprint_2_tests.md`

### Sprint 3 - Simplified FSS filesystem module

**Status:** tested

**Backlog Items Implemented:**

- **PBI-001**: Terraform module for FSS filesystem - tested
- **PBI-006**: Terraform architecture rules for agentic development - tested

**Key Features Added:**

- Terraform module `terraform/modules/fss_sprint3/` with explicit `compartment_ocid`, `availability_domain`, and `display_name` inputs
- Lifecycle handling scoped to Oracle-managed `defined_tags` keys: `Oracle-Tags.CreatedBy` and `Oracle-Tags.CreatedOn`
- Terraform architecture rules that move AD randomization, dynamic tag recognition, and `name_prefix` naming into experimental patterns

**Documentation:**

- Setup: `progress/sprint_3/sprint_3_setup.md`
- Design: `progress/sprint_3/sprint_3_design.md`
- Implementation: `progress/sprint_3/sprint_3_implementation.md`
- Tests: `progress/sprint_3/sprint_3_tests.md`
- Operator manual: `progress/sprint_3/sprint_3_operator_manual.md`
- Terraform rules: `progress/sprint_3/sprint_3_tf_rules.md`
