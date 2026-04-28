# Sprint 5 - Design

Status: Approved

## Overview

Sprint 5 will add a new filesystem module with a broader OCI FSS interface and a higher-level composition module that can create multiple filesystem, mount target, and export entries from a map input.

Product paths proposed for Sprint 5:

- `terraform/modules/fss_sprint5_filesystem`
- `terraform/modules/fss_sprint5_stack`

The Sprint 5 filesystem module will be based on the Sprint 3 filesystem module. The Sprint 5 stack module will compose the Sprint 5 filesystem module with the existing Sprint 4 mount target and export modules.

## Provider Schema Assessment

The local OCI provider schema for `oci_file_storage_file_system` identifies these configurable fields:

- Required by provider: `availability_domain`, `compartment_id`
- Optional configurable attributes: `display_name`, `defined_tags`, `freeform_tags`, `kms_key_id`, `are_quota_rules_enabled`, `clone_attach_status`, `detach_clone_trigger`, `filesystem_snapshot_policy_id`, `is_lock_override`, `source_snapshot_id`
- Optional nested blocks: `locks`, `timeouts`
- Computed-only attributes include clone counts, lifecycle state, metered bytes, quota enforcement state, replication metadata, source details, system tags, and timestamps.

Sprint 5 will not expose computed-only attributes as inputs. It may expose selected computed values as outputs when useful for tests and operators.

## PBI-007. FSS module - expose kms_key_id argument at mandatory variables

Status: Accepted

### Requirement

The Sprint 5 filesystem module must require a `kms_key_id` input and pass it to `oci_file_storage_file_system.this.kms_key_id`.

### Design

Sprint 5 integration must create or ensure a dedicated FSS master encryption key (MEK) in the Sprint 1 foundation Vault before applying filesystems. The MEK state will live under `progress/sprint_5/scaffold/fss-mek/` so it is recoverable and follows `RUP_patch.md` P7. The test setup will reuse the Sprint 1 Vault OCID and management endpoint, then run the oci_scaffold KMS key ensure flow with a Sprint 5-specific prefix such as `sprint5-fss-mek`.

OCI File Storage customer-managed key usage also requires IAM access for File Storage resource principals. The Sprint 5 integration harness will ensure a dynamic group for filesystems in the Sprint 1 compartment and will call `oci_scaffold/resource/ensure-iam_policy.sh` with explicit statements that grant that dynamic group and the realm-specific File Storage service principal access to use keys in the key compartment.

Create `terraform/modules/fss_sprint5_filesystem` with mandatory variables:

- `compartment_ocid`
- `availability_domain`
- `display_name`
- `kms_key_id`

`kms_key_id` will not have a default. The integration test will prove Terraform validation fails when it is omitted.

### Acceptance

- Missing `kms_key_id` fails Terraform validation.
- Sprint 5 creates or ensures an FSS MEK in the Sprint 1 foundation Vault and records its OCID under Sprint 5 scaffold state.
- Sprint 5 ensures the IAM dynamic group and KMS-use policy required by OCI File Storage customer-managed keys.
- The Sprint 5 MEK OCID allows filesystem creation.
- Module output includes the filesystem OCID and the effective KMS key OCID.

## PBI-008. FSS module - expose rest of all available arguments at with default values

Status: Accepted

### Requirement

Expose remaining useful configurable filesystem arguments as optional variables while keeping mandatory and optional sections clearly marked in `variables.tf`. Extend Terraform agentic rules with the optional nested block pattern needed for provider blocks.

### Design

The Sprint 5 filesystem module will expose these optional variables:

- `are_quota_rules_enabled`, default `null`
- `clone_attach_status`, default `null`
- `detach_clone_trigger`, default `null`
- `filesystem_snapshot_policy_id`, default `null`
- `is_lock_override`, default `null`
- `source_snapshot_id`, default `null`
- `freeform_tags`, default `{}`
- `defined_tags`, default `{}`
- `locks`, default `[]`
- `timeouts`, default `null`

Optional scalar attributes will be assigned directly. Terraform omits `null` optional arguments for provider resources, preserving default behavior. Optional nested blocks will use dynamic blocks:

- `dynamic "locks"` over `var.locks`
- `dynamic "timeouts"` over `var.timeouts == null ? [] : [var.timeouts]`

The `locks` variable will be a list of objects with required `type` plus optional `message`, `related_resource_id`, and `time_created` fields. The `timeouts` variable will be an object with optional `create`, `update`, and `delete` strings.

`clone_attach_status` is optional/computed in the provider schema. Sprint 5 will expose it as an advanced pass-through variable with a `null` default to satisfy the broad interface requirement, but integration tests will not set it because the normal create path does not require it. The provider schema also reports `id` as optional/computed, but Terraform rejects it in resource configuration; Sprint 5 treats `id` as computed-only and exposes it through outputs as `filesystem_ocid`.

The module will keep the narrowly scoped lifecycle ignore for Oracle-managed defined tags:

```hcl
lifecycle {
  ignore_changes = [
    defined_tags["Oracle-Tags.CreatedBy"],
    defined_tags["Oracle-Tags.CreatedOn"],
  ]
}
```

### Acceptance

