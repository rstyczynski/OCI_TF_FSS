# Sprint 6 - Operator Manual

## Overview

Sprint 6 provides automation for mounting OCI File Storage Service (FSS) exports on compute instances and running administrator operations on mounted filesystems.

## Prerequisites

1. Sprint 1 foundation infrastructure deployed (`progress/sprint_1/scaffold/infra/`)
2. Sprint 5 MEK (Master Encryption Key) created by the Sprint 5 ensure-key flow (`progress/sprint_5/scaffold/fss-mek/`)
3. OCI CLI configured with appropriate credentials
4. SSH access to foundation compute instance

## Provisioning FSS and Mounting

The Sprint 5 stack returns `nfs_mount_sources`, so operators do not need to look up mount target private IP OCIDs manually. Each value is already in `<mount-address>:<export-path>` form.

### Step 1: Get Foundation State Values

```bash
cd "$(git rev-parse --show-toplevel)"

# Get compute public IP
COMPUTE_IP=$(jq -r '.compute.public_ip' progress/sprint_1/scaffold/infra/state-infra.json)
echo "Compute IP: ${COMPUTE_IP}"

# Get compartment, subnet, and KMS key
COMPARTMENT_OCID=$(jq -r '.compartment.ocid' progress/sprint_1/scaffold/infra/state-infra.json)
SUBNET_OCID=$(jq -r '.subnet.ocid' progress/sprint_1/scaffold/infra/state-infra.json)
SUBNET_CIDR=$(jq -r '.subnet.cidr' progress/sprint_1/scaffold/infra/state-infra.json)
KMS_KEY_ID=$(jq -r '.key.ocid' progress/sprint_5/scaffold/fss-mek/state-sprint5-fss-mek.json)

echo "Compartment: ${COMPARTMENT_OCID}"
echo "Subnet: ${SUBNET_OCID}"
echo "KMS Key: ${KMS_KEY_ID}"
```

### Step 2: Deploy FSS Stack

```bash
# Create working directory
mkdir -p progress/sprint_6/operator_tf
cd progress/sprint_6/operator_tf

# Create Terraform configuration
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
  source              = "../../../terraform/modules/fss_sprint5_stack"
  compartment_ocid    = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = var.subnet_ocid
  kms_key_id          = var.kms_key_id
  default_source_cidr = var.subnet_cidr

  filesystems = {
    myfs = {
      filesystem_display_name = "my-fss-filesystem"
      export_path             = "/mydata"
      freeform_tags = {
        environment = "dev"
      }
    }
  }
}

output "mount_target_mount_addresses" {
  value = module.stack.mount_target_mount_addresses
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}
EOF

# Initialize and apply
terraform init
terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="subnet_cidr=${SUBNET_CIDR}" \
  -var="kms_key_id=${KMS_KEY_ID}"
```

### Step 3: Get NFS Mount Source

```bash
NFS_MOUNT_SOURCE=$(terraform output -json nfs_mount_sources | jq -r '.myfs')
MOUNT_TARGET_ADDRESS=$(terraform output -json mount_target_mount_addresses | jq -r '.myfs')

echo "Mount Target Address: ${MOUNT_TARGET_ADDRESS}"
echo "NFS Mount Source: ${NFS_MOUNT_SOURCE}"
```

`MOUNT_TARGET_ADDRESS` is useful for network diagnostics. `NFS_MOUNT_SOURCE` is the value passed to `mount`.

### Step 4: Materialize SSH Key

```bash
cd /Users/rstyczynski/projects/OCI_TF_FSS

# Get secret OCID and materialize key
SECRET_OCID=$(jq -r '.secret.ocid' progress/sprint_1/scaffold/infra/state-infra.json)

oci secrets secret-bundle get \
  --secret-id "${SECRET_OCID}" \
  --query 'data."secret-bundle-content".content' \
  --raw-output | base64 -d > /tmp/ssh_key.pem

chmod 600 /tmp/ssh_key.pem
```

### Step 5: Mount FSS on Compute Instance

