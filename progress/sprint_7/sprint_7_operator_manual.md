# Sprint 7 - Operator Manual

## Overview

`fss_sprint7_stack` provisions OCI File Storage Service infrastructure using two independent map inputs — `mount_targets` and `filesystems`. Each filesystem entry carries a nested `exports` map; each export references a mount target by stable key. This allows a true M:N topology: one mount target can serve multiple filesystems, and one filesystem can be exported via multiple mount targets.

## Prerequisites

1. Sprint 1 foundation infrastructure deployed: `progress/sprint_1/scaffold/infra/state-infra.json`
2. Sprint 5 MEK (Master Encryption Key) provisioned: `progress/sprint_5/scaffold/fss-mek/state-sprint5-fss-mek.json`
3. OCI CLI configured with credentials that have IAM and FSS permissions
4. Terraform >= 1.5.0 installed

## Step 1 — Read foundation values

```bash
cd "$(git rev-parse --show-toplevel)"

COMPARTMENT_OCID=$(jq -r '.compartment.ocid' progress/sprint_1/scaffold/infra/state-infra.json)
SUBNET_OCID=$(jq -r '.subnet.ocid'           progress/sprint_1/scaffold/infra/state-infra.json)
SUBNET_CIDR=$(jq -r '.subnet.cidr'           progress/sprint_1/scaffold/infra/state-infra.json)
KMS_KEY_ID=$(jq -r '.key.ocid'               progress/sprint_5/scaffold/fss-mek/state-sprint5-fss-mek.json)

echo "Compartment : ${COMPARTMENT_OCID}"
echo "Subnet      : ${SUBNET_OCID}"
echo "Subnet CIDR : ${SUBNET_CIDR}"
echo "KMS key     : ${KMS_KEY_ID}"
```

**NOT RUN** — snippet reads local state files; executed indirectly by IT-2 (`progress/sprint_7/test_run_A3_integration_20260428_164808.log`).

## Step 2 — Create a working directory

```bash
mkdir -p progress/sprint_7/operator_tf
cd progress/sprint_7/operator_tf
```

**NOT RUN** — executed indirectly via test harness.

## Step 3 — Write Terraform configuration

The example below provisions two mount targets and two filesystems. `fs_data` is exported to both mount targets with different `identity_squash` settings; `fs_backup` is exported only to the primary mount target.

```bash
cat > main.tf <<'EOF'
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

variable "compartment_ocid"    {}
variable "subnet_ocid"         {}
variable "default_source_cidr" {}
variable "kms_key_id"          {}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

module "fss" {
  source              = "../../../terraform/modules/fss_sprint7_stack"
  compartment_ocid    = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = var.subnet_ocid
  kms_key_id          = var.kms_key_id
  default_source_cidr = var.default_source_cidr

  mount_targets = {
    primary = {
      display_name = "fss-mt-primary"
    }
    secondary = {
      display_name = "fss-mt-secondary"
    }
  }

  filesystems = {
    fs_data = {
      display_name = "fss-data"
      exports = {
        to_primary = {
          mount_target_key = "primary"
          path             = "/data"
          identity_squash  = "NONE"
        }
        to_secondary = {
          mount_target_key = "secondary"
          path             = "/data"
        }
      }
    }
    fs_backup = {
      display_name = "fss-backup"
      exports = {
        to_primary = {
          mount_target_key = "primary"
          path             = "/backup"
        }
      }
    }
  }
}

output "mount_targets"      { value = module.fss.mount_targets }
output "filesystems"        { value = module.fss.filesystems }
output "nfs_mount_sources"  { value = module.fss.nfs_mount_sources }
EOF
```

**NOT RUN** — the equivalent configuration was exercised by IT-2 (`progress/sprint_7/test_run_A3_integration_20260428_164808.log`).

## Step 4 — Apply

```bash
terraform init

terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="default_source_cidr=${SUBNET_CIDR}" \
  -var="kms_key_id=${KMS_KEY_ID}"
```

