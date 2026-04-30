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

---

## OCI Resource Manager CLI Workflow

This chapter covers the same operational path using the OCI Resource Manager
service instead of running Terraform locally. ORM manages provider installation,
state, and job history. Use this path when operators do not have Terraform
installed locally or when audit trails via ORM jobs are required.

## ORM Prerequisites

> EXECUTED — log: `test_run_A3_integration_20260430_095710.log`

```bash
# Same environment variables as the direct CLI path
export OCI_REGION="eu-zurich-1"
export COMPARTMENT_OCID="ocid1.compartment.oc1..example"
export SUBNET_OCID="ocid1.subnet.oc1.eu-zurich-1..example"
export AD_NAME="$(oci iam availability-domain list \
  --compartment-id "${COMPARTMENT_OCID}" \
  --query 'data[0].name' --raw-output)"
export REPO_ROOT="$(git rev-parse --show-toplevel)"
export PACKAGE_OUT="${REPO_ROOT}/progress/sprint_15/generated_tf/manual"
export ORM_WORKDIR="${REPO_ROOT}/progress/sprint_15/generated_tf/orm_apply"
mkdir -p "${ORM_WORKDIR}"

echo "Region:      ${OCI_REGION}"
echo "Compartment: ${COMPARTMENT_OCID}"
echo "AD:          ${AD_NAME}"
```

## ORM Step 1 — Package

> EXECUTED — log: `test_run_A3_integration_20260430_095710.log`

Produce the two ORM-ready zip files (see Step 1 of the direct CLI path).
The zips must include the `modules/` tree.

```bash
rm -f "${PACKAGE_OUT}/fss-mount-target.zip" \
      "${PACKAGE_OUT}/fss-filesystem-export.zip"

(cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/mount_target" && \
  zip -qr "${PACKAGE_OUT}/fss-mount-target.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)

(cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint15_orm_advanced/filesystem_export" && \
  zip -qr "${PACKAGE_OUT}/fss-filesystem-export.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)
```

## ORM Step 2 — Create and Apply the Mount Target Stack

> EXECUTED — log: `test_run_A3_integration_20260430_095710.log`

```bash
# Variable file
cat >"${ORM_WORKDIR}/mt_vars.json" <<JSON
{
  "region":                     "${OCI_REGION}",
  "compartment_ocid":           "${COMPARTMENT_OCID}",
  "availability_domain":        "${AD_NAME}",
  "subnet_ocid":                "${SUBNET_OCID}",
  "mount_target_display_name":  "fss-sprint15-orm-mt"
}
JSON

# Create stack — waits until ACTIVE
oci resource-manager stack create \
  --compartment-id   "${COMPARTMENT_OCID}" \
  --display-name     "fss-sprint15-orm-mount-target" \
  --config-source    "${PACKAGE_OUT}/fss-mount-target.zip" \
  --variables        "file://${ORM_WORKDIR}/mt_vars.json" \
  --wait-for-state   ACTIVE \
  --wait-for-state   FAILED \
  --max-wait-seconds 900 \
  >"${ORM_WORKDIR}/mt_stack_create.json"

export MT_STACK_ID="$(jq -r '.data.id' "${ORM_WORKDIR}/mt_stack_create.json")"
echo "Mount target stack: ${MT_STACK_ID}"

# Apply job — AUTO_APPROVED skips the plan-review step
oci resource-manager job create-apply-job \
  --stack-id                 "${MT_STACK_ID}" \
  --display-name             "fss-sprint15-orm-mt-apply" \
  --execution-plan-strategy  AUTO_APPROVED \
  >"${ORM_WORKDIR}/mt_apply_job.json"

export MT_APPLY_JOB_ID="$(jq -r '.data.id' "${ORM_WORKDIR}/mt_apply_job.json")"

# Poll until terminal state
oci resource-manager job get \
  --job-id "${MT_APPLY_JOB_ID}" \
  --wait-for-state SUCCEEDED \
  --wait-for-state FAILED \
  --wait-for-state CANCELED \
  --max-wait-seconds 1800 \
  --wait-interval-seconds 20
```

## ORM Step 3 — Extract Mount Target Outputs

> EXECUTED — log: `test_run_A3_integration_20260430_095710.log`

```bash
# Download Terraform state from the apply job
oci resource-manager job get-job-tf-state \
  --job-id "${MT_APPLY_JOB_ID}" \
  --file   "${ORM_WORKDIR}/mt_tf_state.json"

export MT_OCID="$(jq -r '.outputs.mount_target_ocid.value' \
  "${ORM_WORKDIR}/mt_tf_state.json")"
export MT_MOUNT_ADDRESS="$(jq -r '.outputs.mount_address.value' \
  "${ORM_WORKDIR}/mt_tf_state.json")"

echo "Mount target OCID:  ${MT_OCID}"
echo "Mount address:      ${MT_MOUNT_ADDRESS}"
```

