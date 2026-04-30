# Sprint 16 - Implementation Notes

## PBI-030. Replace sprint-15-specific intermediate modules with fss_stack_sprint17

Status: Progress

Implemented in `terraform/modules/fss_stack_sprint16_orm_advanced/`.

- Created a new Sprint 16 ORM product directory instead of modifying the failed Sprint 15 package.
- Embedded verbatim copies of `terraform/modules/fss_stack_sprint17/` under both Sprint 16 Resource Manager roots:
  - `mount_target/modules/fss_stack_sprint17/`
  - `filesystem_export/modules/fss_stack_sprint17/`
- Updated `mount_target/` to call the full Sprint 17 stack with one managed `mount_targets.primary` entry and `filesystems = {}`.
- Updated `filesystem_export/` to call the full Sprint 17 stack with `mount_targets.existing.external_ocid`, preserving the existing Resource Manager UI variables and output shape.
- Added Sprint 16-specific smoke and integration tests so Sprint 15 tests and generated artifacts remain untouched.

Verification:

- A1 smoke: `progress/sprint_16/test_run_A1_smoke_20260430_141200.log`
- A3 integration: `progress/sprint_16/test_run_A3_integration_20260430_141213.log`
