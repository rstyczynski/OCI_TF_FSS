# Sprint 3 - Terraform Agentic Rules

Sprint 3 updates the Sprint 2 Terraform rules to prefer explicit, ordinary Terraform module interfaces by default. Experimental patterns remain documented, but they are only used when the Product Owner clearly requests them.

## Default module rules

- Prefer required inputs for resource identity and replacement-driving values.
- Do not hide replacement-driving choices behind random defaults.
- Do not derive resource names from `name_prefix` unless the sprint explicitly asks for a naming abstraction.
- Use stable, descriptive outputs.
- Keep provider/data-source use in modules minimal; avoid data lookups whose only purpose is to compensate for hidden defaults.
- Prefer resource lifecycle handling for known provider-injected metadata drift when it can be scoped to exact keys.

## OCI Oracle-managed tags

OCI may inject Oracle-managed defined tags such as:

- `Oracle-Tags.CreatedBy`
- `Oracle-Tags.CreatedOn`

For Sprint 3 modules, handle those with a narrowly scoped lifecycle ignore:

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