- Default module usage remains compatible with Sprint 3 behavior except for the new required `kms_key_id`.
- At least one optional attribute is proven in integration by applying a non-default value and checking output or plan/state evidence.
- Sprint 5 Terraform rules document describes optional nested block handling.

## PBI-009. Create higher level module that accepts map of arguments to support multiple FSS with all mount points and exports

Status: Accepted

### Requirement

Create a higher-level module that accepts map input and provisions multiple complete FSS entries with filesystems, mount targets, and exports.

### Design

Create `terraform/modules/fss_sprint5_stack`. It will accept:

- Mandatory shared variables: `compartment_ocid`, `availability_domain`, `subnet_ocid`, `kms_key_id`
- Optional shared variable: `default_source_cidr`
- Mandatory map variable: `filesystems`

`filesystems` will be a map keyed by stable operator-chosen names. Each value will include:

- `filesystem_display_name`
- `export_path`
- Optional `mount_target_display_name`; when omitted, the stack module generates a stable display name from the map key
- Optional `source_cidr`; when omitted, the stack module uses `var.default_source_cidr`
- Optional filesystem arguments forwarded to `fss_sprint5_filesystem`
- Optional mount target arguments forwarded to Sprint 4 mount target module
- Optional export option arguments forwarded to Sprint 4 export module

The stack module will use `for_each = var.filesystems` for all per-entry modules. It will wire:

- `module.filesystem[each.key].filesystem_ocid` into the export module
- `module.mount_target[each.key].mount_target_export_set_ocid` into the export module

Generated mount target display names will use a deterministic pattern such as `fss-mt-${each.key}`. This keeps the operator-facing input small while preserving stable Terraform plans.

At least one source CIDR must be available for every export: either the per-entry `source_cidr` or the optional shared `default_source_cidr`. The module will validate that an effective source CIDR can be resolved before planning export resources.

Outputs will be maps keyed by the same stable keys:

- `filesystem_ocids`
- `mount_target_ocids`
- `mount_target_export_set_ocids`
- `mount_target_mount_addresses`
- `export_ocids`
- `export_paths`
- `nfs_mount_sources`

The `nfs_mount_sources` output is the operator-facing mount string in `<mount-address>:<export-path>` form. `mount-address` uses the mount target FQDN when available and falls back to the private IP address.

### Acceptance

- Integration apply creates at least two entries from one map input.
- Outputs contain both map keys and non-empty identifiers.
- Generated Terraform root is preserved under `progress/sprint_5/generated_tf/`.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Missing mandatory KMS key fails

- **Preconditions:** Terraform CLI and OCI provider available.
- **Steps:** Generate a root module using `fss_sprint5_filesystem` without `kms_key_id`; run `terraform init` and `terraform validate`.
- **Expected Outcome:** Validation fails because `kms_key_id` is required.
- **Verification:** Test passes only when validation returns non-zero and output mentions the missing argument.
- **Target file:** `tests/integration/test_fss_sprint5_tf.sh`

#### IT-2: Filesystem applies with Sprint 5 MEK and optional argument

- **Preconditions:** Sprint 1 foundation state contains compartment OCID, Vault OCID, and Vault management endpoint.
- **Steps:** Ensure a Sprint 5 FSS MEK in the Sprint 1 Vault, generate a root module using `fss_sprint5_filesystem`, pass the Sprint 5 MEK OCID, set at least one optional argument such as `freeform_tags`, then run plan/apply/output/destroy.
- **Expected Outcome:** Filesystem is created with non-empty OCID and effective KMS key output.
- **Verification:** Terraform outputs include `filesystem_ocid` and `kms_key_id`; tag or optional argument evidence is captured in artifacts.
- **Target file:** `tests/integration/test_fss_sprint5_tf.sh`

#### IT-3: Stack module creates multiple FSS entries from map input

- **Preconditions:** Sprint 1 foundation state contains compartment OCID, subnet OCID, subnet CIDR, Vault OCID, and Vault management endpoint.
- **Steps:** Ensure a Sprint 5 FSS MEK in the Sprint 1 Vault, generate a root module using `fss_sprint5_stack` with two map entries and the Sprint 5 MEK OCID; run plan/apply/output/destroy.
- **Expected Outcome:** Two filesystems, two mount targets, and two exports are created.
- **Verification:** Output maps include exactly the requested keys and non-empty OCIDs/export paths.
- **Target file:** `tests/integration/test_fss_sprint5_tf.sh`

### Traceability

| Backlog Item | Integration Tests |
|--------------|-------------------|
| PBI-007 | IT-1, IT-2, IT-3 |
| PBI-008 | IT-2 |
| PBI-009 | IT-3 |

## Quality Gates

After managed-mode construction approval:

- A3 new-code integration: `tests/run.sh --integration --new-only progress/sprint_5/new_tests.manifest`
- B3 integration regression: `tests/run.sh --integration`

Every gate run must write a timestamped log under `progress/sprint_5/`.

## Skeleton Verification

The integration skeletons were executed before construction and failed red as expected because implementation is pending design approval.

- Log: `progress/sprint_5/test_run_skeleton_red_20260428_085437.log`
- Summary: `pass=0 fail=3`
