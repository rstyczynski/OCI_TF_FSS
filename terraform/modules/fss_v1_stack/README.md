# FSS v1 Stack Module

## Purpose

`fss_v1_stack` creates OCI File Storage Service topologies from two maps:

- `mount_targets`: mount targets keyed by stable operator names
- `filesystems`: filesystems keyed by stable operator names, each with nested exports

Exports reference mount targets by key. This supports the current stack interface where one mount target can serve multiple filesystems, and one filesystem can have multiple exports.

The module requires `kms_key_id` because every filesystem created by this module is encrypted with the customer-managed OCI Vault key supplied by the caller.

Use this module for the v1 interface. Sprint-numbered modules remain in the repository as development history and test baselines.

## Required Inputs

| Name | Description |
|---|---|
| `compartment_ocid` | Target OCI compartment OCID. |
| `availability_domain` | Availability Domain for filesystems and mount targets. |
| `subnet_ocid` | Subnet OCID for mount targets. |
| `kms_key_id` | KMS key OCID used to encrypt all filesystems. |

## Optional Inputs

| Name | Default | Description |
|---|---:|---|
| `default_source_cidr` | `null` | Default client IPv4 CIDR for exports that omit `source`. |
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
| `enabled` | `false` | Whether to create/enable an OCI File Storage NFS service log. |
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

Important outputs:

| Name | Description |
|---|---|
| `mount_targets` | Composite mount target output keyed by mount target key. Includes IP, mount address, export set OCID, and `logging` details when enabled. |
| `mount_target_ocids` | Mount target OCIDs keyed by mount target key. |
| `mount_target_ip_addresses` | Primary private IP address per mount target. |
| `mount_target_mount_addresses` | Preferred NFS server address per mount target; FQDN when available, otherwise private IP. |
| `mount_target_log_group_ocids` | Log group OCIDs keyed by mount target key for logging-enabled targets. |
| `mount_target_log_ocids` | Log OCIDs keyed by mount target key for logging-enabled targets. |
| `filesystems` | Composite filesystem output keyed by filesystem key, with nested export summaries and ready-to-use NFS mount sources. |
| `filesystem_ocids` | Filesystem OCIDs keyed by filesystem key. |
| `export_paths` | Export paths keyed by composite `filesystem__export` key. |
| `nfs_mount_sources` | Ready-to-use `<mount-address>:<export-path>` strings keyed by composite `filesystem__export` key. |

## Example

```hcl
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

variable "compartment_ocid" {}
variable "subnet_ocid" {}
variable "subnet_cidr" {}
variable "kms_key_id" {}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

module "fss" {
  source              = "../../../terraform/modules/fss_v1_stack"
  compartment_ocid    = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = var.subnet_ocid
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

output "mount_targets" {
  value = module.fss.mount_targets
}

output "filesystems" {
  value = module.fss.filesystems
}

output "nfs_mount_sources" {
  value = module.fss.nfs_mount_sources
}
```

## Apply

```bash
terraform init
terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="subnet_cidr=${SUBNET_CIDR}" \
  -var="kms_key_id=${KMS_KEY_ID}"
```

## Logging Lookup

When logging is enabled for a mount target, the log details are available in `mount_targets`:

```bash
terraform output -json mount_targets | jq '.primary.logging'
terraform output -json mount_target_log_ocids
terraform output -json mount_target_log_group_ocids
```

## Teardown

```bash
terraform destroy \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="subnet_cidr=${SUBNET_CIDR}" \
  -var="kms_key_id=${KMS_KEY_ID}"
```

## Operator Notes

- `kms_key_id` is mandatory. Use the Sprint 5 MEK state or another valid OCI KMS key OCID.
- If an export omits `source`, `default_source_cidr` must be set.
- `identity_squash = "NONE"` is useful for administrator workflows that rely on remote `sudo`.
