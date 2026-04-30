# Sprint 16 - Design

Status: Accepted

Mode: YOLO

## PBI-030. Replace sprint-15-specific intermediate modules with fss_stack_sprint17

### Feasibility

Product Owner update: use `fss_stack_sprint17` instead of `fss_stack_sprint12` because Sprint 17 contains the improved stack behavior for externally managed mount targets and per-mount-target placement overrides.

`fss_stack_sprint17` interface (from `terraform/modules/fss_stack_sprint17/variables.tf`):

- `compartment_ocid`, `subnet_ocid` — mandatory
- `availability_domain` — optional (auto-detected when null)
- `kms_key_id` — optional
- `default_source_cidr` — optional
- `mount_targets` — map of mount target configs (optional `subnet_ocid`, optional `availability_domain`, optional `external_ocid`, display_name, hostname_label, nsg_ids, freeform_tags, defined_tags, logging)
- `filesystems` — map of filesystem configs with nested `exports` map

Passing `filesystems = {}` creates no filesystems and no exports. This makes `fss_stack_sprint17` usable for mount-target-only creation.

`fss_stack_sprint17` outputs (relevant ones): `mount_targets` (compound), `mount_target_ocids`, `mount_target_ip_addresses`, `mount_target_mount_addresses`, `mount_target_log_group_ocids`, `mount_target_log_ocids`, `filesystems`, `filesystem_ocids`, `export_paths`, `nfs_mount_sources`, `effective_availability_domain`.

Compatibility changes required to accept Sprint 17:

- Create the Sprint 16 Resource Manager product at `terraform/modules/fss_stack_sprint16_orm_advanced/`; do not modify the failed Sprint 15 product directory.
- Replace embedded directories with verbatim copies of `terraform/modules/fss_stack_sprint17/`, not `fss_stack_sprint12/`.
- Update root `source` paths from sprint-15-specific modules to `./modules/fss_stack_sprint17`.
- Keep root ORM variable-shaping and validation logic in place.
- For `mount_target/`, pass a single managed `mount_targets.primary` entry and `filesystems = {}`.
- For `filesystem_export/`, call the full `fss_stack_sprint17` module with `mount_targets.existing.external_ocid = var.existing_mount_target_ocid`; do not call `fss_filesystem` and `fss_export` submodules directly.
- Pass `mount_targets.existing.subnet_ocid = local.selected_mount_target.subnet_id` and `mount_targets.existing.availability_domain = var.availability_domain` so Sprint 17 external mount target validation has the exact placement values for the selected mount target.
- Convert enabled export slots into one filesystem entry with nested exports, all using `mount_target_key = "existing"`.
- Update outputs to read from Sprint 17 compound maps and composite export keys (`filesystem__export_1`, etc.), while preserving the external shape expected by the Resource Manager stack outputs.

### Product: terraform/modules/fss_stack_sprint16_orm_advanced/

Sprint 16 ships a new ORM package directory rather than rewriting `terraform/modules/fss_stack_sprint15_orm_advanced/`. The Sprint 15 package remains as historical failed sprint output; Sprint 16 contains the corrected implementation.

### Stack 1: mount_target/

**New `modules/` layout:**

```
mount_target/
  modules/
    fss_stack_sprint17/          ← verbatim copy of terraform/modules/fss_stack_sprint17/
      main.tf
      variables.tf
      outputs.tf
      versions.tf
      modules/
        fss_mount_target/
        fss_filesystem/
        fss_export/
```

**Updated `mount_target/main.tf` module call:**

```hcl
module "fss_stack" {
  source = "./modules/fss_stack_sprint17"

  compartment_ocid    = var.compartment_ocid
  subnet_ocid         = var.subnet_ocid
  availability_domain = var.availability_domain

  mount_targets = {
    primary = {
      display_name   = var.mount_target_display_name
      hostname_label = local.hostname_label
      nsg_ids        = local.nsg_ids
      freeform_tags  = local.tag_pair_freeform_tags
      defined_tags   = {}
      logging = var.enable_mount_target_logging ? {
        enabled            = true
        log_group_id       = local.log_group_id
        log_group_name     = var.log_group_name
        log_display_name   = var.log_display_name
        retention_duration = var.log_retention_duration
        freeform_tags      = local.tag_pair_freeform_tags
        defined_tags       = {}
      } : null
    }
  }

  filesystems = {}

  depends_on = [terraform_data.validate_tags]
}
```

**`mount_target/outputs.tf` updated references:**

