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
  - Default root: `progress/sprint_N/tf_state/` (override with `TF_STATE_ROOT` if needed).
  - **Stable directory per logical test**: use a fixed subdirectory name per test (a `test_id`), e.g. `progress/sprint_N/tf_state/it4_happy_path/`, not a fresh `mktemp` directory on every run. That keeps `.terraform/` on disk so **`terraform init` is not repeated** when you re-run the same test.
  - **When to wipe**: remove that subdirectory (or set `TF_RESET_TF_STATE=true` before the run, if the harness supports it) when you need a clean slate or hit state conflicts. **Keep** the directory across reruns when an update-style or multi-step scenario depends on existing state (or use `SKIP_TEARDOWN=true` to skip destroy and preserve state for debugging).
  - **Per-test teardown**: each test case MUST run **`terraform destroy`** when its body finishes (unless `SKIP_TEARDOWN=true`). Do not rely on a single **EXIT** trap when the runner may invoke several test functions in one shell (manifest mode): traps overwrite each other and only the last workdir would be destroyed. Ephemeral dirs (`mktemp`-style names under `tf_state`) may be removed entirely after destroy; stable `test_id` dirs are left on disk after destroy (empty or state-only) so the next run can re-init quickly.
  - If `SKIP_TEARDOWN=true`, destroy is skipped and the directory is preserved for operator debugging and manual teardown.
- **Test artifacts (gate / debugging evidence)** — integration runs MUST retain:
  - **Plan files**: every `terraform plan` that participates in assertions MUST use `-out=<path>` and keep that **binary plan file** on disk under the test working directory (for example `tf_test_artifacts/*.tfplan`). Do not rely only on console plan output.
  - **Deploy and destroy logs**: capture **stdout and stderr together** from `terraform apply` (deploy) and from `terraform destroy` (teardown), for example with `2>&1 | tee tf_test_artifacts/deploy.stdout.log` and `tf_test_artifacts/destroy.stdout.log`. Tests that have no apply still SHOULD capture comparable steps (for example `terraform validate`) to a log under the same artifacts folder.
  - Optionally also write `terraform show -no-color <planfile>` next to each binary plan for human-readable review.
- For behavior that should be validated without destructive changes (example: “changing AD forces replace”), tests MUST:
  - run `terraform plan -detailed-exitcode` and assert exit code (`0` = no change, `2` = change)
  - parse plan output (`terraform show -no-color <plan>`) to assert replace behavior (destroy+create)
  - do NOT apply the destructive plan in the test

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

Apply the same lookup-before-create rule for `oci_logging_log`:

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
