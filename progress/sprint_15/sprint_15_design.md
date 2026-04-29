# Sprint 15 - Design

Status: Accepted

Mode: managed

## PBI-026. Add Resource Manager mount target stack

Status: Accepted

### Requirement

Create a focused OCI Resource Manager stack for FSS mount target creation. The stack must expose Resource Manager form controls for placement, network, optional logging, and tags, and output the mount target identifiers needed by later FSS workflows.

## PBI-028. Add Resource Manager filesystem stack with chained exports

Status: Accepted

### Requirement

Create a focused OCI Resource Manager stack for one filesystem with one mandatory export and up to five additional optional exports. The stack must let the operator select an existing mount target, then use chained "add another export" checkboxes so optional export groups appear only when needed.

### Feasibility Analysis

Oracle Resource Manager schema documents allow console variable controls and dynamic prepopulation. The supported types list includes `oci:mount:target:id`, and the meta schema requires `dependsOn.compartmentId` and `dependsOn.availabilityDomain` for that type. This means existing mount target dropdowns are feasible for the filesystem stack, but the form must ask for an availability domain before rendering the mount target dropdown.

Resource Manager schema does not appear to support true dynamic page creation or arbitrary repeated groups. A bounded, chained-checkbox pattern is feasible: export 1 is always visible; export 1 contains `add_export_2`; export 2 is visible only when `add_export_2` is true and contains `add_export_3`; this continues to export 6.

The export-only workflow is moved to future `PBI-029`, so Sprint 15 does not need a File Storage filesystem selector.

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

### Stack 2 - Filesystem With Chained Exports

Purpose: create one filesystem and one to six exports using an existing mount target selected in Resource Manager.

Inputs:

- `region`
- `compartment_ocid`
- `availability_domain`
- `existing_mount_target_ocid` using Resource Manager type `oci:mount:target:id`
- optional filesystem display name
- optional KMS key OCID
- export 1 path and export options
- chained optional export 2 through export 6 groups
- tags

Implementation approach:

- Resolve the selected mount target using `data.oci_file_storage_mount_targets` filtered by `id`.
- Read `export_set_id`, `ip_address`, and `hostname_label`/mount address candidates from the selected mount target.
- Create filesystem in the same availability domain.
- Create exports against the resolved export set for enabled export slots only.
- Validate enabled export slots so path is non-empty and export paths are unique.
- Build a local `exports` map from enabled slot variables rather than asking the operator to edit a raw map.

Chained export UI:

- Export 1 is mandatory and visible.
- Export 1 includes `add_export_2`.
- Export 2 group is visible only when `add_export_2` is true and includes `add_export_3`.
- Export 3 group is visible only when `add_export_3` is true and includes `add_export_4`.
- Continue through export 6.

Outputs:

- `filesystem_ocid`
- `export_ocids`
- `export_paths`
- `mount_target_ocid`
- `export_set_ocid`
- `nfs_mount_sources`
- `filesystem_export_summary`

### Resource Manager Schema Design

Each stack has its own `schema.yaml` at the stack root. Schemas must:

- group variables by placement, resource settings, export settings, logging, and tags
- use `oci:identity:region:name`, `oci:identity:compartment:id`, `oci:identity:availabilitydomain:name`, `oci:core:subnet:id`, `oci:kms:key:id`, and `oci:mount:target:id` where supported
- expose output groups with copyable mount information and resource OCIDs
- avoid raw map/object editing for primary operator workflows
- use chained `visible` expressions for optional export groups in the filesystem stack

### Operator Documentation

Create a package README and Sprint 15 operator manual showing:

1. create mount target stack
2. create filesystem with one or more exports by selecting that mount target
3. read `nfs_mount_sources`
4. destroy in reverse order

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
| Advanced workflow apply | OCI Resource Manager, FSS, subnet | mount target stack creates mount target; filesystem stack creates one filesystem with at least two exports; outputs expose mount sources | 10-20 min |
| Reverse destroy | OCI Resource Manager jobs | filesystem stack and mount-target stack destroy cleanly | 5-15 min |

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
- Steps: package/upload mount target stack, apply it, package/upload filesystem stack selecting the created mount target, enable at least one optional chained export, apply it, verify outputs, destroy in reverse order.
- Expected outcome: all Resource Manager jobs complete successfully and outputs expose mount target details, filesystem OCID, export OCIDs, and NFS mount source strings.
- Target file: `tests/integration/test_fss_sprint15_orm_advanced.sh`

### Traceability

| Backlog Item | Smoke Tests | Integration Tests |
|---|---|---|
| PBI-026 | SM-1 | IT-1 |
| PBI-028 | SM-1 | IT-1 |
