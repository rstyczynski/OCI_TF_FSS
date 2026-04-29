# FSS v1 Stack Module

## Purpose

`fss_v1_stack` provisions a KMS-backed OCI File Storage Service stack from a map input. Each map entry creates:

- one filesystem
- one mount target
- one export

This is the stable v1 package of the Sprint 5 stack behavior. Operators should use this module instead of sprint-numbered module paths.

## Required Inputs

| Name | Description |
|---|---|
| `compartment_ocid` | Target OCI compartment OCID. |
| `availability_domain` | Availability Domain for filesystems and mount targets. |
| `subnet_ocid` | Subnet OCID for mount targets. |
| `kms_key_id` | KMS key OCID used to encrypt all filesystems. |
| `filesystems` | Map of filesystem stack entries. |

Each `filesystems` entry requires:

| Name | Description |
|---|---|
| `filesystem_display_name` | Filesystem display name. |
| `export_path` | NFS export path, for example `/data`. |

## Optional Inputs

| Name | Default | Description |
|---|---:|---|
| `default_source_cidr` | `null` | Default CIDR for exports that omit `source_cidr`. |
| `filesystems[*].mount_target_display_name` | generated | Mount target display name. |
| `filesystems[*].source_cidr` | `default_source_cidr` | Client CIDR allowed by the export. |
| `filesystems[*].hostname_label` | `null` | Mount target hostname label. |
| `filesystems[*].nsg_ids` | `null` | NSG OCIDs attached to the mount target. |
| `filesystems[*].access` | `READ_WRITE` | Export access mode. |
| `filesystems[*].allowed_auth` | `["SYS"]` | Allowed NFS auth methods. |
| `filesystems[*].identity_squash` | `ROOT` | Export identity squash mode. |
| `filesystems[*].anonymous_uid` | `65534` | Anonymous UID for squashed users. |
| `filesystems[*].anonymous_gid` | `65534` | Anonymous GID for squashed users. |
| `filesystems[*].is_anonymous_access_allowed` | `false` | Whether anonymous access is allowed. |
| `filesystems[*].require_privileged_source_port` | `false` | Whether clients must use privileged source ports. |
| `filesystems[*].freeform_tags` | `{}` | Filesystem freeform tags. |
| `filesystems[*].defined_tags` | `{}` | Filesystem defined tags. |

The filesystem entries also pass through advanced filesystem options exposed by `fss_v1_filesystem`, including quota rules, snapshot policy, source snapshot, locks, and operation timeouts.

## Outputs

Important outputs:

| Name | Description |
|---|---|
| `filesystems` | Composite output keyed by input map key with filesystem, mount target, export, and NFS mount source details. |
| `filesystem_ocids` | Filesystem OCIDs keyed by input map key. |
| `mount_target_ocids` | Mount target OCIDs keyed by input map key. |
| `mount_target_mount_addresses` | Preferred NFS server address per entry. |
| `export_ocids` | Export OCIDs keyed by input map key. |
| `export_paths` | Export paths keyed by input map key. |
| `nfs_mount_sources` | Ready-to-use `<mount-address>:<export-path>` strings. |
| `effective_source_cidrs` | Effective export CIDRs after default inheritance. |

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

  filesystems = {
    alpha = {
      filesystem_display_name = "fss-alpha"
      export_path             = "/alpha"
      identity_squash         = "NONE"
      freeform_tags = {
        environment = "dev"
      }
    }
    beta = {
      filesystem_display_name   = "fss-beta"
      mount_target_display_name = "fss-beta-mt"
      export_path               = "/beta"
      source_cidr               = var.subnet_cidr
    }
  }
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
- If `source_cidr` is omitted for an entry, `default_source_cidr` must be set.
- `identity_squash = "NONE"` is useful for administrator workflows that rely on remote `sudo`.
