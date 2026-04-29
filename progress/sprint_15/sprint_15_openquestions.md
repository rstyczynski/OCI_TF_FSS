# Sprint 15 - More Information Needed

## Filesystem Resource Manager selector support

Status: Proposed

Problem to clarify: Oracle Resource Manager schema documentation confirms a dynamic mount target selector type, `oci:mount:target:id`, but I do not see a documented equivalent dynamic selector for File Storage filesystems. The export-only stack is now moved to future PBI-029, so this no longer blocks Sprint 15.

Answer: Not required for Sprint 15 after backlog split. Existing mount target selection remains in scope; existing filesystem selection moves to future PBI-029.

Product Owner opinion: Provide filesystem name from current compartment

Resolution: Deferred to future PBI-029. Sprint 15 does not implement export-only workflow.
