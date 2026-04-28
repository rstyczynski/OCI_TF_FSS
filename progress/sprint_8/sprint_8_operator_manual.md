# Sprint 8 - Operator Manual

## Overview

`fss_sprint8_stack` extends the Sprint 7 stack with optional OCI Logging for File Storage mount targets. Logging is opt-in per mount target and uses the OCI File Storage service log category `nfslogs`.

## Prerequisites

1. Sprint 1 foundation infrastructure deployed.
2. Sprint 5 MEK provisioned.
3. OCI CLI configured with permissions for File Storage and Logging.
4. Terraform >= 1.5.0 installed.

## Read Foundation Values

```bash
cd "$(git rev-parse --show-toplevel)"

COMPARTMENT_OCID=$(jq -r '.compartment.ocid' progress/sprint_1/scaffold/infra/state-infra.json)
SUBNET_OCID=$(jq -r '.subnet.ocid' progress/sprint_1/scaffold/infra/state-infra.json)
SUBNET_CIDR=$(jq -r '.subnet.cidr' progress/sprint_1/scaffold/infra/state-infra.json)
COMPUTE_IP=$(jq -r '.compute.public_ip' progress/sprint_1/scaffold/infra/state-infra.json)
KMS_KEY_ID=$(jq -r '.key.ocid' progress/sprint_5/scaffold/fss-mek/state-sprint5-fss-mek.json)
```

## Create Terraform Configuration

```bash
mkdir -p progress/sprint_8/operator_tf
cd progress/sprint_8/operator_tf

cat > main.tf <<'EOF'
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

module "stack" {
  source              = "../../../terraform/modules/fss_sprint8_stack"
  compartment_ocid    = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = var.subnet_ocid
  kms_key_id          = var.kms_key_id
  default_source_cidr = var.subnet_cidr

  mount_targets = {
    primary = {
      display_name = "fss-logging-primary"
      logging = {
        enabled            = true
        log_group_name     = "fss-primary-logs"
        log_display_name   = "fss-primary-nfs"
        retention_duration = 30
      }
    }
  }

  filesystems = {
    data = {
      display_name = "fss-logging-data"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/data"
          identity_squash  = "NONE"
        }
      }
    }
  }
}

output "mount_targets" {
  value = module.stack.mount_targets
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}
EOF
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

## Inspect Log Outputs

```bash
terraform output -json mount_targets | jq '.primary.logging'

LOG_GROUP_OCID=$(terraform output -json mount_targets | jq -r '.primary.logging.log_group_ocid')
LOG_OCID=$(terraform output -json mount_targets | jq -r '.primary.logging.log_ocid')
NFS_MOUNT_SOURCE=$(terraform output -json nfs_mount_sources | jq -r '.data__primary')
```

The composite `mount_targets` output includes `logging = null` when logging is disabled, or a populated logging object when logging is enabled. Atomic outputs remain available for log OCID and log group OCID lookup.

## Verify the Log with OCI CLI

```bash
oci logging log get \
  --log-group-id "${LOG_GROUP_OCID}" \
  --log-id "${LOG_OCID}" \
  | jq '.data | {id, "is-enabled", "lifecycle-state"}'
```

## Generate NFS Activity

Materialize the foundation SSH key before this step. Sprint 1 stores it in Vault; the integration tests call `sprint1__raw_key_from_secret_bundle` from `tools/infra_setup.sh`.

```bash
ssh -i /tmp/ssh_key.pem -o StrictHostKeyChecking=no "opc@${COMPUTE_IP}" <<REMOTE
sudo yum install -y nfs-utils 2>/dev/null || true
sudo mkdir -p /mnt/fss/sprint8
sudo mount -t nfs -o vers=3,noacl ${NFS_MOUNT_SOURCE} /mnt/fss/sprint8
echo "Sprint 8 log proof" | sudo tee /mnt/fss/sprint8/proof.txt
sudo cat /mnt/fss/sprint8/proof.txt
sudo rm -f /mnt/fss/sprint8/proof.txt
sudo umount /mnt/fss/sprint8
sudo rmdir /mnt/fss/sprint8
REMOTE
```

`identity_squash = "NONE"` is used in this example so remote `sudo` operations are not mapped to anonymous UID/GID.

## Search Logs

```bash
TIME_START=$(date -u -v-15M '+%Y-%m-%dT%H:%M:%SZ')
TIME_END=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
SEARCH_QUERY="search \"${COMPARTMENT_OCID}/${LOG_GROUP_OCID}/${LOG_OCID}\" | sort by datetime desc"

oci logging-search search-logs \
  --time-start "${TIME_START}" \
  --time-end "${TIME_END}" \
  --search-query "${SEARCH_QUERY}" \
  --limit 10 \
  | jq '.data.results'
```

NFS service log ingestion can lag after a fresh log is created. `oci logging log get` verifies the log configuration immediately; `search-logs` provides event evidence once records arrive.

## Teardown

```bash
terraform destroy \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="subnet_cidr=${SUBNET_CIDR}" \
  -var="kms_key_id=${KMS_KEY_ID}"
```
