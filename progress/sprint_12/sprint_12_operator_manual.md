# Sprint 12 - Operator Manual

## Overview

`fss_stack_sprint12` is the operator-facing package for OCI File Storage Service provisioning. It bundles the stack module, lower-level reusable modules, and two executable examples under one directory root.

```text
terraform/modules/fss_stack_sprint12/
  main.tf, variables.tf, outputs.tf, versions.tf   ← root stack
  modules/
    fss_filesystem/                                 ← reusable filesystem module
    fss_mount_target/                               ← reusable mount target module
    fss_export/                                     ← reusable export module
  examples/
    basic_fss/                                      ← minimal example
    multi_fss_with_logging/                         ← full example
```

## Prerequisites

- Terraform >= 1.5.0
- OCI CLI configured with credentials that have IAM and FSS permissions
- An existing OCI compartment and subnet

## Example 1 — Basic FSS

One mount target, one filesystem, one export. Only `compartment_ocid` and `subnet_ocid` are required. The module derives the Availability Domain automatically and uses Oracle-managed encryption.

### Provision

```bash
cd terraform/modules/fss_stack_sprint12/examples/basic_fss

terraform init

export COMPARTMENT_OCID=ocid1.compartment.oc1..YOUR_COMPARTMENT
export SUBNET_OCID=ocid1.subnet.oc1..YOUR_SUBNET

terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

### Inspect outputs

```bash
# Ready-to-use NFS mount string
terraform output -json nfs_mount_sources
# { "data__primary" = "10.0.0.5:/data" }

# How the AD was selected and encryption mode
terraform output -raw availability_domain_source   # "subnet" or "random"
terraform output -raw kms_key_mode                 # "ORACLE_MANAGED"

# Mount target IP address
terraform output -json mount_targets | jq '.primary.ip_address'
```

### Mount on a compute instance

```bash
NFS_SOURCE=$(terraform output -json nfs_mount_sources | jq -r '."data__primary"')

ssh opc@<COMPUTE_IP> "
  sudo mkdir -p /mnt/data
  sudo mount -t nfs -o vers=3,noacl ${NFS_SOURCE} /mnt/data
  df -h /mnt/data
"
```

### Teardown

```bash
terraform destroy \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

## Example 2 — Multiple FSS with logging

Two mount targets, two filesystems, three exports. The `primary` mount target has OCI Logging enabled. One export uses `identity_squash = "NONE"` for administrator access. All optional variables have defaults so only the two mandatory inputs are required.

### Provision

```bash
cd terraform/modules/fss_stack_sprint12/examples/multi_fss_with_logging

terraform init

export COMPARTMENT_OCID=ocid1.compartment.oc1..YOUR_COMPARTMENT
export SUBNET_OCID=ocid1.subnet.oc1..YOUR_SUBNET

# Minimal — Oracle-managed encryption, AD derived automatically
terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"

# With customer-managed KMS key
terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="kms_key_id=ocid1.key.oc1..YOUR_KEY"
```

### Inspect multi-FSS outputs

```bash
# All mount sources keyed by composite key fs__export
terraform output -json nfs_mount_sources
# {
#   "backup__primary"  = "10.0.0.5:/backup",
#   "data__primary"    = "10.0.0.5:/data",
#   "data__secondary"  = "10.0.0.6:/data-secondary"
# }

# Logging details for the primary mount target
terraform output -json mount_targets | jq '.primary.logging'
# { "log_group_ocid": "ocid1.loggroup...", "log_ocid": "ocid1.log...", ... }

# identity_squash per export
terraform output -json filesystems | \
  jq '.data.exports | to_entries[] | {(.key): .value.identity_squash}'
# { "primary": "NONE" }
# { "secondary": "ROOT" }
```

### Discover OCI logs

```bash
LOG_GROUP=$(terraform output -json mount_targets | jq -r '.primary.logging.log_group_ocid')
LOG_OCID=$(terraform output -json mount_targets  | jq -r '.primary.logging.log_ocid')

oci logging log get \
  --log-group-id "${LOG_GROUP}" \
  --log-id       "${LOG_OCID}" \
  --query 'data.{name:"display-name", state:"lifecycle-state"}' \
  --output table
```

### Destroy multi-FSS stack

```bash
terraform destroy \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

## Running the integration tests

IT-1 (static validate) requires no OCI credentials. IT-2 (full apply) requires Sprint 1 foundation state.

```bash
cd "$(git rev-parse --show-toplevel)"

TS="$(date -u '+%Y%m%d_%H%M%S')"
LOG="progress/sprint_12/test_run_A3_integration_${TS}.log"
tests/run.sh --integration --new-only progress/sprint_12/new_tests.manifest 2>&1 | tee "$LOG"
```

## Evidence

IT-2 was executed during sprint closure. Key observed outputs:

| Field                        | Value                                      |
|------------------------------|--------------------------------------------|
| `availability_domain_source` | `random`                                   |
| `kms_key_mode`               | `ORACLE_MANAGED`                           |
| `nfs_mount_sources`          | `{ "data__primary" = "10.0.0.6:/data" }`   |

Log: `progress/sprint_12/test_run_A3_integration_20260429_084147.log`
