# Sprint 4 - Implementation Notes

## Implementation Overview

**Sprint Status:** tested

**Backlog Items:**

- PBI-002. Terraform module for FSS mount target - tested
- PBI-003. Terraform module for FSS export - tested
- PBI-004. Network Path Analyzer test for FSS availability - tested

## PBI-002. Terraform module for FSS mount target

Status: tested

### Implementation Summary

Implemented `terraform/modules/fss_sprint4_mount_target/` as an explicit-input module for one OCI FSS mount target. It requires `compartment_ocid`, `availability_domain`, `subnet_ocid`, and `display_name`, supports optional tags, hostname label, and NSG IDs, and ignores only Oracle-managed `defined_tags` keys.

The module now exposes operator mount endpoint outputs in addition to OCI identifiers:

- `mount_target_ip_address`: primary private IP address assigned to the mount target.
- `mount_target_fqdn`: DNS name when `hostname_label` and subnet DNS are available.
- `mount_target_mount_address`: preferred NFS server address, using FQDN when available and falling back to private IP.

### Code Artifacts

| Artifact | Purpose | Status |
|----------|---------|--------|
| `terraform/modules/fss_sprint4_mount_target/` | OCI FSS mount target module | Complete |
| `tests/integration/test_fss_sprint4_tf.sh` | Mount target integration coverage | Complete |

## PBI-003. Terraform module for FSS export

Status: tested

### Implementation Summary

Implemented `terraform/modules/fss_sprint4_export/` as an explicit-input module for one OCI FSS export. It requires `export_set_ocid`, `file_system_ocid`, `path`, and `source_cidr`, and exposes export identifiers for callers and tests.

### Code Artifacts

| Artifact | Purpose | Status |
|----------|---------|--------|
| `terraform/modules/fss_sprint4_export/` | OCI FSS export module | Complete |
| `tests/integration/test_fss_sprint4_tf.sh` | Export integration coverage | Complete |

## PBI-004. Network Path Analyzer test for FSS availability

Status: tested

### Implementation Summary

Filled the Sprint 4 integration test skeletons. Each test creates a self-contained Terraform root under `progress/sprint_4/generated_tf/`, provisions a Sprint 3 filesystem, Sprint 4 mount target, and Sprint 4 export, then tears down Terraform resources while preserving generated `main.tf` for operator review. The path analyzer test creates transient oci_scaffold state under `progress/sprint_4/scaffold/` and runs `oci_scaffold/resource/ensure-path_analyzer.sh` from the foundation compute VNIC to the mount target VNIC on TCP/2049.

### Verification Before Quality Gates

- `terraform fmt -recursive terraform/modules/fss_sprint4_mount_target terraform/modules/fss_sprint4_export`
- `bash -n tests/integration/test_fss_sprint4_tf.sh`
- Generated Sprint 4 Terraform root validation: `terraform validate` returned success.

### Post-Sprint Documentation Update

Operator-facing mount outputs were added after reviewing the Sprint 5 stack outputs. The update is documentation/API-surface oriented and was validated with:

- `terraform validate` in `terraform/modules/fss_sprint4_mount_target`
- `terraform validate` in `terraform/modules/fss_sprint5_stack`

### Quality Gate Verification

- A3 new-code integration: `progress/sprint_4/test_run_A3_integration_20260428_081015.log`, summary `pass=3 fail=0`.
- B3 full integration regression: `progress/sprint_4/test_run_B3_integration_20260428_081543.log`, summary `pass=4 fail=0`.
- NPA proof: `progress/sprint_4/sprint_4_npa_report.md`.

### Known Issues

- None.
