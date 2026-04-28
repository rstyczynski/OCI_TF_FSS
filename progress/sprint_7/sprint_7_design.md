# Sprint 7 - Design

Status: Proposed

## PBI-019. Refactor stack filesystem variable

Status: Proposed

### Requirement

Replace the Sprint 5 stack's flat `filesystems` variable (one entry = one filesystem + one mount target + one export) with two independent map variables — `mount_targets` and `filesystems` — where each filesystem carries a nested `exports` map and each export references a mount target by stable key. The new module lives at `terraform/modules/fss_sprint7_stack`. The existing `fss_sprint5_stack` module is not modified.

### Module structure

```
terraform/modules/fss_sprint7_stack/
  variables.tf
  main.tf
  outputs.tf
  versions.tf
```

The module reuses the three lower-level modules from earlier sprints:

- `../fss_sprint5_filesystem` — filesystem resource
- `../fss_sprint4_mount_target` — mount target resource
- `../fss_sprint4_export` — export resource

**Additive change to `fss_sprint4_export`:** add `identity_squash` as an output so the stack can read the OCI-applied value rather than echoing the input variable. This is backward compatible — no existing outputs change.

```hcl
# terraform/modules/fss_sprint4_export/outputs.tf (addition)
output "identity_squash" {
  description = "Identity squash mode applied to the export option."
  value       = oci_file_storage_export.this.export_options[0].identity_squash
}
```

### Variables

**Shared mandatory variables** (same as Sprint 5 stack):

```hcl
variable "compartment_ocid"    { type = string }
variable "availability_domain" { type = string }
variable "subnet_ocid"         { type = string }
variable "kms_key_id"          { type = string }
```

**Shared optional variable:**

```hcl
variable "default_source_cidr" {
  type    = string
  default = null
}
```

**New first-class `mount_targets` variable:**

```hcl
variable "mount_targets" {
  description = "Map of mount targets keyed by stable operator names."
  type = map(object({
    display_name   = optional(string)
    hostname_label = optional(string)
    nsg_ids        = optional(list(string))
    freeform_tags  = optional(map(string), {})
    defined_tags   = optional(map(string), {})
  }))
  default = {}
}
```

**Refactored `filesystems` variable with nested `exports`:**

```hcl
variable "filesystems" {
  description = "Map of filesystem entries keyed by stable operator names."
  type = map(object({
    display_name  = string
    freeform_tags = optional(map(string), {})
    defined_tags  = optional(map(string), {})
    exports = optional(map(object({
      mount_target_key               = string
      path                           = string
      source                         = optional(string, null)
      access                         = optional(string, "READ_WRITE")
      allowed_auth                   = optional(list(string), ["SYS"])
      identity_squash                = optional(string, "ROOT")
      anonymous_uid                  = optional(number, 65534)
      anonymous_gid                  = optional(number, 65534)
      is_anonymous_access_allowed    = optional(bool, false)
      require_privileged_source_port = optional(bool, false)
    })), {})
  }))
  default = {}
}
```

### `for_each` flattening pattern

The nested `exports` map inside `filesystems` prevents direct iteration with `for_each`. A local value flattens all `(filesystem_key, export_key)` pairs into a map keyed by a stable composite string `"${fs_key}__${export_key}"`.

```hcl
locals {
  exports_flat = merge([
    for fs_key, fs in var.filesystems : {
      for export_key, export in fs.exports :
      "${fs_key}__${export_key}" => {
        fs_key     = fs_key
        export_key = export_key
        export     = export
      }
    }
  ]...)

  effective_sources = {
    for composite_key, pair in local.exports_flat :
    composite_key => coalesce(pair.export.source, var.default_source_cidr)
  }
}
```

The `__` separator is chosen because OCI display names and map keys do not use double underscores, making the composite key unambiguous to parse for debugging.

`mount_target_key` validation happens at plan time: Terraform will error with a descriptive message when `module.mount_target[pair.export.mount_target_key]` is indexed with a key that does not exist in `var.mount_targets`. No additional `precondition` is required for this sprint.

### `main.tf` structure

```hcl
module "mount_target" {
  for_each = var.mount_targets

  source = "../fss_sprint4_mount_target"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid
  display_name        = coalesce(each.value.display_name, "fss-mt-${each.key}")
  hostname_label      = each.value.hostname_label
  nsg_ids             = each.value.nsg_ids
}

module "filesystem" {
  for_each = var.filesystems

  source = "../fss_sprint5_filesystem"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = each.value.display_name
  kms_key_id          = var.kms_key_id
  freeform_tags       = each.value.freeform_tags
  defined_tags        = each.value.defined_tags
}

module "export" {
  for_each = local.exports_flat

  source = "../fss_sprint4_export"

  export_set_ocid  = module.mount_target[each.value.export.mount_target_key].mount_target_export_set_ocid
  file_system_ocid = module.filesystem[each.value.fs_key].filesystem_ocid
  path             = each.value.export.path
  source_cidr      = local.effective_sources[each.key]

  access                         = each.value.export.access
  allowed_auth                   = each.value.export.allowed_auth
  identity_squash                = each.value.export.identity_squash
  anonymous_uid                  = each.value.export.anonymous_uid
  anonymous_gid                  = each.value.export.anonymous_gid
  is_anonymous_access_allowed    = each.value.export.is_anonymous_access_allowed
  require_privileged_source_port = each.value.export.require_privileged_source_port
}
```

### Outputs

The Sprint 5 TF rule requires both composite and atomic outputs for map-based modules.

**Composite `mount_targets` output** (keyed by mount target key):

