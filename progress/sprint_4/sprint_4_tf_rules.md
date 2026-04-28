# Sprint 4 - Terraform Agentic Rules

Sprint 4 keeps the Sprint 3 default module rules and adds an explicit rule for generated Terraform test roots.

## Default module rules

- Prefer required inputs for resource identity and replacement-driving values.
- Do not hide replacement-driving choices behind random defaults.
- Do not derive resource names from `name_prefix` unless the sprint explicitly asks for a naming abstraction.
- Use stable, descriptive outputs.
- Keep provider/data-source use in modules minimal; avoid data lookups whose only purpose is to compensate for hidden defaults.
- Prefer resource lifecycle handling for known provider-injected metadata drift when it can be scoped to exact keys.

## Generated Terraform test roots

- Integration tests that generate Terraform code must write the generated root module under the sprint home directory in a visible, reviewable location.
- Do not put generated reviewable Terraform source only under ignored state directories such as `progress/sprint_N/tf_state/`.
- Keep generated `main.tf` files available for operator review after the test run.
- Ignore only runtime byproducts: `.terraform/`, `terraform.tfstate*`, binary plans, provider lock files when generated only for test roots, and test artifact directories.
- Terraform execution can use the same generated root directory, but cleanup must not delete the generated `main.tf`.

For Sprint 4, generated Terraform roots live under:

```text
progress/sprint_4/generated_tf/<test_id>/main.tf
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