**NOT RUN** — executed indirectly by IT-2 test log above.

## Step 5 — Inspect outputs

```bash
# All NFS mount sources, keyed by composite key fs__export
terraform output -json nfs_mount_sources

# Expected form:
# {
#   "fs_backup__to_primary"    = "10.0.0.5:/backup",
#   "fs_data__to_primary"      = "10.0.0.5:/data",
#   "fs_data__to_secondary"    = "10.0.0.6:/data"
# }

# IP address and preferred mount address per mount target
terraform output -json mount_target_ip_addresses
terraform output -json mount_target_mount_addresses

# Composite mount_targets output includes ip_address, fqdn, and mount_address
terraform output -json mount_targets | jq '.primary | {ip: .mount_target_ip_address, fqdn: .mount_target_fqdn, mount_address: .mount_target_mount_address}'

# Per-filesystem composite output with nested export summaries
terraform output -json filesystems | jq '.fs_data.exports'
```

**NOT RUN** — output structure verified in IT-2 test log.

### Output key conventions

| Key pattern | Meaning |
|---|---|
| `mount_target_ocids["primary"]` | OCID of the `primary` mount target |
| `mount_target_ip_addresses["primary"]` | Private IP address of the `primary` mount target |
| `mount_target_mount_addresses["primary"]` | FQDN if `hostname_label` set, otherwise private IP |
| `mount_targets["primary"].mount_target_ip_address` | Same IP address via composite output |
| `mount_targets["primary"].mount_target_fqdn` | DNS name (null when no `hostname_label`) |
| `filesystem_ocids["fs_data"]` | OCID of the `fs_data` filesystem |
| `nfs_mount_sources["fs_data__to_primary"]` | `<addr>:<path>` ready to pass to `mount` |
| `filesystems["fs_data"].exports["to_primary"].identity_squash` | OCI-applied squash mode |

## Step 6 — Mount on a compute instance

```bash
COMPUTE_IP=$(jq -r '.compute.public_ip' \
  ../../sprint_1/scaffold/infra/state-infra.json)

# Read a specific mount source
NFS_MOUNT_SOURCE=$(terraform output -json nfs_mount_sources \
  | jq -r '."fs_data__to_primary"')

ssh -i /tmp/ssh_key.pem -o StrictHostKeyChecking=no "opc@${COMPUTE_IP}" <<REMOTE
sudo yum install -y nfs-utils
sudo mkdir -p /mnt/fss/data
sudo mount -t nfs -o vers=3,noacl ${NFS_MOUNT_SOURCE} /mnt/fss/data
mount | grep /mnt/fss/data
df -h /mnt/fss/data
REMOTE
```

**NOT RUN** — mount procedure not re-executed in Sprint 7; see Sprint 6 operator manual for mount evidence.

### `identity_squash` and admin operations

| `identity_squash` | Remote `sudo` behaviour |
|---|---|
| `ROOT` (default) | Remote root mapped to anonymous UID — `sudo mkdir` on the export may fail |
| `NONE` | Remote root is trusted — admin operations work normally |

Set `identity_squash = "NONE"` on exports that need administrator write access. Apply Terraform and remount before retrying.

## Step 7 — Teardown

```bash
cd progress/sprint_7/operator_tf

terraform destroy \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="default_source_cidr=${SUBNET_CIDR}" \
  -var="kms_key_id=${KMS_KEY_ID}"
```

**NOT RUN** — destroy exercised by IT-2 teardown (`test_run_A3_integration_20260428_164808.log`).

## Running the integration tests

```bash
cd "$(git rev-parse --show-toplevel)"

TS="$(date -u '+%Y%m%d_%H%M%S')"
LOG="progress/sprint_7/test_run_A3_integration_${TS}.log"
tests/run.sh --integration --new-only progress/sprint_7/new_tests.manifest 2>&1 | tee "$LOG"
```

IT-1 (static validate) requires no OCI credentials. IT-2 (full apply) requires Sprint 1 foundation state and Sprint 5 MEK state.
