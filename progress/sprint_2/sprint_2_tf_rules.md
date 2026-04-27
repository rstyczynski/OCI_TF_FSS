# Sprint 2 — Terraform Agentic Rules (Local)

This document enumerates the Terraform architecture and interface rules established in Sprint 2 (PBI-006). It is intended to be upstreamed into RUPStrikesBack rules/skills in a follow-up change set.

## Module structure and versioning

- Every module MUST include a `versions.tf` with:
  - `terraform.required_version` pinned to the minimum supported Terraform version for the repository
  - `required_providers` declared explicitly (provider sources)

## Inputs (variables) — required vs optional

- Prefer **required inputs** only for values that cannot be derived safely (example: `compartment_ocid`).
- If there is a safe, stable default, make the argument optional with `default = <value>`.
- If “unset” should change behavior (example: auto-select AD), use `default = null` and conditional selection.
- For optional maps (example: tags), use `default = {}`.

## Optional nested blocks

- For optional nested blocks, use `dynamic` blocks with `for_each`:
  - optional single block: `for_each = var.block == null ? [] : [var.block]`
  - optional repeated blocks: `for_each = var.blocks` with `default = []`
- Do not create “*_type” scalar variables for nested blocks (example: `locks.type`). Prefer structured variables (`object` / `list(object)`) so required fields are enforced by the type system.

## Outputs

- Always define module outputs explicitly.
- Output names MUST be stable and descriptive (example: `filesystem_ocid`, not `id`).
- Output values come from module resources/locals (never from ad-hoc CLI parsing).
- Outputs SHOULD have `description`.

## Stateful randomized defaults (example: AD selection)

If a module needs a randomized default value, the random choice MUST be persisted in Terraform state and MUST store the final value (not an index).

Recipe (example: pick an Availability Domain name when input is null):

```hcl
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

locals {
  ad_names = [for ad in data.oci_identity_availability_domains.ads.availability_domains : ad.name]
}

resource "random_shuffle" "picked_ad" {
  count        = var.availability_domain == null ? 1 : 0
  input        = local.ad_names
  result_count = 1
}

locals {
  availability_domain = var.availability_domain != null
    ? var.availability_domain
    : random_shuffle.picked_ad[0].result[0]
}
```

## Testing rules (integration)

- Categorize terraform integration tests by intent and run them in this order:
  - `error_path` — validate required arguments fail fast (run first)
  - `defaults_path` — validate defaults and stateful behaviors (run second)
  - `happy_path` — full apply success scenario (run last)
- For behavior that should be validated without destructive changes (example: “changing AD forces replace”), tests MUST:
  - run `terraform plan -detailed-exitcode` and assert exit code (`0` = no change, `2` = change)
  - parse plan output (`terraform show -no-color <plan>`) to assert replace behavior (destroy+create)
  - do NOT apply the destructive plan in the test

