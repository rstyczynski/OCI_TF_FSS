# FSS Mount Target Module

## Purpose

Creates one OCI File Storage mount target in a subnet and exposes the identifiers required by exports and NFS clients.

## Required Inputs

| Name | Description |
|---|---|
| `compartment_ocid` | Target OCI compartment OCID. |
| `availability_domain` | Availability Domain for the mount target. |
| `subnet_ocid` | Subnet OCID where the mount target is created. |
| `display_name` | Mount target display name. |

## Optional Inputs

| Name | Description |
|---|---|
| `hostname_label` | Optional hostname label used to build the mount target FQDN. |
| `nsg_ids` | Optional NSG OCIDs attached to the mount target. |
| `freeform_tags` | Freeform tags. |
| `defined_tags` | Defined tags. |

## Outputs

Key outputs include:

- `mount_target_ocid`
- `mount_target_display_name`
- `mount_target_export_set_ocid`
- `mount_target_private_ip_ids`
- `mount_target_ip_address`
- `mount_target_fqdn`
- `mount_target_mount_address`

## Example

```hcl
module "mt" {
  source              = "../fss_mount_target"
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_ocid         = var.subnet_ocid
  display_name        = "fss-mt"
}
```