```bash
# SSH to compute and mount FSS
ssh -i /tmp/ssh_key.pem -o StrictHostKeyChecking=no "opc@${COMPUTE_IP}" << REMOTE_SCRIPT
# Install NFS utils if not present
sudo yum install -y nfs-utils

# Create mount point
sudo mkdir -p /mnt/fss/myfs

# Mount FSS export
sudo mount -t nfs -o vers=3,noacl ${NFS_MOUNT_SOURCE} /mnt/fss/myfs

# Verify mount
mount | grep /mnt/fss/myfs
df -h /mnt/fss/myfs
REMOTE_SCRIPT
```

## Administrator Operations

### Create Directory Structure

```bash
ssh -i /tmp/ssh_key.pem -o StrictHostKeyChecking=no "opc@${COMPUTE_IP}" << 'REMOTE_SCRIPT'
sudo mkdir -p /mnt/fss/myfs/data/subdir1/subdir2
ls -la /mnt/fss/myfs/data/
REMOTE_SCRIPT
```

### Change Ownership

```bash
ssh -i /tmp/ssh_key.pem -o StrictHostKeyChecking=no "opc@${COMPUTE_IP}" << 'REMOTE_SCRIPT'
sudo chown -R opc:opc /mnt/fss/myfs/data
stat /mnt/fss/myfs/data
REMOTE_SCRIPT
```

### Set Permissions

```bash
ssh -i /tmp/ssh_key.pem -o StrictHostKeyChecking=no "opc@${COMPUTE_IP}" << 'REMOTE_SCRIPT'
chmod 750 /mnt/fss/myfs/data
stat -c '%a %n' /mnt/fss/myfs/data
REMOTE_SCRIPT
```

### File Operations

```bash
ssh -i /tmp/ssh_key.pem -o StrictHostKeyChecking=no "opc@${COMPUTE_IP}" << 'REMOTE_SCRIPT'
# Create file
echo "Hello FSS" > /mnt/fss/myfs/data/hello.txt

# Read file
cat /mnt/fss/myfs/data/hello.txt

# List files
ls -la /mnt/fss/myfs/data/
REMOTE_SCRIPT
```

## Unmounting and Cleanup

### Unmount FSS

```bash
ssh -i /tmp/ssh_key.pem -o StrictHostKeyChecking=no "opc@${COMPUTE_IP}" << 'REMOTE_SCRIPT'
sudo umount /mnt/fss/myfs
sudo rmdir /mnt/fss/myfs
REMOTE_SCRIPT
```

### Destroy FSS Infrastructure

```bash
cd /Users/rstyczynski/projects/OCI_TF_FSS/progress/sprint_6/operator_tf

terraform destroy \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="subnet_cidr=${SUBNET_CIDR}" \
  -var="kms_key_id=${KMS_KEY_ID}"
```

### Cleanup SSH Key

```bash
rm -f /tmp/ssh_key.pem
```

## Mount Options Reference

OCI FSS recommended mount options:

| Option | Value | Description |
|--------|-------|-------------|
| vers | 3 | NFS version 3 (recommended for OCI FSS) |
| noacl | - | Disable ACL (simplifies permission management) |
| rsize | 1048576 | Read buffer size (optional, for performance) |
| wsize | 1048576 | Write buffer size (optional, for performance) |
| timeo | 600 | Timeout in tenths of seconds |
| retrans | 2 | Number of retries |

Example with full options:

```bash
sudo mount -t nfs \
  -o vers=3,noacl,rsize=1048576,wsize=1048576,timeo=600,retrans=2 \
  ${NFS_MOUNT_SOURCE} /mnt/fss/myfs
```

## Troubleshooting

### Mount fails with "access denied"

Check export options in Terraform configuration ensure `source_cidr` matches the compute subnet.

### Mount hangs

1. Verify network reachability to the mount target address from `terraform output -json mount_target_mount_addresses`.
2. Check security list allows NFS ports (111, 2048-2050 TCP/UDP)
3. Run Sprint 4 NPA test to verify path

### Permission denied on mounted filesystem

1. Check export `identity_squash` setting (default: ROOT)
2. Verify ownership and permissions with `ls -la`
3. Use `sudo` for root-level operations
