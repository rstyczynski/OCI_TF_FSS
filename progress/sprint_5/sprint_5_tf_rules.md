# Sprint 5 - Terraform Agentic Rules

Sprint 5 keeps the Sprint 4 Terraform rules and adds guidance for optional provider nested blocks.

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