```hcl
output "mount_targets" {
  value = {
    for key, mt in module.mount_target : key => {
      mount_target_ocid            = mt.mount_target_ocid
      mount_target_display_name    = mt.mount_target_display_name
      mount_target_export_set_ocid = mt.mount_target_export_set_ocid
      mount_target_private_ip_ids  = mt.mount_target_private_ip_ids
      availability_domain          = var.availability_domain
      subnet_ocid                  = var.subnet_ocid
      compartment_ocid             = var.compartment_ocid
    }
  }
}
```

**Composite `filesystems` output** (keyed by filesystem key, with nested export summaries):

```hcl
output "filesystems" {
  value = {
    for fs_key, fs in module.filesystem : fs_key => {
      filesystem_ocid         = fs.filesystem_ocid
      filesystem_display_name = fs.filesystem_display_name
      kms_key_id              = var.kms_key_id
      compartment_ocid        = var.compartment_ocid
      availability_domain     = var.availability_domain
      exports = {
        for composite_key, pair in local.exports_flat :
        pair.export_key => {
          export_ocid      = module.export[composite_key].export_ocid
          path             = module.export[composite_key].export_path
          mount_target_key = pair.export.mount_target_key
          identity_squash  = module.export[composite_key].identity_squash
          nfs_mount_source = format(
            "%s:%s",
            module.mount_target[pair.export.mount_target_key].mount_target_mount_address,
            module.export[composite_key].export_path
          )
        }
        if pair.fs_key == fs_key
      }
    }
  }
}
```

**Atomic outputs:**

```hcl
output "mount_target_ocids"   # map(string) keyed by mount_target key
output "filesystem_ocids"     # map(string) keyed by filesystem key
output "export_paths"         # map(string) keyed by composite key "fs__export"
output "nfs_mount_sources"    # map(string) keyed by composite key "fs__export"
```

### Acceptance criteria

- `terraform validate` succeeds for a well-formed config with both `mount_targets` and `filesystems`.
- `terraform apply` creates N mount targets and M filesystems with their respective exports; the `filesystems` composite output contains the correct nested export map.
- Adding or removing one filesystem or export entry does not affect resources for other entries (stable `for_each` keys).
- Removing a mount target that is still referenced by an export fails at plan time with a clear Terraform error.

---

## Test Specification

Sprint Test Configuration:

- Test: integration
- Regression: none
- Mode: managed

### Integration Tests

#### IT-1: New variable structure passes static validation

- **Preconditions:** Terraform CLI and OCI provider available; no OCI credentials needed.
- **Steps:** Write a root module using `fss_sprint7_stack` with two `mount_targets` entries and two `filesystems` entries (one filesystem has two exports referencing different mount targets, one has one export). Run `terraform init` and `terraform validate`.
- **Expected Outcome:** `terraform validate` exits 0 with "Success! The configuration is valid."
- **Verification:** Non-zero exit or error output fails the test.
- **Target file:** `tests/integration/test_fss_sprint7_tf.sh`

#### IT-2: Stack applies with cross-referenced mount targets and filesystems

Topology: 2 mount targets × 2 filesystems × 2 exports each = 4 exports total. Every mount target serves both filesystems (true M:N). `identity_squash` is varied per export to produce assertable differences in the composite output.

| Resource | Mount target | Path | `identity_squash` |
|---|---|---|---|
| `fs_alpha / export_to_primary` | `mt_primary` | `/sprint7-alpha-primary` | `ROOT` (default) |
| `fs_alpha / export_to_secondary` | `mt_secondary` | `/sprint7-alpha-secondary` | `NONE` |
| `fs_beta / export_to_primary` | `mt_primary` | `/sprint7-beta-primary` | `NONE` |
| `fs_beta / export_to_secondary` | `mt_secondary` | `/sprint7-beta-secondary` | `ROOT` (explicit) |

- **Preconditions:** Sprint 1 foundation state contains compartment OCID, subnet OCID, subnet CIDR, Vault OCID, and Vault management endpoint. Sprint 5 FSS MEK must be available (reuses Sprint 5 MEK ensure helper).
- **Steps:** Generate the root module with the topology above. Run plan/apply/output. Assert outputs. Run destroy.
- **Expected Outcome:** 2 mount targets, 2 filesystems, 4 exports created. `filesystems` composite output has nested `exports` with 2 entries per filesystem. `nfs_mount_sources` contains 4 composite keys. `identity_squash` values in the nested export summary match the configured values.
- **Verification:** `jq` assertions check: both mount target OCIDs non-empty; both filesystem OCIDs non-empty; `nfs_mount_sources` length == 4; `fs_alpha.exports.export_to_secondary.identity_squash == "NONE"`; `fs_beta.exports.export_to_primary.identity_squash == "NONE"`; all `nfs_mount_source` strings match `<addr>:<path>` pattern.
- **Target file:** `tests/integration/test_fss_sprint7_tf.sh`

### Traceability

| Backlog Item | Integration Tests |
|---|---|
| PBI-019 | IT-1, IT-2 |

### Quality Gates

After managed-mode PO approval (P6, RUP_patch.md):

- A3 new-code integration: `tests/run.sh --integration --new-only progress/sprint_7/new_tests.manifest`

No regression gate (PLAN.md: `Regression: none`).

Every gate run must write a timestamped log under `progress/sprint_7/`.

### Skeleton Verification

Test skeletons must be run and confirmed red (fail=2, pass=0) before construction begins. Log saved to `progress/sprint_7/test_run_skeleton_red_<TS>.log`.
