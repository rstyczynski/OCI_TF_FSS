# Sprint 17 - Terraform Agentic Rules

Sprint 17 carries forward the latest Terraform rules from Sprint 5 and adds guidance for OCI resources whose display names are unique within a scope.

## Default module rules

- Prefer required inputs for resource identity and replacement-driving values.
- Do not hide replacement-driving choices behind random defaults.
- Do not derive resource names from `name_prefix` unless the sprint explicitly asks for a naming abstraction.
- Use stable, descriptive outputs.
- Keep provider/data-source use in modules minimal; avoid data lookups whose only purpose is to compensate for hidden defaults.
- Prefer resource lifecycle handling for known provider-injected metadata drift when it can be scoped to exact keys.
- Keep mandatory and optional variables in clearly marked sections in `variables.tf`.

## Optional provider attributes

- Optional scalar provider arguments should default to `null` when omission preserves current behavior.
- Optional collection arguments should default to an empty collection only when the provider can safely receive that empty collection and it matches previous behavior.
- Do not invent defaults for provider features that change resource semantics.

## Optional nested blocks

Provider nested blocks cannot always be assigned as `null` directly. Use dynamic blocks to omit the block when the caller does not configure it.

For zero-or-more nested blocks:

```hcl
dynamic "locks" {
  for_each = var.locks

  content {
    type                = locks.value.type
    message             = try(locks.value.message, null)
    related_resource_id = try(locks.value.related_resource_id, null)
    time_created        = try(locks.value.time_created, null)
  }
}
```

For optional single nested blocks:

```hcl
dynamic "timeouts" {
  for_each = var.timeouts == null ? [] : [var.timeouts]

  content {
    create = try(timeouts.value.create, null)
    update = try(timeouts.value.update, null)
    delete = try(timeouts.value.delete, null)
  }
}
```

Add variable validation when a nested block has provider-required fields.

## Generated Terraform test roots

- Integration tests that generate Terraform code must write the generated root module under the sprint home directory in a visible, reviewable location.
- Do not put generated reviewable Terraform source only under ignored state directories such as `progress/sprint_N/tf_state/`.
- Keep generated `main.tf` files available for operator review after the test run.
- Ignore only runtime byproducts: `.terraform/`, `terraform.tfstate*`, binary plans, provider lock files when generated only for test roots, and test artifact directories.
- Terraform execution can use the same generated root directory, but cleanup must not delete the generated `main.tf`.

For Sprint 5, generated Terraform roots live under:

```text
progress/sprint_5/generated_tf/<test_id>/main.tf
```

## Composite outputs for map-based modules

For modules that accept a map and create a repeated stack of related resources, provide both:

- atomic map outputs for stable Terraform references between modules
- one composite map output for operator inventory and JSON review

Atomic outputs should remain simple and narrowly named, such as `filesystem_ocids` or `export_paths`. The composite output should preserve the same input map keys and group the useful per-entry values into one object:

```hcl
output "filesystems" {
  description = "Complete FSS stack outputs keyed by input map key."
  value = {
    for key in keys(var.filesystems) : key => {
      filesystem_ocid         = module.filesystem[key].filesystem_ocid
      filesystem_display_name = module.filesystem[key].filesystem_display_name
      kms_key_id              = var.kms_key_id

      mount_target_ocid            = module.mount_target[key].mount_target_ocid
      mount_target_display_name    = module.mount_target[key].mount_target_display_name
      mount_target_export_set_ocid = module.mount_target[key].mount_target_export_set_ocid
      mount_target_private_ip_ids  = module.mount_target[key].mount_target_private_ip_ids
      mount_target_ip_address      = module.mount_target[key].mount_target_ip_address
      mount_target_fqdn            = module.mount_target[key].mount_target_fqdn
      mount_target_mount_address   = module.mount_target[key].mount_target_mount_address

      export_ocid     = module.export[key].export_ocid
      export_set_ocid = module.export[key].export_set_ocid
      export_path     = module.export[key].export_path
      nfs_mount_source = format(
        "%s:%s",
        module.mount_target[key].mount_target_mount_address,
        module.export[key].export_path
      )
      source_cidr     = local.effective_source_cidrs[key]
    }
  }
}
```

Keep the composite output additive. Do not remove existing atomic outputs unless a sprint explicitly includes a breaking interface change.

For stacks that create mount targets and exports, expose a direct `nfs_mount_sources` atomic map as well. Consumers should not need to resolve OCI private IP OCIDs through the OCI CLI just to mount an export.

## OCI unique display names - lookup before create

Some OCI resources reject duplicate display names inside a scope. OCI Logging returns `409-Conflict` when creating a log group if another log group in the same compartment already uses the requested display name. Service logs have the same practical collision risk inside the chosen log group.

Rule: **When a module accepts a name for an OCI resource with scoped uniqueness, resolve an existing resource with that name before creating a new one.** Creation should happen only when no matching resource exists and the caller did not pass an explicit existing OCID.

