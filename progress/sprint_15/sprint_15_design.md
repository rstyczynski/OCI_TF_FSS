# Sprint 15 - Design

Status: Proposed

Mode: managed

## PBI-026. Add advanced multi-topology Resource Manager package

Status: Proposed

### Requirement

Create an advanced OCI Resource Manager package set for the current FSS stack package. The package set must support focused console workflows instead of raw `mount_targets` and `filesystems` maps:

- mount target stack
- filesystem with export stack
- export-only stack

### Feasibility Analysis

Oracle Resource Manager schema documents allow console variable controls and dynamic prepopulation. The supported types list includes `oci:mount:target:id`, and the meta schema requires `dependsOn.compartmentId` and `dependsOn.availabilityDomain` for that type. This means existing mount target dropdowns are feasible, but the stack forms must ask for an availability domain before rendering the mount target dropdown.

I do not see a documented Resource Manager schema type for File Storage filesystem OCID selection. This affects the export-only stack, because PBI-026 asks for selecting an existing filesystem. The proposed Sprint 15 design uses a string filesystem OCID input as a fallback and records this as a managed-mode open question.

Primary reference: Oracle Resource Manager schema documentation, "Extend Console Pages Using Schema Documents": `https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager_topic-schema.htm`, especially supported dynamic prepopulation types and `oci:mount:target:id` meta schema.

### Product Layout

Create an advanced Resource Manager package family beside the Sprint 13 package:

```text
terraform/modules/fss_stack_sprint15_orm_advanced/
  README.md
  mount_target/
    main.tf
    variables.tf
    outputs.tf
    versions.tf
    schema.yaml
  filesystem_export/
    main.tf
    variables.tf
    outputs.tf
    versions.tf
    schema.yaml
  export/
    main.tf
    variables.tf
    outputs.tf
    versions.tf
    schema.yaml
```

Generated review/apply roots and package zips stay under:

```text
progress/sprint_15/generated_tf/
```

### Stack 1 - Mount Target

Purpose: create one mount target in a selected compartment, subnet, and availability domain.

Inputs:

- `region`
- `compartment_ocid`
- `availability_domain`
- `subnet_ocid`
- optional display name, hostname label, NSGs, tags
- optional logging controls

Outputs:

- `mount_target_ocid`
- `export_set_ocid`
- `mount_address`
- `ip_address`
- `logging`
- `mount_target_summary`

Implementation approach:

- Use the Sprint 12 lower-level mount target module pattern or direct OCI mount target resource equivalent.
- Preserve Sprint 12 output shape where useful.
- Add logging using the Sprint 12 stack logging implementation when enabled.

### Stack 2 - Filesystem With Export

Purpose: create one filesystem and one export using an existing mount target selected in Resource Manager.

Inputs:

- `region`
- `compartment_ocid`
- `availability_domain`
- `existing_mount_target_ocid` using Resource Manager type `oci:mount:target:id`
- optional filesystem display name
- optional KMS key OCID
- export path and export options
- tags

Implementation approach:

- Resolve the selected mount target using `data.oci_file_storage_mount_targets` filtered by `id`.
- Read `export_set_id`, `ip_address`, and `hostname_label`/mount address candidates from the selected mount target.
- Create filesystem in the same availability domain.
- Create export against the resolved export set.

Outputs:

- `filesystem_ocid`
- `export_ocid`
- `export_path`
- `mount_target_ocid`
- `export_set_ocid`
- `nfs_mount_source`
- `filesystem_export_summary`

### Stack 3 - Export Only

Purpose: create an additional export for an existing filesystem and existing mount target.

Inputs:

- `region`
- `compartment_ocid`
- `availability_domain`
- `existing_mount_target_ocid` using Resource Manager type `oci:mount:target:id`
- `existing_filesystem_ocid` as string unless Product Owner confirms a supported filesystem dropdown type
- export path and export options

Implementation approach:

- Resolve the selected mount target using `data.oci_file_storage_mount_targets` filtered by `id`.
- Create a new `oci_file_storage_export` for the provided filesystem OCID and resolved export set.

Outputs:

- `export_ocid`
- `export_path`
- `filesystem_ocid`
- `mount_target_ocid`
- `export_set_ocid`
- `nfs_mount_source`
- `export_summary`

### Resource Manager Schema Design

Each stack has its own `schema.yaml` at the stack root. Schemas must:

- group variables by placement, resource settings, export settings, logging, and tags
- use `oci:identity:region:name`, `oci:identity:compartment:id`, `oci:identity:availabilitydomain:name`, `oci:core:subnet:id`, `oci:kms:key:id`, and `oci:mount:target:id` where supported
- expose output groups with copyable mount information and resource OCIDs
- avoid raw map/object editing for primary operator workflows

### Operator Documentation

Create a package README and Sprint 15 operator manual showing:

1. create mount target stack
2. create filesystem with export stack selecting that mount target
3. create export-only stack using the existing filesystem and mount target
4. read `nfs_mount_source`
5. destroy in reverse order

Documentation snippets must either be executed with evidence or explicitly marked NOT RUN with the reason.

### Testing Strategy

#### Recommended Sprint Parameters

- Test: smoke, integration
- Regression: none

Smoke covers package shape, schema presence, and Terraform formatting without OCI changes. Integration covers Resource Manager stack upload/apply/destroy.

#### Smoke Test Targets

| Candidate | Why Critical | Expected Runtime |
|---|---|---|
| Package layout and schema check | If files are missing, upload cannot work | < 10 sec |
| Terraform fmt/validate for package roots | If roots are invalid, Resource Manager jobs fail late | < 2 min |

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|---|---|---|
| Resource Manager package upload | OCI Resource Manager, Sprint 1 foundation compartment/subnet | each stack upload succeeds and schema is accepted | 2-5 min |
| Advanced workflow apply | OCI Resource Manager, FSS, subnet | mount target stack creates mount target; filesystem-export stack creates filesystem/export; export-only stack creates additional export; outputs expose mount source | 10-20 min |
| Reverse destroy | OCI Resource Manager jobs | export-only, filesystem-export, and mount-target stacks destroy cleanly | 5-15 min |

## Test Specification

Sprint Test Configuration:

- Test: smoke, integration
- Mode: managed

### Smoke Tests

#### SM-1: Advanced ORM package static validation

- What it verifies: expected package directories, root Terraform files, schema files, and README exist.
- Pass criteria: all required files exist, `terraform fmt -check` passes, and local Terraform validation passes for each stack root where possible.
- Why smoke: catches unusable packages before OCI upload.
- Target file: `tests/smoke/test_fss_sprint15_orm_advanced.sh`

### Integration Tests

#### IT-1: Resource Manager advanced workflow

- Preconditions: Sprint 1 foundation state exists and OCI CLI has Resource Manager permissions.
- Steps: package/upload mount target stack, apply it, package/upload filesystem-export stack selecting the created mount target, apply it, package/upload export-only stack using the created filesystem and mount target, apply it, verify outputs, destroy in reverse order.
- Expected outcome: all Resource Manager jobs complete successfully and outputs expose mount target details, filesystem OCID, export OCIDs, and NFS mount source strings.
- Target file: `tests/integration/test_fss_sprint15_orm_advanced.sh`

### Traceability

| Backlog Item | Smoke Tests | Integration Tests |
|---|---|---|
| PBI-026 | SM-1 | IT-1 |
