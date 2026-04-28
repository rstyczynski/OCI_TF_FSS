# Sprint 8 - Tests

Status: Passed

## Quality Gates

Sprint configuration:

- Test: integration
- Regression: none
- Mode: managed

## A3 Integration

Command:

```bash
tests/run.sh --integration --new-only progress/sprint_8/new_tests.manifest
```

Evidence:

- `progress/sprint_8/test_run_A3_integration_20260428_174852.log`

Result:

- pass=1
- fail=0

Verified behavior:

- Terraform initialized and validated the generated Sprint 8 root module.
- Terraform applied `fss_sprint8_stack` with one logging-enabled mount target.
- `mount_targets.mt_logged.logging` included log group OCID, log OCID, File Storage service, `nfslogs` category, mount target resource OCID, enabled flag, and retention.
- Atomic log OCID outputs matched the composite logging object.
- `oci logging log get` returned the created enabled log.
- The test mounted the generated NFS source from the foundation compute instance and wrote/read a proof file.
- `oci logging-search search-logs` returned 1 result.
- Terraform teardown destroyed all 5 test resources.

## Regression

Not run. Sprint 8 is a new stack module and the sprint definition sets `Regression: none`.
