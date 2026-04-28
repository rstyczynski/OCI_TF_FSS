# Sprint 4 - Design

## PBI-002. Terraform module for FSS mount target

Status: Proposed

### Requirement Summary

Create a Terraform module that provisions an OCI FSS mount target that downstream exports can attach to. The module must keep an explicit interface and expose identifiers required by export and availability validation.

### Feasibility Analysis

**API Availability:**

- OCI Terraform provider supports `oci_file_storage_mount_target`.
- Oracle provider documentation states that mount target creation requires `availability_domain`, `compartment_id`, and `subnet_id`; it exports `id`, `export_set_id`, and `private_ip_ids`.
- Oracle provider documentation states a file system can be associated with a mount target only when both are in the same availability domain.

**References:**

- Oracle Terraform provider mount target resource: https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci/latest/docs/r/file_storage_mount_target.html

**Technical Constraints:**

- Follow Sprint 3 Terraform rules: explicit required inputs, stable outputs, no random AD selection, no `name_prefix` abstraction.
- Proposed product path: `terraform/modules/fss_sprint4_mount_target`.
- Mount target integration tests will use the Sprint 1 foundation subnet.
- Oracle-managed defined tags should use the same narrowly scoped lifecycle handling as Sprint 3.

**Risk Assessment:**

- Mount targets consume multiple subnet IP addresses; the foundation subnet must have sufficient free IPs.
- Export association requires the mount target and filesystem to share an availability domain.

### Design Overview

**Architecture:**

- Add `terraform/modules/fss_sprint4_mount_target/`.
- The module creates exactly one `oci_file_storage_mount_target`.
- Required inputs are `compartment_ocid`, `availability_domain`, `subnet_ocid`, and `display_name`.
- Optional inputs are `hostname_label`, `nsg_ids`, `freeform_tags`, and `defined_tags`.

**Outputs:**

- `mount_target_ocid`
- `mount_target_display_name`
- `mount_target_export_set_ocid`
- `mount_target_private_ip_ids`
- `availability_domain`
- `subnet_ocid`

### Technical Specification

**Resource:**

- `oci_file_storage_mount_target.this`

**Inputs:**

- `compartment_ocid` (required)
- `availability_domain` (required)
- `subnet_ocid` (required)
- `display_name` (required)
- `hostname_label` (optional, default `null`)
- `nsg_ids` (optional, default `null`)
- `freeform_tags` (optional, default `{}`)
- `defined_tags` (optional, default `{}`)

**Lifecycle handling:**

Use the Sprint 3 tag lifecycle pattern:

```hcl
lifecycle {
  ignore_changes = [
    defined_tags["Oracle-Tags.CreatedBy"],
    defined_tags["Oracle-Tags.CreatedOn"],
  ]
}
```

## PBI-003. Terraform module for FSS export

Status: Proposed

### Requirement Summary

Create a Terraform module that provisions an OCI FSS export linking a filesystem to a mount target export set at a caller-provided export path.

### Feasibility Analysis

**API Availability:**

- OCI Terraform provider supports `oci_file_storage_export`.
- Oracle provider documentation states that export creation requires `export_set_id`, `file_system_id`, and `path`.
- Oracle provider documentation states export options control visibility and that exports without matching client options are invisible to clients.

**References:**

- Oracle Terraform provider export resource: https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci/latest/docs/r/file_storage_export.html

**Technical Constraints:**

- Proposed product path: `terraform/modules/fss_sprint4_export`.
- The module should not create a filesystem or mount target; it should accept their OCIDs explicitly.
- The default integration export option should permit the Sprint 1 foundation subnet CIDR.

**Risk Assessment:**

- Too-broad export options can expose the filesystem more than intended inside the VCN. Tests should pass an explicit foundation subnet CIDR rather than rely on provider defaults.
- Export paths must be unique within a mount target export set.

### Design Overview

**Architecture:**

- Add `terraform/modules/fss_sprint4_export/`.
- The module creates exactly one `oci_file_storage_export`.
- Required inputs are `export_set_ocid`, `file_system_ocid`, `path`, and `source_cidr`.
- Export options default to read/write, SYS auth, root squash, no anonymous access, and no privileged source-port requirement for practical Linux client compatibility.

**Outputs:**

- `export_ocid`
- `export_path`
- `export_set_ocid`
- `file_system_ocid`

### Technical Specification

**Resource:**

- `oci_file_storage_export.this`

**Inputs:**

- `export_set_ocid` (required)
- `file_system_ocid` (required)
- `path` (required)
- `source_cidr` (required)
- `access` (optional, default `"READ_WRITE"`)
- `allowed_auth` (optional, default `["SYS"]`)
- `identity_squash` (optional, default `"ROOT"`)
- `anonymous_uid` (optional, default `65534`)
- `anonymous_gid` (optional, default `65534`)
- `is_anonymous_access_allowed` (optional, default `false`)
- `require_privileged_source_port` (optional, default `false`)

## PBI-004. Network Path Analyzer test for FSS availability

Status: Proposed

### Requirement Summary

Add an integration validation that uses OCI Network Path Analyzer through the existing `oci_scaffold` helper to check TCP reachability from the foundation subnet to the FSS mount target private IP on NFS port 2049.

### Feasibility Analysis