## ORM Step 4 — Create and Apply the Filesystem/Export Stack

> EXECUTED — log: `test_run_A3_integration_20260430_095710.log`

```bash
cat >"${ORM_WORKDIR}/fs_vars.json" <<JSON
{
  "region":                    "${OCI_REGION}",
  "compartment_ocid":          "${COMPARTMENT_OCID}",
  "availability_domain":       "${AD_NAME}",
  "existing_mount_target_ocid":"${MT_OCID}",
  "filesystem_display_name":   "fss-sprint15-orm-fs",
  "export_1_path":             "/data",
  "add_export_2":              true,
  "export_2_path":             "/logs"
}
JSON

oci resource-manager stack create \
  --compartment-id   "${COMPARTMENT_OCID}" \
  --display-name     "fss-sprint15-orm-filesystem-export" \
  --config-source    "${PACKAGE_OUT}/fss-filesystem-export.zip" \
  --variables        "file://${ORM_WORKDIR}/fs_vars.json" \
  --wait-for-state   ACTIVE \
  --wait-for-state   FAILED \
  --max-wait-seconds 900 \
  >"${ORM_WORKDIR}/fs_stack_create.json"

export FS_STACK_ID="$(jq -r '.data.id' "${ORM_WORKDIR}/fs_stack_create.json")"
echo "Filesystem/export stack: ${FS_STACK_ID}"

oci resource-manager job create-apply-job \
  --stack-id                "${FS_STACK_ID}" \
  --display-name            "fss-sprint15-orm-fs-apply" \
  --execution-plan-strategy AUTO_APPROVED \
  >"${ORM_WORKDIR}/fs_apply_job.json"

export FS_APPLY_JOB_ID="$(jq -r '.data.id' "${ORM_WORKDIR}/fs_apply_job.json")"

oci resource-manager job get \
  --job-id "${FS_APPLY_JOB_ID}" \
  --wait-for-state SUCCEEDED \
  --wait-for-state FAILED \
  --wait-for-state CANCELED \
  --max-wait-seconds 1800 \
  --wait-interval-seconds 20
```

## ORM Step 5 — Read NFS Mount Sources

> EXECUTED — log: `test_run_A3_integration_20260430_095710.log`

```bash
oci resource-manager job get-job-tf-state \
  --job-id "${FS_APPLY_JOB_ID}" \
  --file   "${ORM_WORKDIR}/fs_tf_state.json"

jq '.outputs.nfs_mount_sources.value' "${ORM_WORKDIR}/fs_tf_state.json"
jq '.outputs.filesystem_export_summary.value' "${ORM_WORKDIR}/fs_tf_state.json"
```

Expected `nfs_mount_sources` shape:

```json
{
  "export_1": "10.x.x.x:/data",
  "export_2": "10.x.x.x:/logs"
}
```

## ORM Step 6 — Destroy and Delete (reverse order)

> EXECUTED — log: `test_run_A3_integration_20260430_095710.log`

```bash
# Destroy filesystem/export stack first
oci resource-manager job create-destroy-job \
  --stack-id                "${FS_STACK_ID}" \
  --display-name            "fss-sprint15-orm-fs-destroy" \
  --execution-plan-strategy AUTO_APPROVED \
  >"${ORM_WORKDIR}/fs_destroy_job.json"

export FS_DESTROY_JOB_ID="$(jq -r '.data.id' "${ORM_WORKDIR}/fs_destroy_job.json")"
oci resource-manager job get \
  --job-id "${FS_DESTROY_JOB_ID}" \
  --wait-for-state SUCCEEDED \
  --wait-for-state FAILED \
  --wait-for-state CANCELED \
  --max-wait-seconds 1800 \
  --wait-interval-seconds 20

# Destroy mount target stack
oci resource-manager job create-destroy-job \
  --stack-id                "${MT_STACK_ID}" \
  --display-name            "fss-sprint15-orm-mt-destroy" \
  --execution-plan-strategy AUTO_APPROVED \
  >"${ORM_WORKDIR}/mt_destroy_job.json"

export MT_DESTROY_JOB_ID="$(jq -r '.data.id' "${ORM_WORKDIR}/mt_destroy_job.json")"
oci resource-manager job get \
  --job-id "${MT_DESTROY_JOB_ID}" \
  --wait-for-state SUCCEEDED \
  --wait-for-state FAILED \
  --wait-for-state CANCELED \
  --max-wait-seconds 1800 \
  --wait-interval-seconds 20

# Remove the ORM stack objects
oci resource-manager stack delete \
  --stack-id "${FS_STACK_ID}" --force \
  --wait-for-state DELETED --max-wait-seconds 300

oci resource-manager stack delete \
  --stack-id "${MT_STACK_ID}" --force \
  --wait-for-state DELETED --max-wait-seconds 300
```
