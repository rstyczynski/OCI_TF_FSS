# Sprint 15 - Proposed Changes

## Filesystem selector fallback

Status: Proposed

Proposal: For the export-only Resource Manager stack, use a plain `existing_filesystem_ocid` string input unless Product Owner confirms a supported Resource Manager schema type for File Storage filesystem dropdowns. Keep existing mount target selection as a dynamic dropdown using `oci:mount:target:id`.

Rationale: Oracle's documented Resource Manager schema supported types include `oci:mount:target:id` but do not show a File Storage filesystem selector. A string fallback keeps the workflow deployable without inventing unsupported schema types.
