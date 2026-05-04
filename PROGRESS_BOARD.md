# Progress board

Progress board is a table showing sprint, and backlog items state. It's the only purpose of this file. All potential comments, progress notes, etc. always keep in dedicated files for each phase.

| Sprint | Sprint Status | Backlog Item | Item Status |
| --- | --- | --- | --- |
| Sprint 1 | implemented | PBI-005. Foundation infrastructure for system-level FSS tests | tested |
| Sprint 2 | implemented | PBI-001. Terraform module for FSS filesystem | tested |
| Sprint 2 | implemented | PBI-006. Terraform architecture rules for agentic development | tested |
| Sprint 3 | tested | PBI-001. Terraform module for FSS filesystem | tested |
| Sprint 3 | tested | PBI-006. Terraform architecture rules for agentic development | tested |
| Sprint 4 | tested | PBI-002. Terraform module for FSS mount target | tested |
| Sprint 4 | tested | PBI-003. Terraform module for FSS export | tested |
| Sprint 4 | tested | PBI-004. Network Path Analyzer test for FSS availability | tested |
| Sprint 5 | tested | PBI-007. FSS module - expose kms_key_id argument at mandatory variables | tested |
| Sprint 5 | tested | PBI-008. FSS module - expose rest of all available arguments at with default values | tested |
| Sprint 5 | tested | PBI-009. Create higher level module that accepts map of arguments to support multiple FSS with all mount points and exports | tested |
| Sprint 6 | tested | PBI-010. Mount FSS file system(s) on a compute instance | tested |
| Sprint 6 | tested | PBI-011. Perform administrator tasks for FSS mount(s) | tested |
| Sprint 7 | tested | PBI-019. Refactor stack filesystem variable | tested |
| Sprint 8 | tested | PBI-016. Add logging to mount targets | tested |
| Sprint 9 | tested | PBI-013. Pack sprint 5 terraform stack and lower level modules into v1 module | tested |
| Sprint 9 | tested | PBI-014. Prepare comprehensive user documentation for v1 modules | tested |
| Sprint 10 | tested | PBI-020. Rebase v1 stack on latest Sprint 8 stack interface | tested |
| Sprint 11 | tested | PBI-021. Create v2 stack with optimized mandatory parameters | tested |
| Sprint 11 | tested | PBI-022. Complete v2 stack package and README | tested |
| Sprint 12 | tested | PBI-024. Repackage FSS stack with examples and modules layout | tested |
| Sprint 13 | tested | PBI-023. Package current FSS stack package for OCI Resource Manager | tested |
| Sprint 14 | tested | PBI-027. Add legacy PV report to FSS stack variables converter | tested |
| Sprint 15 | failed | PBI-026. Add Resource Manager mount target stack | failed |
| Sprint 15 | failed | PBI-028. Add Resource Manager filesystem stack with chained exports | failed |
| Sprint 16 | tested | PBI-030. Replace sprint-15-specific intermediate modules with fss_stack_sprint17 | tested |
| Sprint 17 | tested | PBI-031. fss_stack_sprint12 - support externally managed mount targets in exports | tested |
| Sprint 17 | tested | PBI-032. fss stack - allow per-mount-target placement overrides (subnet / availability domain) | tested |
| Sprint 18 | tested | PBI-033. Stable release pointers for terraform/modules | tested |
| Sprint 19 | tested | PBI-035. OCI FSS export path scoping experiment and multi_exports_one_fs example | tested |
| — | — | PBI-025. Verify identity_squash = "NONE" behavior at NFS level | tested |
