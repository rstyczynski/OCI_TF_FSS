# FSS Stack Module

## Purpose

This module creates OCI File Storage Service topologies from two maps:

- `mount_targets`: mount targets keyed by stable operator names
- `filesystems`: filesystems keyed by stable operator names, each with nested exports

Exports reference mount targets by key. The module reduces mandatory operator input by deriving the Availability Domain, allowing Oracle-managed filesystem encryption, and defaulting export source CIDR.

## Contents

- [FSS Stack Module](#fss-stack-module)
  - [Purpose](#purpose)
  - [Contents](#contents)
  - [Mandatory Inputs](#mandatory-inputs)
  - [Mount Target Entries](#mount-target-entries)
  - [Filesystem Entries](#filesystem-entries)
  - [Optional Inputs](#optional-inputs)
  - [Outputs](#outputs)
  - [Operator Notes](#operator-notes)
  - [Examples](#examples)
    - [Example 1 — Basic FSS](#example-1--basic-fss)
      - [Run it](#run-it)
      - [What the code does](#what-the-code-does)
      - [Expected output](#expected-output)
      - [Mount on a compute instance](#mount-on-a-compute-instance)
      - [Teardown](#teardown)
    - [Example 2 — Multiple FSS with logging](#example-2--multiple-fss-with-logging)
      - [Run](#run)
      - [Code walkthrough](#code-walkthrough)
      - [Sample outputs](#sample-outputs)
      - [Mount the admin-accessible export (`identity_squash = "NONE"`)](#mount-the-admin-accessible-export-identity_squash--none)
      - [Discover logs via OCI CLI](#discover-logs-via-oci-cli)
      - [Destroy](#destroy)

## Mandatory Inputs

| Name | Description |
|---|---|
| `compartment_ocid` | Target OCI compartment OCID. |
| `subnet_ocid` | Subnet OCID for mount targets. |

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

## Optional Inputs

| Name | Default | Description |
|---|---:|---|
| `availability_domain` | `null` | Explicit AD override. When omitted, the module uses the subnet AD when available, otherwise selects from sorted AD names using `random_shuffle`. |
| `kms_key_id` | `null` | Customer-managed KMS key OCID. When omitted, OCI File Storage uses Oracle-managed encryption. |
| `default_source_cidr` | `0.0.0.0/0` | Default client IPv4 CIDR for exports that omit `source`. FSS is private VCN reachable, not public-internet reachable. |
| `mount_targets` | `{}` | Map of mount targets to create. |
| `filesystems` | `{}` | Map of filesystems to create, each with optional nested exports. |

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

## Operator Notes

- `default_source_cidr = "0.0.0.0/0"` is broad, but FSS is not directly exposed to the public internet. Use explicit export `source` values or a module-level CIDR when tighter client filtering is required.
- `identity_squash = "NONE"` is useful for administrator workflows that rely on remote `sudo`.
- `mount_targets[*].logging` is `null` when logging is disabled for that mount target.

## Examples

### Example 1 — Basic FSS

Located in `examples/basic_fss/`.

**What it does:** provisions one mount target, one filesystem (`fss-data`), and one export at `/data`. Only two inputs are required. The module derives the Availability Domain from the subnet and uses Oracle-managed encryption.

**When to use it:** quickest path to a working NFS mount point; no KMS key, no logging, no explicit AD.

#### Run it

```bash
export compartment_ocid=
export subnet_ocid=

cd terraform/modules/fss_stack_sprint12/examples/basic_fss

terraform init

terraform apply \
  -var="compartment_ocid=${compartment_ocid}" \
  -var="subnet_ocid=${subnet_ocid}"
```

#### What the code does

```hcl
module "fss" {
  source = "../.."

  compartment_ocid = var.compartment_ocid  # mandatory — target compartment
  subnet_ocid      = var.subnet_ocid       # mandatory — mount target lands here

  mount_targets = {
    primary = {}  # display name defaults to "fss-mt-primary"; AD derived from subnet
  }

  filesystems = {
    data = {
      display_name = "fss-data"
      exports = {
        primary = {
          mount_target_key = "primary"  # references the mount_targets key above
          path             = "/data"    # NFS export path clients will mount
          # source defaults to 0.0.0.0/0 (safe because FSS is VCN-private)
          # identity_squash defaults to ROOT
        }
      }
    }
  }
}
```

#### Expected output

```bash
terraform output -json nfs_mount_sources
# { "data__primary" = "10.0.0.5:/data" }

terraform output -json mount_targets | jq '.primary | {ip: .ip_address, mount: .mount_address}'
# { "ip": "10.0.0.5", "mount": "10.0.0.5" }

terraform output -raw availability_domain_source
# subnet   ← derived from the subnet; no explicit AD was needed

terraform output -raw kms_key_mode
# ORACLE_MANAGED   ← no kms_key_id was supplied
```

#### Mount on a compute instance

```bash
NFS_SOURCE=$(terraform output -json nfs_mount_sources | jq -r '."data__primary"')

ssh opc@<COMPUTE_IP> "sudo mkdir -p /mnt/data && \
  sudo mount -t nfs -o vers=3,noacl ${NFS_SOURCE} /mnt/data && \
  df -h /mnt/data"
```

#### Teardown

```bash
terraform destroy \
  -var="compartment_ocid=${compartment_ocid}" \
  -var="subnet_ocid=${subnet_ocid}"
```

---

### Example 2 — Multiple FSS with logging

Located in `examples/multi_fss_with_logging/`.

**What it does:** provisions two mount targets (`primary` with OCI Logging enabled, `secondary` without), two filesystems (`fss-data` and `fss-backup`), and three exports — one filesystem exported to both mount targets (M:N topology), the other to one. Demonstrates `identity_squash = "NONE"` for admin-accessible exports and optional KMS encryption.

**When to use it:** production-like topology with audit logging, multi-AD redundancy through separate mount targets, and mixed squash policies per export.

#### Run

```bash
export compartment_ocid=
export subnet_ocid=
export kms_key_id=          # optional — leave empty for Oracle-managed encryption
export availability_domain= # optional — leave empty to derive from subnet

cd terraform/modules/fss_stack_sprint12/examples/multi_fss_with_logging

terraform init

# Minimal — Oracle-managed encryption, AD derived automatically
terraform apply \
  -var="compartment_ocid=${compartment_ocid}" \
  -var="subnet_ocid=${subnet_ocid}"

# With customer-managed KMS key and explicit AD
terraform apply \
  -var="compartment_ocid=${compartment_ocid}" \
  -var="subnet_ocid=${subnet_ocid}" \
  -var="kms_key_id=${kms_key_id}" \
  -var="availability_domain=${availability_domain}"
```

#### Code walkthrough

```hcl
module "fss" {
  source = "../.."

  compartment_ocid    = var.compartment_ocid
  subnet_ocid         = var.subnet_ocid
  availability_domain = var.availability_domain  # null → derived from subnet or randomized
  kms_key_id          = var.kms_key_id           # null → Oracle-managed encryption
  default_source_cidr = var.default_source_cidr  # default 0.0.0.0/0

  mount_targets = {
    primary = {
      display_name = "fss-primary"
      logging = {
        enabled = true   # creates an OCI Logging NFS service log for this mount target
        # log_group_id omitted → module creates a log group automatically
      }
    }
    secondary = {
      display_name = "fss-secondary"
      # no logging — logging block omitted entirely
    }
  }

  filesystems = {
    data = {
      display_name = "fss-data"
      exports = {
        primary = {
          mount_target_key = "primary"      # export via primary mount target
          path             = "/data"
          identity_squash  = "NONE"         # remote root is trusted — admin operations work
        }
        secondary = {
          mount_target_key = "secondary"    # same filesystem, second mount target
          path             = "/data-secondary"
          # identity_squash defaults to ROOT — safe for application mounts
        }
      }
    }
    backup = {
      display_name = "fss-backup"
      exports = {
        primary = {
          mount_target_key = "primary"      # backup only via primary; secondary not needed
          path             = "/backup"
        }
      }
    }
  }
}
```

Export topology at a glance:

```text
mt_primary ──── data/primary     (/data,           squash=NONE)
           └─── backup/primary   (/backup,          squash=ROOT)

mt_secondary ── data/secondary   (/data-secondary,  squash=ROOT)
```

#### Sample outputs

```bash
terraform output -json nfs_mount_sources
# {
#   "backup__primary"    = "10.0.0.5:/backup",
#   "data__primary"      = "10.0.0.5:/data",
#   "data__secondary"    = "10.0.0.6:/data-secondary"
# }

# Check logging resources for the primary mount target
terraform output -json mount_targets | jq '.primary.logging'
# { "log_group_ocid": "ocid1.loggroup...", "log_ocid": "ocid1.log...", "enabled": true, ... }

# No logging object for secondary
terraform output -json mount_targets | jq '.secondary.logging'
# null

# Verify identity_squash on each export
terraform output -json filesystems | jq '.data.exports | to_entries[] | {(.key): .value.identity_squash}'
# { "primary": "NONE" }
# { "secondary": "ROOT" }
```

#### Mount the admin-accessible export (`identity_squash = "NONE"`)

Verify the stack is applied and the export has NONE squash before mounting:

```bash
# Confirm identity_squash is NONE — must be done before mounting
terraform output -json filesystems | \
  jq '.data.exports.primary.identity_squash'
# expected: "NONE"
```

Then mount and run admin operations:

```bash
NFS_ADMIN=$(terraform output -json nfs_mount_sources | jq -r '."data__primary"')
COMPUTE_IP=<YOUR_COMPUTE_IP>

ssh opc@${COMPUTE_IP} "
  sudo mkdir -p /mnt/data
  sudo mount -t nfs -o vers=3,noacl ${NFS_ADMIN} /mnt/data
  sudo mkdir -p /mnt/data/app/conf && echo MKDIR_OK
  sudo chown opc:opc /mnt/data/app
  sudo umount /mnt/data
"
```

> **Note:** `sudo mkdir` fails with "Permission denied" if the export has `identity_squash = ROOT` (the default). Ensure the stack is applied with `identity_squash = "NONE"` on this export before running admin operations. If in doubt, run the verify step above.

#### Discover logs via OCI CLI

```bash
LOG_GROUP_OCID=$(terraform output -json mount_targets | jq -r '.primary.logging.log_group_ocid')
LOG_OCID=$(terraform output -json mount_targets | jq -r '.primary.logging.log_ocid')

echo "Log group : ${LOG_GROUP_OCID}"
echo "Log       : ${LOG_OCID}"

oci logging log get \
  --log-group-id "${LOG_GROUP_OCID}" \
  --log-id       "${LOG_OCID}" \
  --query 'data.{name:"display-name", state:"lifecycle-state"}' \
  --output table
```

#### Destroy

```bash
terraform destroy \
  -var="compartment_ocid=${compartment_ocid}" \
  -var="subnet_ocid=${subnet_ocid}"
```