**API Availability:**

- OCI CLI supports `oci vn-monitoring path-analysis get-path-analysis-adhoc`.
- The CLI command initiates an analysis and waits for a successful or failed work request.
- This repository already contains `oci_scaffold/resource/ensure-path_analyzer.sh`, which submits an ad hoc path analysis and stores the result in scaffold state.

**References:**

- OCI CLI path analysis command: https://docs.oracle.com/en-us/iaas/tools/oci-cli/3.63.3/oci_cli_docs/cmdref/vn-monitoring/path-analysis/get-path-analysis-adhoc.html
- Local helper: `oci_scaffold/resource/ensure-path_analyzer.sh`

**Technical Constraints:**

- Use `oci_scaffold` for NPA because Terraform support is not available in this sprint.
- Keep Terraform state under `progress/sprint_4/tf_state/`.
- Reuse Sprint 1 foundation scaffold state from `progress/sprint_1/scaffold/infra/state-infra.json`.
- The NPA source is the foundation subnet endpoint used by `ensure-path_analyzer.sh`; the destination is the mount target private IP resolved after Terraform apply.

**Risk Assessment:**

- NPA service or permissions can return unavailable. Sprint 4 will treat that as a failed validation with the reason captured in the log.
- Path Analyzer proves network reachability, not an actual NFS mount. A future sprint can add remote mount validation if required.

### Design Overview

**Architecture:**

1. Integration test creates a filesystem with `terraform/modules/fss_sprint3`.
2. Integration test creates a mount target with `terraform/modules/fss_sprint4_mount_target` in the foundation subnet and same AD.
3. Integration test creates an export with `terraform/modules/fss_sprint4_export`.
4. Integration test resolves the mount target private IP from `private_ip_ids`.
5. Integration test prepares a transient Sprint 4 NPA workdir by copying the needed foundation state fields and setting:
   - `.inputs.path_analyzer_dst_ip` to the mount target private IP
   - `.inputs.path_analyzer_protocol` to `tcp`
   - `.inputs.path_analyzer_port` to `2049`
   - `.inputs.path_analyzer_label` to a Sprint 4 label
6. Integration test runs `oci_scaffold/resource/ensure-path_analyzer.sh` and asserts the latest result is `SUCCEEDED`.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration - Terraform resources and OCI path analysis must run against OCI.
- **Regression:** integration - existing foundation and filesystem module behavior must not regress.
- **Regression scope:** omit; run full integration regression per `PLAN.md`.

#### Unit Test Targets

None. This repository currently validates Terraform infrastructure through integration scripts.

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|----------|-----------------------------|------------------|--------------|
| Mount target happy path | OCI credentials, foundation subnet, Terraform | Mount target is created and outputs include OCID, export set OCID, private IP IDs | 2-5 min |
| Export happy path | OCI credentials, filesystem, mount target, Terraform | Export is created with expected path and source CIDR | 2-5 min |
| Path Analyzer reachability | OCI credentials, oci_scaffold, foundation state, mount target private IP | NPA result is `SUCCEEDED` for TCP/2049 from foundation subnet to mount target IP | 1-3 min |

#### Smoke Test Candidates

None. Sprint `Test:` is integration only.

**Success Criteria:**

- New-code integration gate passes all Sprint 4 tests.
- Full integration regression gate passes.
- Sprint 4 docs include operator usage for mount target/export and NPA validation.

### Open Design Questions

- None blocking. Proposed module paths are part of this design and should be accepted or corrected during review.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Mount target happy path

- **Preconditions:** Terraform installed; OCI credentials configured; Sprint 1 foundation state exposes compartment, subnet, and subnet CIDR.
- **Steps:** create a filesystem using the Sprint 3 module, create a mount target in the foundation subnet using the Sprint 4 mount target module.
- **Expected Outcome:** apply succeeds and outputs include mount target OCID, export set OCID, and at least one private IP ID.
- **Verification:** parse Terraform outputs.
- **Target file:** `tests/integration/test_fss_sprint4_tf.sh`

#### IT-2: Export happy path

- **Preconditions:** Terraform installed; OCI credentials configured; filesystem and mount target are created in the same Terraform root.
- **Steps:** create export with explicit path and `source_cidr` equal to the foundation subnet CIDR.
- **Expected Outcome:** apply succeeds and outputs include export OCID and export path.
- **Verification:** parse Terraform outputs and compare export path.
- **Target file:** `tests/integration/test_fss_sprint4_tf.sh`

#### IT-3: Network Path Analyzer reachability

- **Preconditions:** Terraform IT root has created filesystem, mount target, and export; `oci_scaffold` is present; OCI CLI can run NPA.
- **Steps:** resolve mount target private IP, run `oci_scaffold/resource/ensure-path_analyzer.sh` from foundation subnet to mount target IP on TCP/2049.
- **Expected Outcome:** NPA completes with `SUCCEEDED`.
- **Verification:** inspect latest `.path_analyzer[]` state result.
- **Target file:** `tests/integration/test_fss_sprint4_tf.sh`

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
|--------------|-------|------------|-------------------|
| PBI-002 | - | - | IT-1, IT-3 |
| PBI-003 | - | - | IT-2, IT-3 |
| PBI-004 | - | - | IT-3 |
