# FSS v2 Stack Module

## Purpose

`fss_v2_stack` creates OCI File Storage Service topologies from two maps:

- `mount_targets`: mount targets keyed by stable operator names
- `filesystems`: filesystems keyed by stable operator names, each with nested exports

Exports reference mount targets by key. v2 keeps the current v1 stack shape and reduces mandatory operator input by deriving the Availability Domain, allowing Oracle-managed filesystem encryption, and defaulting export source CIDR.

Use this module for new operator-facing stacks. Keep `fss_v1_stack` for consumers that need the v1 contract.

## Mandatory Inputs

| Name | Description |
|---|---|
| `compartment_ocid` | Target OCI compartment OCID. |
| `subnet_ocid` | Subnet OCID for mount targets. |

## Optional Inputs

| Name | Default | Description |
|---|---:|---|
| `availability_domain` | `null` | Explicit AD override. When omitted, v2 uses the subnet AD when available, otherwise selects from sorted AD names using `random_shuffle`. |
| `kms_key_id` | `null` | Customer-managed KMS key OCID. When omitted, OCI File Storage uses Oracle-managed encryption. |
| `default_source_cidr` | `0.0.0.0/0` | Default client IPv4 CIDR for exports that omit `source`. FSS is private VCN reachable, not public-internet reachable. |
| `mount_targets` | `{}` | Map of mount targets to create. |
| `filesystems` | `{}` | Map of filesystems to create, each with optional nested exports. |

## Mount Target Entries

Each `mount_targets` entry may set:

| Name | Default | Description |
|---|---:|---|
| `display_name` | `fss-mt-<key>` | Mount target display name. |
| `hostname_label` | `null` | Optional hostname label used to build the mount target FQDN. |
| `nsg_ids` | `null` | Optional NSG OCIDs attached to the mount target. |
| `freeform_tags` | `{}` | Freeform tags. |
| `defined_tags` | `{}` | Defined tags. |
| `logging` | `null` | Optional OCI Logging configuration. |

Logging object fields:

| Name | Default | Description |
|---|---:|---|
| `enabled` | `false` | Whether to create or enable an OCI File Storage NFS service log. |
| `log_group_id` | `null` | Existing log group OCID. When omitted, the module creates one. |
| `log_group_name` | `fss-<key>-logs` | Display name for a created log group. |
| `log_display_name` | `fss-<key>-nfs` | Display name for the service log. |
| `retention_duration` | `30` | Log retention in days. |
| `freeform_tags` | `{}` | Tags for created logging resources. |
| `defined_tags` | `{}` | Defined tags for created logging resources. |

## Filesystem Entries

Each `filesystems` entry may set:

| Name | Default | Description |
|---|---:|---|
| `display_name` | required | Filesystem display name. |
| `freeform_tags` | `{}` | Filesystem freeform tags. |
| `defined_tags` | `{}` | Filesystem defined tags. |
| `exports` | `{}` | Map of exports for this filesystem. |

Each export entry may set:

| Name | Default | Description |
|---|---:|---|
| `mount_target_key` | required | Key of the mount target that owns the export set. |
| `path` | required | NFS export path, for example `/data`. |
| `source` | `null` | Client CIDR. Uses `default_source_cidr` when omitted. |
| `access` | `READ_WRITE` | Export access mode. |
| `allowed_auth` | `["SYS"]` | Allowed NFS authentication methods. |
| `identity_squash` | `ROOT` | Export identity squash mode. |
| `anonymous_uid` | `65534` | Anonymous UID for squashed users. |
| `anonymous_gid` | `65534` | Anonymous GID for squashed users. |
| `is_anonymous_access_allowed` | `false` | Whether anonymous access is allowed. |
| `require_privileged_source_port` | `false` | Whether clients must use privileged source ports. |

## Outputs

| Name | Description |
|---|---|
| `mount_targets` | Composite mount target output keyed by mount target key. Includes IP, mount address, export set OCID, AD source, and logging details when enabled. |
| `mount_target_ocids` | Mount target OCIDs keyed by mount target key. |
| `mount_target_ip_addresses` | Primary private IP address per mount target. |
| `mount_target_mount_addresses` | Preferred NFS server address per mount target; FQDN when available, otherwise private IP. |
| `mount_target_log_group_ocids` | Log group OCIDs keyed by mount target key for logging-enabled targets. |
| `mount_target_log_ocids` | Log OCIDs keyed by mount target key for logging-enabled targets. |
| `filesystems` | Composite filesystem output keyed by filesystem key, with nested export summaries and ready-to-use NFS mount sources. |
| `filesystem_ocids` | Filesystem OCIDs keyed by filesystem key. |
| `export_paths` | Export paths keyed by composite `filesystem__export` key. |
| `nfs_mount_sources` | Ready-to-use `<mount-address>:<export-path>` strings keyed by composite `filesystem__export` key. |
| `effective_availability_domain` | AD selected for filesystems and mount targets. |
| `availability_domain_source` | `explicit`, `subnet`, or `random`. |
| `effective_kms_key_id` | KMS key OCID supplied by the caller; `null` means Oracle-managed encryption. |
| `kms_key_mode` | `CUSTOMER_MANAGED` or `ORACLE_MANAGED`. |
| `default_source_cidr` | Default export source CIDR. |

## Minimal Example

```hcl
module "fss" {
  source           = "../../../terraform/modules/fss_v2_stack"
  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid

  mount_targets = {
    primary = {}
  }

  filesystems = {
    data = {
      display_name = "fss-data"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/data"
        }
      }
    }
  }
}
```

## Full Example

```hcl
module "fss" {
  source              = "../../../terraform/modules/fss_v2_stack"
  compartment_ocid    = var.compartment_ocid
  subnet_ocid         = var.subnet_ocid
  availability_domain = var.availability_domain
  kms_key_id          = var.kms_key_id
  default_source_cidr = var.subnet_cidr

  mount_targets = {
    primary = {
      display_name = "fss-primary"
      logging = {
        enabled = true
      }
    }
    secondary = {
      display_name = "fss-secondary"
    }
  }

  filesystems = {
    data = {
      display_name = "fss-data"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/data"
          identity_squash  = "NONE"
        }
        secondary = {
          mount_target_key = "secondary"
          path             = "/data-secondary"
        }
      }
    }
    backup = {
      display_name = "fss-backup"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/backup"
        }
      }
    }
  }
}
```

## Migration From v1

- Remove `availability_domain` when you want v2 to derive it from the subnet or select it for a regional subnet.
- Remove `kms_key_id` when Oracle-managed encryption is acceptable.
- Remove `default_source_cidr` when the v2 default `0.0.0.0/0` is acceptable for private VCN-reachable FSS exports.
- Keep the same `mount_targets` and `filesystems` map shape used by the latest v1 stack.

## Operator Notes

- `default_source_cidr = "0.0.0.0/0"` is broad, but FSS is not directly exposed to the public internet. Use explicit export `source` values or a module-level CIDR when tighter client filtering is required.
- `identity_squash = "NONE"` is useful for administrator workflows that rely on remote `sudo`.
- `mount_targets[*].logging` is `null` when logging is disabled for that mount target.
