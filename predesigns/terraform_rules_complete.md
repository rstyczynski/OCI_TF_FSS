# Pre-design: Complete Generic Terraform Rules Skill

**Status:** Proposed
**Backlog item:** PBI-034
**Date:** 2026-05-04

## Problem

`doc/tf_rules.md` is this project's authoritative Terraform rules reference. It was built sprint-by-sprint and covers seven topics well, but a code survey of `fss_stack_sprint17` reveals ten additional patterns in active use that are undocumented. More importantly, the rules are stored as a project-local sprint artifact — not reusable by other projects.

## Goal

Create a single, complete, MoSCoW-prioritised Terraform rules document in **RUPStrikesBack** as a generic reusable skill/reference, following the same convention as `RUPStrikesBack/rules/specific/ansible/ANSIBLE_BEST_PRACTICES.md`. Update this project's `doc/tf_rules.md` symlink to point to the upstream file.

## Current coverage (doc/tf_rules.md = sprint_17)

| Section | Status |
| ------- | ------ |
| Default module rules (explicit inputs, stable outputs, no magic defaults) | ✅ covered |
| Optional provider attributes | ✅ covered |
| Optional nested blocks (dynamic block pattern) | ✅ covered |
| Generated Terraform test roots (placement, naming) | ✅ covered |
| Composite outputs for map-based modules | ✅ covered |
| OCI unique display names — lookup before create | ✅ covered |
| OCI Oracle-managed tags — lifecycle ignore | ✅ covered |
| Experimental patterns | ✅ covered |

## Gaps — patterns in use but not documented

| Pattern | Evidence in codebase |
| ------- | -------------------- |
| Module file organisation — when to split into domain files (`log.tf` etc.) | Sprint 18 refactor |
| Input variable validation blocks — `validation {}` with `regex`, `alltrue`, `can()` | `variables.tf` lines 43-57 |
| Precondition validation — `terraform_data` + `precondition` for runtime cross-variable checks | `main.tf` validate_* resources |
| Map partitioning with for_each — disjoint subsets (managed/external) | `managed_mount_targets`, `external_mount_targets` locals |
| Composite key flattening — nested map → flat iterable | `exports_flat` local |
| Multi-level coalesce/try fallback chain — explicit precedence for optional attributes | AD resolution, log group/log ID resolution |
| Dual-mode outputs — composite object + atomic flat map per attribute | every output pair in `outputs.tf` |
| Self-contained module principle — sub-modules embedded under `modules/`, no sibling refs | Sprint 12+ packaging |
| Count for conditional optional resources — `count = condition ? 1 : 0` | `data.oci_identity_availability_domains.ads` |
| Versions.tf — required_providers + minimum Terraform version | `versions.tf` |

## Proposed document structure

**File:** `RUPStrikesBack/rules/specific/terraform/TERRAFORM_RULES.md`

MoSCoW legend: **M** Must have · **S** Should have · **C** Could have · **W** Won't have (this iteration)

Generic sections apply to any Terraform project. OCI-specific sections are labelled `[OCI]`.

```text
# Terraform Architecture Rules

## 1. Module structure
   1.1 [M] File organisation — main.tf, variables.tf, outputs.tf, versions.tf;
           domain-specific files (e.g. log.tf) when a coherent subsystem exceeds ~80 lines
   1.2 [M] Versioning — required_providers block + minimum Terraform version in versions.tf
   1.3 [M] Self-contained packaging — sub-modules embedded under modules/; no ../sibling refs

## 2. Inputs (variables)
   2.1 [M] Mandatory vs optional — required inputs for identity/replacement-driving values only
   2.2 [M] Optional nested objects — optional() with typed defaults, never null objects
   2.3 [S] Variable validation blocks — regex for OCID format, alltrue for map constraints, can()
   2.4 [M] No derived or magic defaults — no random naming, no hidden provider-level assumptions

## 3. Locals
   3.1 [S] Hierarchical staging — separate locals {} blocks per computation stage; name reflects stage
   3.2 [S] Map partitioning — disjoint subsets via for-if filter; never mutate the source map
   3.3 [S] Composite key flattening — merge nested map into flat key "parent__child" for for_each
   3.4 [C] Multi-level coalesce/try fallback chains — explicit precedence, document the order

## 4. Resources
   4.1 [M] for_each over locals subsets — never iterate var.* directly when filtering is needed
   4.2 [S] count for conditional optional resources — count = condition ? 1 : 0; prefer for_each
   4.3 [S] terraform_data + precondition — runtime cross-variable validation with clear error messages
   4.4 [M] lifecycle ignore_changes — provider-injected tags only; document which keys and why

## 5. Data sources
   5.1 [M] Lookup before create — for resources with scoped-unique display names
   5.2 [M] Cardinality guard — validate length <= 1 before using result; fail fast with precondition

## 6. Optional provider attributes & nested blocks
   6.1 [S] Optional provider attributes — use try(resource.attr, null) not direct references
   6.2 [S] Optional nested blocks — dynamic block pattern with for_each on a list variable

## 7. Outputs
   7.1 [M] Dual-mode outputs — composite object output + atomic flat map per key attribute
   7.2 [M] Composite outputs for map-based modules — nested child map under parent key

## 8. Testing
   8.1 [M] Generated test roots — stable path under progress/sprint_N/generated_tf/<test_id>/; never /tmp
   8.2 [S] Plan-only destructive tests — terraform show on plan output; never apply destructive plans

## 9. OCI-specific rules  [OCI]
   9.1 [M] Oracle-managed tags — lifecycle ignore for Oracle-Tags.CreatedBy / CreatedOn
   9.2 [S] OCID format validation — regex ^ocid1\.<type>\.. in variable validation blocks
   9.3 [M] Unique display names — lookup before create (see §5); never assume name is free

## 10. Experimental patterns  [W — excluded from active use unless explicitly requested]
   - AD randomization  [OCI]
   - Dynamic tag recognition  [OCI]
   - name_prefix naming abstraction
```

## Implementation scope (PBI-034)

1. Create `RUPStrikesBack/rules/specific/terraform/TERRAFORM_RULES.md` with full rule text for each entry above.
2. Update `doc/tf_rules.md` symlink: `ln -sfn ../RUPStrikesBack/rules/specific/terraform/TERRAFORM_RULES.md doc/tf_rules.md`
3. Update `PROJECT_RULES.md` R3 to reference the new upstream path.

## Verification

- `readlink doc/tf_rules.md` returns `../RUPStrikesBack/rules/specific/terraform/TERRAFORM_RULES.md`
- `ls RUPStrikesBack/rules/specific/terraform/` shows the new file alongside `ansible/` and `github_actions/`
- `grep -c '^## ' doc/tf_rules.md` returns ≥ 10
- No project-specific content (project names, sprint paths) in `TERRAFORM_RULES.md`
- All rules from the current `doc/tf_rules.md` appear verbatim or superseded (no regression)
