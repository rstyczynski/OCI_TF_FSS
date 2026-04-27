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
- Terraform integration tests MUST keep their Terraform working directory (and thus TF state) under the sprint directory:
  - Default: `progress/sprint_N/tf_state/`
  - If `SKIP_TEARDOWN=true`, the directory is preserved for operator debugging and manual teardown.
- For behavior that should be validated without destructive changes (example: “changing AD forces replace”), tests MUST:
  - run `terraform plan -detailed-exitcode` and assert exit code (`0` = no change, `2` = change)
  - parse plan output (`terraform show -no-color <plan>`) to assert replace behavior (destroy+create)
  - do NOT apply the destructive plan in the test

## Oracle-managed tags (OCI) — avoid perpetual drift

Some OCI resources get **Oracle-managed defined tags** injected after create (example keys: `Oracle-Tags.CreatedBy`, `Oracle-Tags.CreatedOn`). If your Terraform configuration sets `defined_tags = {}` (or sets a subset), a subsequent `terraform plan` may try to remove those injected tags, causing perpetual “drift”.

Rule: **Never fight Oracle-managed defined tags.** Either ignore them, or explicitly preserve them.

Preferred approach (preserve-only allowlisted Oracle tags via merge):

- Read current tags from the resource via `data.*` (after the resource exists).
- Filter to **only** the allowlisted Oracle-managed keys.
- Merge them into the desired user-supplied `defined_tags`.
- Validate that allowlisted keys are **exactly** in the `Oracle-Tags.*` namespace.

Recipe (pattern):

```hcl
variable "defined_tags" {
  type    = map(string)
  default = {}
}

variable "oracle_managed_defined_tag_keys" {
  type    = set(string)
  default = ["Oracle-Tags.CreatedBy", "Oracle-Tags.CreatedOn"]

  validation {
    condition = alltrue([
      for k in var.oracle_managed_defined_tag_keys :
      can(regex("^Oracle-Tags\\.[A-Za-z0-9_]+$", k))
    ])
    error_message = "oracle_managed_defined_tag_keys entries must be Oracle-Tags.<Name> (example: Oracle-Tags.CreatedOn)."
  }
}

# Example: after creation, read the resource back (no circular deps).
data "oci_file_storage_file_system" "current" {
  file_system_id = oci_file_storage_file_system.this.id
}

locals {
  oracle_managed_defined_tags = {
    for k, v in try(data.oci_file_storage_file_system.current.defined_tags, {}) :
    k => v if contains(var.oracle_managed_defined_tag_keys, k)
  }

  merged_defined_tags = merge(var.defined_tags, local.oracle_managed_defined_tags)
}

resource "oci_file_storage_file_system" "this" {
  # ...
  defined_tags = local.merged_defined_tags
}
```

Notes:

- This pattern is easiest when the resource already exists (imported) or when the provider/data source can read without creating a dependency cycle. If a data source would create a cycle, fall back to ignoring `defined_tags` drift for that resource.
