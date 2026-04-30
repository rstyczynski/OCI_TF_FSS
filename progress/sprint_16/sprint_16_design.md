# Sprint 16 - Design

Status: Accepted

Mode: YOLO

## PBI-030. Replace sprint-15-specific intermediate modules with fss_stack_sprint12

### Feasibility

`fss_stack_sprint12` interface (from `terraform/modules/fss_stack_sprint12/variables.tf`):

- `compartment_ocid`, `subnet_ocid` — mandatory
- `availability_domain` — optional (auto-detected when null)
- `kms_key_id` — optional
- `default_source_cidr` — optional
- `mount_targets` — map of mount target configs (display_name, hostname_label, nsg_ids, freeform_tags, defined_tags, logging)
- `filesystems` — map of filesystem configs with nested `exports` map

Passing `filesystems = {}` creates no filesystems and no exports. This makes `fss_stack_sprint12` usable for mount-target-only creation.

`fss_stack_sprint12` outputs (relevant ones): `mount_targets` (compound), `mount_target_ocids`, `mount_target_ip_addresses`, `mount_target_mount_addresses`, `mount_target_log_group_ocids`, `mount_target_log_ocids`.

Sub-module interfaces (used directly by `filesystem_export/`):

- `fss_stack_sprint12/modules/fss_filesystem/` — inputs: `compartment_ocid`, `availability_domain`, `display_name`, `kms_key_id`, `freeform_tags`, `defined_tags`; output: `filesystem_ocid`, `filesystem_display_name`
- `fss_stack_sprint12/modules/fss_export/` — inputs: `export_set_ocid`, `file_system_ocid`, `path`, `source_cidr`, `access`, `identity_squash`, `anonymous_uid`, `anonymous_gid`, `is_anonymous_access_allowed`, `require_privileged_source_port`; output: `export_ocid`, `export_path`

### Stack 1: mount_target/

**New `modules/` layout:**

```
mount_target/
  modules/
    fss_stack_sprint12/          ← verbatim copy of terraform/modules/fss_stack_sprint12/
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
  source = "./modules/fss_stack_sprint12"

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

**Logging resources removed from root:** logging is handled inside `fss_stack_sprint12`. Root retains only tag slot logic and `validate_tags`.

### Stack 2: filesystem_export/

`fss_stack_sprint12` always creates new mount targets. The `filesystem_export/` stack needs to create only filesystem + exports against an EXISTING mount target. Therefore the root cannot call the full `fss_stack_sprint12` module. It calls the `fss_filesystem` and `fss_export` sub-modules directly from within the embedded `fss_stack_sprint12/modules/` tree.

**New `modules/` layout:**

```
filesystem_export/
  modules/
    fss_stack_sprint12/          ← verbatim copy of terraform/modules/fss_stack_sprint12/
      main.tf
      variables.tf
      outputs.tf
      versions.tf
      modules/
        fss_mount_target/
        fss_filesystem/
        fss_export/
```

**Updated `filesystem_export/main.tf` module calls:**

```hcl
module "filesystem" {
  source = "./modules/fss_stack_sprint12/modules/fss_filesystem"

  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = var.filesystem_display_name
  kms_key_id          = local.kms_key_id
  freeform_tags       = local.tag_pair_freeform_tags
  defined_tags        = {}

  depends_on = [terraform_data.validate_tags]
}

module "export" {
  for_each = local.enabled_exports_for_module
  source   = "./modules/fss_stack_sprint12/modules/fss_export"

  export_set_ocid  = local.selected_mount_target.export_set_id
  file_system_ocid = module.filesystem.filesystem_ocid
  path             = each.value.path
  source_cidr      = each.value.source_cidr
  access           = each.value.access
  identity_squash  = each.value.identity_squash
  anonymous_uid    = var.anonymous_uid
  anonymous_gid    = var.anonymous_gid
  is_anonymous_access_allowed    = false
  require_privileged_source_port = var.require_privileged_source_port

  depends_on = [terraform_data.validate_exports]
}
```

Where `local.enabled_exports_for_module` strips the `enabled` flag from each slot (already filtered).

**`filesystem_export/outputs.tf` updated references:**

- `filesystem_ocid` ← `module.filesystem.filesystem_ocid`
- `filesystem_display_name` ← `module.filesystem.filesystem_display_name`
- `export_ocids` ← `{ for key, exp in module.export : key => exp.export_ocid }`
- `export_paths` ← `{ for key, exp in module.export : key => exp.export_path }`
- `nfs_mount_sources` ← `{ for key, exp in module.export : key => "${local.mount_address}:${exp.export_path}" }`
- mount target outputs ← unchanged (from `local.selected_mount_target`)

### Zip packaging

Both zips now include `modules/fss_stack_sprint12/` (the full verbatim copy including its own `modules/` subdirectory). The `mount_target` zip will have approximately the same file count as Sprint 13's zip. The `filesystem_export` zip will also include the full `fss_stack_sprint12/` tree even though only its sub-modules are called.

### Test Specification

#### SM-1: Advanced ORM package static validation (existing, reuse)

Pass criteria unchanged. The module path prefix changes (`fss_stack_sprint12/` instead of sprint-15-specific names) but the smoke test only checks root files, schema, and `terraform validate` — all of which are unaffected.

#### IT-1: Resource Manager advanced workflow (existing, reuse)

Pass criteria unchanged. End-to-end ORM apply/destroy cycle verifies runtime correctness.

Both tests are in `tests/smoke/test_fss_sprint15_orm_advanced.sh` and `tests/integration/test_fss_sprint15_orm_advanced.sh` — no modifications needed.
