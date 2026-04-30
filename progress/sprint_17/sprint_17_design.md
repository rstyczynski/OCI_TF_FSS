# Sprint 17 - design

## PBI-031 / PBI-032. Externally managed mount targets + per-mount-target placement overrides

Status: Proposed

### Goal

Extend the stack interface so each mount target entry can be:

- **managed** by the stack (created as today), or
- **externally managed** (referenced by OCID, not created)

Exports continue to reference mount targets **by key** (`filesystems[*].exports[*].mount_target_key`), with no change to the filesystem/export input shape.

Additionally, allow **per-mount-target placement overrides** so a mount target entry can specify its own `subnet_ocid` and/or `availability_domain`, defaulting to the stack-level values when omitted.

Sprint 17 product lives in `terraform/modules/fss_stack_sprint17/`.

### Scope / constraints

- Preserve compatibility with the Sprint 12 stack interface and examples.
- Placement overrides are implemented as part of Sprint 17 (PBI-032).

### Interface changes

Add optional attributes to `mount_targets` entries:

- `external_ocid` (optional string): when set, the stack does **not** create a mount target for that key; instead it resolves mount target details via data sources using the provided OCID.
- `subnet_ocid` (optional string): when set, this mount target uses the provided subnet instead of the stack default `var.subnet_ocid`.
- `availability_domain` (optional string): when set, this mount target uses the provided AD instead of the stack’s effective AD.

All existing attributes (`display_name`, `hostname_label`, `nsg_ids`, tags, logging) remain valid for managed mount targets. For external mount targets:

- `hostname_label` is ignored for resource creation (no resource is created); the stack uses the remote mount target’s hostname label (if available) for FQDN computation.
- `logging` is not managed by this stack for external mount targets (no log resources created; no log configuration changes).

### Mount target resolution model

Partition `var.mount_targets` into two disjoint sets:

- **managed mount targets**: entries where `external_ocid` is null/missing
- **external mount targets**: entries where `external_ocid` is a non-empty string

Define per-entry effective placement for mount targets:

- `effective_subnet_ocid`: `coalesce(mount_targets[key].subnet_ocid, var.subnet_ocid)`
- `effective_availability_domain`: `coalesce(mount_targets[key].availability_domain, local.effective_availability_domain)`

Resolution outputs produced for both sets, keyed by the same `mount_targets` map key:

- `mount_target_ocid`
- `mount_target_export_set_ocid`
- `mount_target_private_ip_ids`
- `mount_target_ip_address` (derived via `oci_core_private_ip`)
- `mount_target_fqdn` (derived via `hostname_label` + `subnet_domain_name`, when available)
- `mount_target_mount_address` (coalesce FQDN, IP)

These unified resolved values are used by:

- export creation (`export_set_ocid`)
- operator-facing outputs (`mount_targets`, `nfs_mount_sources`, filesystem export summaries)

### Data sources for external mount targets

For each external mount target entry (key \(k\)):

1. Use `data "oci_file_storage_mount_targets"` filtered by `id = external_ocid` and `compartment_id = var.compartment_ocid` to fetch the mount target summary.
2. Use `data "oci_core_private_ip"` for the first private IP ID returned by the mount target summary to obtain `ip_address`.
3. Use `data "oci_core_subnet"` for the mount target entry’s `effective_subnet_ocid` to obtain `subnet_domain_name` for FQDN computation.

Notes:

- The OCI provider list API returns a mount target summary (not the full mount target) and does not expose `ip_address` directly; resolving via `private_ip_ids[0]` is required (proven pattern in Sprint 15 BUG-4).

### Validations (fail fast)

Add input validations (and/or `precondition`s) so errors are clear before apply:

- **external_ocid format**: when provided, must match `^ocid1\\.fsmounttarget\\..+`.
- **key exists**: every export’s `mount_target_key` must exist in `var.mount_targets` keys (unchanged rule).
- **external MT is in expected subnet**: for external mount targets, assert `mount_target.subnet_id == effective_subnet_ocid` for that mount target key.
- **external MT is in effective AD**: for external mount targets, assert `mount_target.availability_domain == effective_availability_domain` for that mount target key.

If any validation fails, surface a message that includes the map key and the mismatched value(s).

### Export creation behavior

Export creation continues to use `module "export"` with the same per-export arguments, except `export_set_ocid` is now resolved from a unified map:

- managed: `module.mount_target[key].mount_target_export_set_ocid`
- external: `data.oci_file_storage_mount_targets...mount_targets[0].export_set_id` (or equivalent provider attribute)

No changes to filesystem creation.

### Outputs

Maintain existing output shapes.

For `output "mount_targets"` and `output "nfs_mount_sources"`:

- Use the unified resolved mount address per mount target key (FQDN if available, else IP).
- For external mount targets, compute mount address using remote `hostname_label` (when present) and the resolved `subnet_domain_name` for that mount target key’s `effective_subnet_ocid`.

### Test strategy (managed sprint)

Smoke:

- `terraform validate` passes for all existing Sprint 12 examples without changes.
- `terraform validate` passes for a new example that sets one mount target entry with `external_ocid` and creates exports referencing that key.
- `terraform validate` passes for a new example that defines two mount target entries with distinct `subnet_ocid` overrides (and explicit `availability_domain` overrides when required by the chosen subnet type).

Integration:

- Not executable without OCI credentials/capacity in this environment; if not run, record as **NOT RUN** in `progress/sprint_17/sprint_17_tests.md` per `RUP_patch.md` rules.

