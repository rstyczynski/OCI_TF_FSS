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

## Sprint 5 - FSS filesystem extended configuration

Status: Done
Mode: managed
Test: integration
Regression: integration

Extend the filesystem module interface and add a higher-level composition module for multiple FSS definitions. Keep the product under `terraform/modules/` with a clear Sprint 5 module path and preserve the Sprint 3 and Sprint 4 products as compatibility baselines.

Backlog Items:

* PBI-007. FSS module - expose kms_key_id argument at mandatory variables
* PBI-008. FSS module - expose rest of all available arguments at with default values
* PBI-009. Create higher level module that accepts map of arguments to support multiple FSS with all mount points and exports

## Sprint 6 - FSS mount and administration

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Automate mounting FSS exports on compute instances and validate common administrator operations on mounted filesystems.

Backlog Items:

* PBI-010. Mount FSS file system(s) on a compute instance
* PBI-011. Perform administrator tasks for FSS mount(s)

## Sprint 7 - FSS stack variable refactor

Status: Done
Mode: managed
Test: integration
Regression: none

Refactor the stack module variable structure so mount targets and filesystems are independent, first-class entries. Each filesystem carries its own nested exports map; each export references a mount target by key. This breaks the current 1:1:1 coupling and aligns the module interface with OCI's actual M:N resource relationships. PBI-019 supersedes PBI-015. Build new version of stack in ./terraform/modules/fss_sprint7_stack

Backlog Items:

* PBI-019. Refactor stack filesystem variable

## Sprint 8 - FSS mount target logging

Status: Done
Mode: managed
Test: integration
Regression: none

Add optional OCI Logging support for mount targets in the current stack interface. Logging must be opt-in per mount target, expose created log resource information, and include an operator manual and integration evidence that uses OCI Logging CLI to discover the created logs.

Backlog Items:

* PBI-016. Add logging to mount targets

## Sprint 9 - FSS v1 module packaging

Status: Done
Mode: YOLO
Test: integration
Regression: none

Package the proven Sprint 5 stack behavior and supporting lower-level modules into stable v1 module paths for operator consumption, and add comprehensive module README documentation with executable examples.

Backlog Items:

* PBI-013. Pack sprint 5 terraform stack and lower level modules into v1 module
* PBI-014. Prepare comprehensive user documentation for v1 modules

## Sprint 10 - Rebase v1 stack on Sprint 8 interface

Status: Done
Mode: YOLO
Test: integration
Regression: none

Repeat the v1 stack packaging using the latest Sprint 8 stack interface. Sprint 9 created the v1 module set and docs, but used the older Sprint 5 stack shape. Sprint 10 updates `fss_v1_stack` to the current interface with independent mount targets, nested filesystem exports, and optional mount target logging.

Backlog Items:

* PBI-020. Rebase v1 stack on latest Sprint 8 stack interface

## Sprint 11 - FSS v2 stack mandatory input optimization

Status: Done
Mode: YOLO
Test: integration
Regression: none

Create an operator-facing v2 stack from the latest v1 stack behavior. Sprint 11 reduces mandatory inputs by deriving the effective availability domain from the subnet or Sprint 2 AD randomization, making `kms_key_id` optional for OCI-managed encryption, and defaulting export source CIDR to `0.0.0.0/0`. It also completes the v2 README and generated Terraform examples for operator review.

Backlog Items:

* PBI-021. Create v2 stack with optimized mandatory parameters
* PBI-022. Complete v2 stack package and README

## Sprint 12 - FSS stack examples and modules layout

Status: Done
Mode: YOLO
Test: integration
Regression: none

Repackage the current FSS stack baseline into `terraform/modules/fss_stack_sprint12/`. The stack package contains executable operator examples under `examples/` and lower-level reusable modules under `modules/`.

Backlog Items:

* PBI-024. Repackage FSS stack with examples and modules layout

## Sprint 13 - OCI Resource Manager package for FSS stack

Status: Done
Mode: managed
Test: integration
Regression: none

Package the current `terraform/modules/fss_stack_sprint12/` stack for OCI Resource Manager. The sprint creates a Resource Manager-compatible Terraform root and `schema.yaml` that expose the common single-stack operator path without requiring operators to hand-author complex map variables, while preserving the full stack module as the underlying implementation.

Backlog Items:

* PBI-023. Package current FSS stack package for OCI Resource Manager

## Sprint 14 - Legacy PV report converter

Status: Done
Mode: YOLO
Test: unit, integration
Regression: none

Create a converter that turns legacy Kubernetes/NFS PV report files into `.auto.tfvars` files for the current `terraform/modules/fss_stack_sprint12/` package. Integration testing applies the generated variables with the Sprint 12 Terraform stack and verifies the created mount targets, filesystems, exports, and mount source outputs.

Backlog Items:

* PBI-027. Add legacy PV report to FSS stack variables converter

## Sprint 15 - Advanced Resource Manager FSS package

Status: Failed
Mode: managed
Test: smoke, integration
Regression: none

Create an advanced OCI Resource Manager package set for the current `terraform/modules/fss_stack_sprint12/` product. Sprint 15 delivers the first two focused stacks: mount target creation, and filesystem creation with chained optional export groups, so operators can use console forms and existing-resource selectors instead of raw map variables.

Backlog Items:

* PBI-026. Add Resource Manager mount target stack
* PBI-028. Add Resource Manager filesystem stack with chained exports

## Sprint 16 - Replace sprint-15-specific modules with canonical fss_stack_sprint17

Status: Done
Mode: YOLO
Test: smoke, integration
Regression: none

Sprint 15 failed due to BUG-11 (critical): the intermediate module layer in both ORM stack roots uses custom sprint-15-specific modules (`fss_stack_sprint15_mount_target`, `fss_stack_sprint15_filesystem_export`) instead of an externally-managed canonical FSS stack module. Sprint 16 uses the improved `fss_stack_sprint17` module so the filesystem/export ORM stack can reference an externally managed mount target through the canonical module entry point.

Sprint 16 creates `terraform/modules/fss_stack_sprint16_orm_advanced/` and embeds a verbatim copy of `fss_stack_sprint17` in each stack root's `modules/` directory. The ORM root variable-shaping logic (tag slots, export slots, validation) stays in the root `main.tf`; resource creation delegates to `fss_stack_sprint17`.

Reference: `progress/sprint_15/sprint_15_bugs.md` BUG-11. Canonical source module: `terraform/modules/fss_stack_sprint17/`.

Backlog Items:

* PBI-030. Replace sprint-15-specific intermediate modules with fss_stack_sprint17 (BUG-11 implementation)

## Sprint 17 - fss_stack_sprint12 supports externally managed mount targets

Status: Done
Mode: managed
Test: smoke, integration
Regression: none

Extend the stack module to support filesystem exports that target externally managed mount targets (by OCID) in addition to stack-managed mount targets (by key lookup), while keeping backwards compatibility with all existing Sprint 12 examples. Keep the sprint product in `terraform/modules/fss_stack_sprint17/`.

Backlog Items:

* PBI-031. fss_stack_sprint12 - support externally managed mount targets in exports
* PBI-032. fss stack - allow per-mount-target placement overrides (subnet / availability domain)