For mount target logging, use this precedence:

- If `logging.log_group_id` is set, use that log group.
- Else, look up a log group in `var.compartment_ocid` with `display_name == logging.log_group_name`.
- If exactly one matching log group exists, use it.
- If no matching log group exists, create it.
- After the log group is resolved, look up an existing service log in that group with `display_name == logging.log_display_name`.
- If an existing log is found, use it only when its source configuration matches the expected File Storage NFS service log for the same mount target resource/category.
- If no matching log exists, create it.

Pattern:

```hcl
locals {
  logging_enabled_mount_targets = {
    for key, mt in var.mount_targets : key => mt
    if try(mt.logging.enabled, false)
  }
}

data "oci_logging_log_groups" "by_name" {
  for_each = {
    for key, mt in local.logging_enabled_mount_targets : key => mt
    if try(mt.logging.log_group_id, null) == null
  }

  compartment_id = var.compartment_ocid
  display_name   = coalesce(each.value.logging.log_group_name, "fss-${each.key}-logs")
}

locals {
  existing_log_group_ids = {
    for key, result in data.oci_logging_log_groups.by_name :
    key => try(one(result.log_groups).id, null)
  }

  log_groups_to_create = {
    for key, mt in local.logging_enabled_mount_targets : key => mt
    if try(mt.logging.log_group_id, null) == null
      && try(local.existing_log_group_ids[key], null) == null
  }
}

resource "oci_logging_log_group" "mount_target" {
  for_each = local.log_groups_to_create

  compartment_id = var.compartment_ocid
  display_name   = coalesce(each.value.logging.log_group_name, "fss-${each.key}-logs")
}

locals {
  resolved_log_group_ids = {
    for key, mt in local.logging_enabled_mount_targets :
    key => coalesce(
      try(mt.logging.log_group_id, null),
      try(local.existing_log_group_ids[key], null),
      try(oci_logging_log_group.mount_target[key].id, null)
    )
  }
}
```

Then apply the same lookup-before-create rule for `oci_logging_log`:

```hcl
data "oci_logging_logs" "by_name" {
  for_each = local.logging_enabled_mount_targets

  log_group_id = local.resolved_log_group_ids[each.key]
  display_name = coalesce(each.value.logging.log_display_name, "fss-${each.key}-nfs")
}

locals {
  existing_log_ids = {
    for key, result in data.oci_logging_logs.by_name :
    key => try(one(result.logs).id, null)
  }

  logs_to_create = {
    for key, mt in local.logging_enabled_mount_targets : key => mt
    if try(local.existing_log_ids[key], null) == null
  }
}

resource "terraform_data" "validate_existing_logs" {
  for_each = {
    for key, log_id in local.existing_log_ids : key => log_id
    if log_id != null
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for log in data.oci_logging_logs.by_name[each.key].logs :
        log.id != each.value || (
          log.log_type == "SERVICE"
          && log.configuration[0].source[0].service == "filestorage"
          && log.configuration[0].source[0].resource == module.mount_target[each.key].mount_target_ocid
          && log.configuration[0].source[0].category == "nfslogs"
        )
      ])
      error_message = "Existing logging log display name is already used for a different source; pass an explicit compatible log name or log group."
    }
  }
}

resource "oci_logging_log" "mount_target" {
  for_each = local.logs_to_create

  log_group_id = local.resolved_log_group_ids[each.key]
  display_name = coalesce(each.value.logging.log_display_name, "fss-${each.key}-nfs")
  log_type     = "SERVICE"

  configuration {
    source {
      source_type = "OCISERVICE"
      service     = "filestorage"
      resource    = module.mount_target[each.key].mount_target_ocid
      category    = "nfslogs"
    }
  }
}
```

Notes:

- Do not blindly reuse an existing service log just because the display name matches. Validate the existing source configuration first.
- If the OCI data source returns multiple matches where the service should guarantee uniqueness, fail fast rather than choosing arbitrarily.
- For resources that support explicit existing OCID inputs, explicit OCID wins over name lookup.
- The module output should expose the resolved OCID, regardless of whether the resource was created or reused.

## OCI Oracle-managed tags

OCI may inject Oracle-managed defined tags such as:

- `Oracle-Tags.CreatedBy`
- `Oracle-Tags.CreatedOn`

Handle those with a narrowly scoped lifecycle ignore:

```hcl
lifecycle {
  ignore_changes = [
    defined_tags["Oracle-Tags.CreatedBy"],
    defined_tags["Oracle-Tags.CreatedOn"],
  ]
}
```

Do not ignore all `defined_tags` by default; user-managed defined tags should remain visible to Terraform.

## Experimental patterns

Use these only on clear Product Owner request:

- AD randomization, including `random_shuffle` selection of an availability domain.
- Dynamic recognition or merge of Oracle-managed defined tags through data-source lookups.
- `name_prefix` derived display names.

When an experimental pattern is approved, the sprint design must state why the ordinary explicit-input approach is insufficient and how the behavior will be tested.
