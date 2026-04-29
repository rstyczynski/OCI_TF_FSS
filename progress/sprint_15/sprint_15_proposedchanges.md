# Sprint 15 - Proposed Changes

## Filesystem selector fallback

Status: Proposed

Proposal: For the export-only Resource Manager stack, use a plain `existing_filesystem_ocid` string input unless Product Owner confirms a supported Resource Manager schema type for File Storage filesystem dropdowns. Keep existing mount target selection as a dynamic dropdown using `oci:mount:target:id`.

Rationale: Oracle's documented Resource Manager schema supported types include `oci:mount:target:id` but do not show a File Storage filesystem selector. A string fallback keeps the workflow deployable without inventing unsupported schema types.

Product Owner opinion: Provide filesystem name from current compartment.

Resolution: Deferred to future PBI-029. Sprint 15 implements mount target creation and filesystem creation with chained optional exports only.

## Split advanced Resource Manager package into focused backlog items

Status: Accepted

Proposal: Split the broad advanced Resource Manager workflow into three backlog items: mount target stack, filesystem stack with chained dynamic export groups, and export-only stack. Sprint 15 will implement the first two items. Export-only stack moves to a future sprint.

Rationale: Resource Manager schema can emulate dynamic export groups with bounded chained checkboxes, which removes the immediate need for a separate export-only stack in this sprint. Export-only remains useful for day-2 expansion and is clearer as its own backlog item.
