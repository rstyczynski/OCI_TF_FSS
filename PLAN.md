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

Status: Done
Mode: managed
Test: integration
Regression: integration

Artifacts / Sprint definition notes:

* PBI-006 deliverable -> `progress/sprint_2/sprint_2_tf_rules.md`

Backlog Items:

* PBI-001. Terraform module for FSS filesystem
* PBI-006. Terraform architecture rules for agentic development

## Sprint 3 - simplify sprint 2 product

Status: Done
Mode: managed
Test: integration
Regression: integration

Sprint 2 implemented some add-on features as: (1) AD randomization, (2) dynamic tag recognition, (3) name_prefix. All of this must be remove to keep the solution as simple as possible and as close to regular terraform best practices as possible. 

(4) Terraform agentic rules should move all three techniques to `Experimental patterns` chapter to be used ONLY on a clear request.

(5) Keep product in terraform/modules/fss_sprint3

Changes:
Ad.1 - remove
Ad.2 - change to life-cycle with clear exclusion of Oracle managed tags. May be on resource or provider level.
Ad.3 - remove
Ad.4 - as instructed - do not completely drop ideas, but move to `Experimental patterns` chapter. PBI-006 deliverable -> `progress/sprint_3/sprint_3_tf_rules.md`

Status: Done
Mode: managed
Test: integration
Regression: integration

* PBI-001. Terraform module for FSS filesystem
* PBI-006. Terraform architecture rules for agentic development

## Sprint 4 - FSS mount target module

Status: Done
Mode: managed
Test: integration
Regression: integration

This sprint combines mount target, export, and availability validation to enable end-to-end testing of the FSS setup. Product is kept in ./terraform directory with clear sprint4 location.

Backlog Items:

* PBI-002. Terraform module for FSS mount target
* PBI-003. Terraform module for FSS export
* PBI-004. Network Path Analyzer test for FSS availability
