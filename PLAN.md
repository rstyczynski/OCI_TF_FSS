# Development plan

## Sprint 1 - Initial setup

Status: Done
Mode: managed
Test: integration
Regression: integration

Keep all resources in /oci_tf_fss compartment.

Backlog Items:

* PBI-005. Foundation infrastructure for system-level FSS tests

## Sprint 2 - FSS filesystem module

Status: Progress
Mode: managed
Test: integration
Regression: integration

Artifacts / Sprint definition notes:

* PBI-006 deliverable -> `progress/sprint_2/sprint_2_tf_rules.md`

Backlog Items:

* PBI-001. Terraform module for FSS filesystem
* PBI-006. Terraform architecture rules for agentic development

## Sprint 3 - FSS mount target module

Status: Planned
Mode: managed
Test: integration
Regression: integration

This sprint combines mount target, export, and availability validation to enable end-to-end testing of the FSS setup.

Backlog Items:

* PBI-002. Terraform module for FSS mount target
* PBI-003. Terraform module for FSS export
* PBI-004. Network Path Analyzer test for FSS availability
