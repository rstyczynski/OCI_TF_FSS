# Sprint 10 - Design

Status: Accepted

Mode: YOLO

## PBI-020. Rebase v1 stack on latest Sprint 8 stack interface

Status: Accepted

### Requirement

Sprint 9 produced v1 module paths and documentation, but it packaged the older Sprint 5 stack shape. Sprint 10 corrects the v1 stack module so `terraform/modules/fss_v1_stack` uses the latest approved Sprint 8 stack interface.

### Product Location

Update:

```text
terraform/modules/fss_v1_stack/
  versions.tf
  variables.tf
  main.tf
  outputs.tf
  README.md
```

Do not modify Sprint 8 source modules. The v1 stack should copy the Sprint 8 interface while referencing v1 lower-level modules:

- `../fss_v1_mount_target`
- `../fss_v1_filesystem`
- `../fss_v1_export`

### Interface

The v1 stack must accept:

- shared `compartment_ocid`, `availability_domain`, `subnet_ocid`, and `kms_key_id`
- `default_source_cidr`
- `mount_targets` map
- `filesystems` map with nested `exports`

Each export references a mount target by `mount_target_key`.

### Logging

Mount target entries may include `logging`. When enabled:

- create or use a log group
- create an OCI File Storage NFS service log
- expose log details through `mount_targets[*].logging`
- expose atomic `mount_target_log_group_ocids` and `mount_target_log_ocids`

### YOLO Decision

Ambiguity: whether to keep Sprint 9 history as failed or create a separate corrective sprint.

Decision: keep Sprint 9 as completed for its original packaging/documentation work and add Sprint 10 as the corrective sprint for the latest stack interface.

Rationale: Sprint 9 was already committed and pushed. A new sprint gives the correction its own backlog traceability and evidence.

## Test Specification

### IT-1: v1 stack uses Sprint 8 interface

- Generate Terraform root under `progress/sprint_10/generated_tf/it1_v1_latest_stack_apply/`.
- Apply `fss_v1_stack` with:
  - two mount targets
  - two filesystems
  - three exports
  - logging enabled on one mount target
- Verify:
  - filesystem outputs include `fs_data` and `fs_backup`
  - mount target outputs include `mt_primary` and `mt_secondary`
  - nested export summaries retain mount target references
  - `nfs_mount_sources` uses composite filesystem/export keys
  - `mt_primary.logging` contains File Storage `nfslogs` details
  - `mt_secondary.logging` is null

### IT-2: documented v1 latest example validates

- Generate Terraform root under `progress/sprint_10/generated_tf/it2_latest_documented_example_validate/`.
- Validate the README-shaped example using placeholder OCIDs.

### Regression

None. Sprint 10 updates the v1 stack product only. Sprint-numbered stack modules remain unchanged.

