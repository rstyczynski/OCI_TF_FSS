# Sprint 13 - Test Execution Results

## Summary

| Gate | Result | Retries | Pass Rate |
|---|---:|---:|---:|
| A3 Integration | PASS | 1 | 100% on final run |

Regression: none (per PLAN.md).

## Artifacts

| Gate | Log File |
|---|---|
| A3 Integration | `progress/sprint_13/test_run_A3_integration_20260429_115006.log` |
| Failed probe before provider-region fix | `progress/sprint_13/test_run_A3_integration_20260429_114409.log` |
| IT-3 probe before provider-region fix | `progress/sprint_13/test_run_A3_integration_IT3_probe_20260429_114706.log` |

## Test Results

### IT-1: ORM package validates locally

**Status:** PASS

- `schema.yaml` parsed successfully.
- Required variables `region`, `compartment_ocid`, and `subnet_ocid` are declared.
- Outputs `nfs_mount_sources`, `mount_targets`, and `resource_manager_summary` are declared.
- `terraform init` and `terraform validate` passed for the generated ORM package copy.

### IT-2: ORM stack upload succeeds

**Status:** PASS

OCI Resource Manager accepted the generated package zip and created an active stack from working directory `terraform/modules/fss_stack_sprint13_orm`.

The upload-only stack was deleted after validation.

### IT-3: ORM apply and destroy jobs succeed

**Status:** PASS

OCI Resource Manager apply job succeeded. Terraform state output included:

```json
{
  "data__primary": "10.0.0.76:/data"
}
```

`resource_manager_summary` included:

```json
{
  "availability_domain": "jJRq:EU-ZURICH-1-AD-1",
  "availability_domain_source": "random",
  "export_path": "/data",
  "kms_key_mode": "ORACLE_MANAGED",
  "mount_target_mount_address": "10.0.0.76",
  "nfs_mount_source": "10.0.0.76:/data"
}
```

Destroy job succeeded and the Resource Manager stack was deleted.

## Fixes During Quality Gates

- Initial Resource Manager apply failed because the OCI provider had no explicit region in the Resource Manager runner.
- Added `region` input and provider configuration `region = var.region`.
- Updated tests to pass Sprint 1 foundation region and capture Resource Manager job logs correctly.
