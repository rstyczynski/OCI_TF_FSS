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
