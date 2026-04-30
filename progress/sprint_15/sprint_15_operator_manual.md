# Sprint 15 - Operator Manual

Status: Draft

## Purpose

Sprint 15 provides two focused OCI Resource Manager stack roots:

- `terraform/modules/fss_stack_sprint15_orm_advanced/mount_target/`
- `terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export/`

Deploy the mount target stack first. Then deploy the filesystem/export stack, selecting the created mount target. Destroy in reverse order.

## Prerequisites

The following must exist before deployment. Verify each:

> NOT RUN — requires live OCI environment and credentials

```bash
# OCI CLI configured and reachable
oci iam region list --output table

# Required environment variables — set before running any snippet below
export OCI_REGION="eu-zurich-1"
export COMPARTMENT_OCID="ocid1.compartment.oc1..example"
export SUBNET_OCID="ocid1.subnet.oc1.eu-zurich-1..example"
export AD_NAME="$(oci iam availability-domain list \
  --compartment-id "${COMPARTMENT_OCID}" \
  --query 'data[0].name' --raw-output)"

echo "Region:      ${OCI_REGION}"
echo "Compartment: ${COMPARTMENT_OCID}"
echo "Subnet:      ${SUBNET_OCID}"
echo "AD:          ${AD_NAME}"
```

## Step 1 — Package the Stacks

> EXECUTED — log: `operator_manual_package_modules_20260429_210911.log`

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
PACKAGE_OUT="${REPO_ROOT}/progress/sprint_15/generated_tf/manual"
mkdir -p "${PACKAGE_OUT}"

# Remove existing zips first — macOS zip updates rather than replaces
rm -f "${PACKAGE_OUT}/fss-mount-target.zip"
rm -f "${PACKAGE_OUT}/fss-filesystem-export.zip"

# Zip root files and embedded modules — recursive on modules/ is required
(cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/mount_target" && \
  zip -qr "${PACKAGE_OUT}/fss-mount-target.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)

(cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export" && \
  zip -qr "${PACKAGE_OUT}/fss-filesystem-export.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)

# Verify — fss-mount-target.zip: 18 files; fss-filesystem-export.zip: 24 files
unzip -l "${PACKAGE_OUT}/fss-mount-target.zip"
unzip -l "${PACKAGE_OUT}/fss-filesystem-export.zip"
```

## Step 2 — Validate the Stack Roots

> EXECUTED — both stacks pass `terraform validate`

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"

cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/mount_target"
terraform init -backend=false
terraform validate

cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export"
terraform init -backend=false
terraform validate
```

## Step 3 — Deploy the Mount Target Stack

> EXECUTED — log: `operator_manual_integration_20260430_074500.log`

```bash
WORKDIR_MT="/tmp/sprint15_mount_target"
mkdir -p "${WORKDIR_MT}"
cp -r "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/mount_target/." \
  "${WORKDIR_MT}/"
cd "${WORKDIR_MT}"

terraform init

terraform apply \
  -var="region=${OCI_REGION}" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="availability_domain=${AD_NAME}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="mount_target_display_name=fss-sprint15-mt"
```

## Step 4 — Capture Mount Target Outputs

> EXECUTED — log: `operator_manual_integration_20260430_074500.log`

```bash
cd "${WORKDIR_MT}"

export MT_OCID="$(terraform output -raw mount_target_ocid)"
export MT_MOUNT_ADDRESS="$(terraform output -raw mount_address)"
export MT_IP="$(terraform output -raw ip_address)"
export MT_EXPORT_SET_OCID="$(terraform output -raw export_set_ocid)"

echo "Mount target OCID:    ${MT_OCID}"
echo "Mount address:        ${MT_MOUNT_ADDRESS}"
echo "IP address:           ${MT_IP}"
echo "Export set OCID:      ${MT_EXPORT_SET_OCID}"
```

## Step 5 — Deploy the Filesystem/Export Stack

> EXECUTED — log: `operator_manual_integration_20260430_074500.log`

```bash
WORKDIR_FS="/tmp/sprint15_filesystem_export"
mkdir -p "${WORKDIR_FS}"
cp -r "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export/." \
  "${WORKDIR_FS}/"
cd "${WORKDIR_FS}"

terraform init

terraform apply \
  -var="region=${OCI_REGION}" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="availability_domain=${AD_NAME}" \
  -var="existing_mount_target_ocid=${MT_OCID}" \
  -var="filesystem_display_name=fss-sprint15-fs" \
  -var="export_1_path=/data" \
  -var="add_export_2=true" \
  -var="export_2_path=/backup"
```

## Step 6 — Read Filesystem/Export Outputs

> EXECUTED — log: `operator_manual_integration_20260430_074500.log`

```bash
cd "${WORKDIR_FS}"

terraform output nfs_mount_sources
terraform output filesystem_ocid
terraform output export_paths
terraform output filesystem_export_summary
```

Expected output shape for `nfs_mount_sources`:

```hcl
{
  "export_1" = "10.x.x.x:/data"
  "export_2" = "10.x.x.x:/backup"
}
```

## Step 7 — Mount and Verify

> NOT RUN — requires live OCI environment, credentials, and a compute instance in the same subnet

```bash
MOUNT_ADDRESS="${MT_MOUNT_ADDRESS}"

sudo mkdir -p /mnt/fss_data /mnt/fss_backup
sudo mount -t nfs "${MOUNT_ADDRESS}:/data"   /mnt/fss_data
sudo mount -t nfs "${MOUNT_ADDRESS}:/backup" /mnt/fss_backup

# Verify writable
sudo touch /mnt/fss_data/probe_sprint15   && echo "MOUNT_DATA_OK"   || echo "MOUNT_DATA_FAIL"
sudo touch /mnt/fss_backup/probe_sprint15 && echo "MOUNT_BACKUP_OK" || echo "MOUNT_BACKUP_FAIL"

sudo umount /mnt/fss_data
sudo umount /mnt/fss_backup
```

## Step 8 — Destroy (reverse order)

> EXECUTED — log: `operator_manual_integration_20260430_074500.log`

```bash
# Destroy filesystem/export stack first
cd "${WORKDIR_FS}"
terraform destroy \
  -var="region=${OCI_REGION}" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="availability_domain=${AD_NAME}" \
  -var="existing_mount_target_ocid=${MT_OCID}" \
  -var="export_1_path=/data"

# Then destroy mount target stack
cd "${WORKDIR_MT}"
terraform destroy \
  -var="region=${OCI_REGION}" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="availability_domain=${AD_NAME}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```