- `mount_target_ocid` ← `module.fss_stack.mount_target_ocids["primary"]`
- `export_set_ocid` ← `module.fss_stack.mount_targets["primary"].export_set_ocid`
- `mount_address` ← `module.fss_stack.mount_target_mount_addresses["primary"]`
- `ip_address` ← `module.fss_stack.mount_target_ip_addresses["primary"]`
- `logging` ← constructed from `module.fss_stack.mount_target_log_group_ocids` / `mount_target_log_ocids`
- `availability_domain` ← `module.fss_stack.effective_availability_domain`
- `subnet_ocid` ← `var.subnet_ocid`

**Logging resources removed from root:** logging is handled inside `fss_stack_sprint17`. Root retains only tag slot logic and `validate_tags`.

### Stack 2: filesystem_export/

`fss_stack_sprint17` supports externally managed mount targets via `mount_targets[*].external_ocid`. The `filesystem_export/` stack can therefore call the full stack module instead of bypassing it through submodules.

**New `modules/` layout:**

```
filesystem_export/
  modules/
    fss_stack_sprint17/          ← verbatim copy of terraform/modules/fss_stack_sprint17/
      main.tf
      variables.tf
      outputs.tf
      versions.tf
      modules/
        fss_mount_target/
        fss_filesystem/
        fss_export/
```

**Updated `filesystem_export/main.tf` module call:**

```hcl
module "fss_stack" {
  source = "./modules/fss_stack_sprint17"

  compartment_ocid    = var.compartment_ocid
  subnet_ocid         = local.selected_mount_target.subnet_id
  availability_domain = var.availability_domain
  kms_key_id          = local.kms_key_id
  default_source_cidr = var.default_source_cidr

  mount_targets = {
    existing = {
      external_ocid       = var.existing_mount_target_ocid
      subnet_ocid         = local.selected_mount_target.subnet_id
      availability_domain = var.availability_domain
    }
  }

  filesystems = {
    filesystem = {
      display_name  = var.filesystem_display_name
      freeform_tags = local.tag_pair_freeform_tags
      defined_tags  = {}
      exports = {
        for key, slot in local.enabled_exports : key => {
          mount_target_key               = "existing"
          path                           = slot.path
          source                         = slot.source_cidr
          access                         = slot.access
          identity_squash                = slot.identity_squash
          anonymous_uid                  = var.anonymous_uid
          anonymous_gid                  = var.anonymous_gid
          is_anonymous_access_allowed    = false
          require_privileged_source_port = var.require_privileged_source_port
        }
      }
    }
  }

  depends_on = [terraform_data.validate_exports, terraform_data.validate_tags]
}
```

`local.selected_mount_target.subnet_id` is used for both the module default `subnet_ocid` and the external mount target entry. This avoids a mismatch if the selected mount target is not in the same subnet the operator would otherwise pass as a default.

**`filesystem_export/outputs.tf` updated references:**

- `filesystem_ocid` ← `module.fss_stack.filesystem_ocids["filesystem"]`
- `filesystem_display_name` ← `module.fss_stack.filesystems["filesystem"].filesystem_display_name`
- `export_ocids` ← `{ for key, exp in module.fss_stack.filesystems["filesystem"].exports : key => exp.export_ocid }`
- `export_paths` ← `{ for key, exp in module.fss_stack.filesystems["filesystem"].exports : key => exp.path }`
- `nfs_mount_sources` ← `{ for key, exp in module.fss_stack.filesystems["filesystem"].exports : key => exp.nfs_mount_source }`
- mount target outputs ← unchanged (from `local.selected_mount_target`)

### Zip packaging

Both zips now include `modules/fss_stack_sprint17/` (the full verbatim copy including its own `modules/` subdirectory). The `mount_target` zip and the `filesystem_export` zip both use the full module entry point.

### Test Specification

#### SM-1: Advanced ORM package static validation (existing, reuse)

Pass criteria unchanged. The module path prefix changes (`fss_stack_sprint17/` instead of sprint-15-specific names) and the package directory changes to `terraform/modules/fss_stack_sprint16_orm_advanced/`.

#### IT-1: Resource Manager advanced workflow (existing, reuse)

Pass criteria unchanged. End-to-end ORM apply/destroy cycle verifies runtime correctness.

Sprint 16 uses copied Sprint 16-specific test scripts in `tests/smoke/test_fss_sprint16_orm_advanced.sh` and `tests/integration/test_fss_sprint16_orm_advanced.sh` so generated artifacts land under `progress/sprint_16/generated_tf/` and the historical Sprint 15 tests remain unchanged.
