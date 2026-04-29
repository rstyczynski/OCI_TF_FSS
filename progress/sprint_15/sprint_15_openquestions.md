# Sprint 15 - More Information Needed

## Filesystem Resource Manager selector support

Status: Proposed

Problem to clarify: Oracle Resource Manager schema documentation confirms a dynamic mount target selector type, `oci:mount:target:id`, but I do not see a documented equivalent dynamic selector for File Storage filesystems. PBI-026 asks the export-only stack to let the operator select an existing filesystem and existing mount target.

Answer: Pending Product Owner approval. Proposed fallback is to use a normal string input for the existing filesystem OCID in Sprint 15 while keeping `oci:mount:target:id` for mount targets. If Oracle supports a filesystem selector type in the target tenancy, we can revise the schema before construction.

Product Owner opinion:
1. Mount target 
