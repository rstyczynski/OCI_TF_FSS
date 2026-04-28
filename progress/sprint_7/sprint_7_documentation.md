# Sprint 7 - Documentation

## Summary

Sprint 7 refactored the FSS stack module variable interface to reflect OCI's actual M:N resource relationships between mount targets and filesystems. The new `fss_sprint7_stack` module replaces the flat 1:1:1 coupling from Sprint 5 with two independent map inputs — `mount_targets` and `filesystems` — where each filesystem carries a nested `exports` map and each export references a mount target by stable key.

## What was delivered

**New module:** `terraform/modules/fss_sprint7_stack/`

Inputs:

| Variable | Required | Description |
|---|---|---|
| `compartment_ocid` | yes | Target compartment |
| `availability_domain` | yes | AD for all filesystems and mount targets |
| `subnet_ocid` | yes | Subnet for all mount targets |
| `kms_key_id` | yes | Encryption key for all filesystems |
| `default_source_cidr` | no | Fallback CIDR for exports that omit `source` |
| `mount_targets` | no | Map of mount target definitions |
| `filesystems` | no | Map of filesystem definitions with nested `exports` |

Each `filesystems` entry supports a nested `exports` map. Each export carries `mount_target_key` (references a `mount_targets` key), `path`, `source`, and all standard NFS export options including `identity_squash`, `access`, `allowed_auth`, and more.

Outputs:

| Output | Description |
|---|---|
| `mount_targets` | Composite map keyed by mount target key |
| `mount_target_ocids` | Atomic OCIDs keyed by mount target key |
| `filesystems` | Composite map with nested `exports` summaries per filesystem |
| `filesystem_ocids` | Atomic OCIDs keyed by filesystem key |
| `export_paths` | Paths keyed by composite key `fs__export` |
| `nfs_mount_sources` | `<addr>:<path>` strings keyed by composite key `fs__export` |

**Additive change:** `terraform/modules/fss_sprint4_export/outputs.tf` — `identity_squash` output added.

**Unchanged:** `terraform/modules/fss_sprint5_stack/` — preserved as compatibility baseline.

## Usage example

```hcl
module "fss" {
  source              = "./terraform/modules/fss_sprint7_stack"
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid
  kms_key_id          = var.kms_key_id
  default_source_cidr = "10.0.0.0/24"

  mount_targets = {
    primary   = { display_name = "fss-mt-primary" }
    secondary = { display_name = "fss-mt-secondary" }
  }

  filesystems = {
    data = {
      display_name = "fss-data"
      exports = {
        to_primary = {
          mount_target_key = "primary"
          path             = "/data"
        }
        to_secondary = {
          mount_target_key = "secondary"
          path             = "/data"
          identity_squash  = "NONE"
        }
      }
    }
  }
}

output "nfs_mount_sources" {
  value = module.fss.nfs_mount_sources
  # e.g. { "data__to_primary" = "10.0.0.5:/data", "data__to_secondary" = "10.0.0.6:/data" }
}
```

## Quality gates

| Gate | Result | Log |
|---|---|---|
| Skeleton red | fail=2 pass=0 | `progress/sprint_7/test_run_skeleton_red_20260428_164054.log` |
| A3 Integration | fail=0 pass=2 | `progress/sprint_7/test_run_A3_integration_20260428_164808.log` |

## Backlog traceability

- PBI-019: `progress/backlog/PBI-019/`
- PBI-015: superseded by PBI-019 — closed without separate implementation
