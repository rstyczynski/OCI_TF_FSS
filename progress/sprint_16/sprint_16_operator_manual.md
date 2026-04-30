# Sprint 16 - Operator Manual

Status: Draft

## Purpose

Sprint 16 provides corrected OCI Resource Manager stack roots under a new product directory:

- `terraform/modules/fss_stack_sprint16_orm_advanced/mount_target/`
- `terraform/modules/fss_stack_sprint16_orm_advanced/filesystem_export/`

Deploy the mount target stack first. Then deploy the filesystem/export stack, selecting the created mount target. Destroy in reverse order.

Sprint 16 keeps the Sprint 15 Resource Manager UI shape but embeds `fss_stack_sprint17` instead of the Sprint 15-specific intermediate modules.

## Prerequisites

The following must exist before deployment.

> NOT RUN - operator-specific OCI environment and credentials are required.

```bash
# OCI CLI configured and reachable
oci iam region list --output table

# Required environment variables - set before running any snippet below
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

## Step 1 - Package the Stacks

> EXECUTED - evidence: `progress/sprint_16/test_run_A3_integration_20260430_141213.log`

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
PACKAGE_OUT="${REPO_ROOT}/progress/sprint_16/generated_tf/manual"
mkdir -p "${PACKAGE_OUT}"

# Remove existing zips first because macOS zip updates rather than replaces.
rm -f "${PACKAGE_OUT}/fss-mount-target.zip"
rm -f "${PACKAGE_OUT}/fss-filesystem-export.zip"

# Zip root files and embedded modules. Recursive modules/ is required.
(cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint16_orm_advanced/mount_target" && \
  zip -qr "${PACKAGE_OUT}/fss-mount-target.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)

(cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint16_orm_advanced/filesystem_export" && \
  zip -qr "${PACKAGE_OUT}/fss-filesystem-export.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)

unzip -l "${PACKAGE_OUT}/fss-mount-target.zip"
unzip -l "${PACKAGE_OUT}/fss-filesystem-export.zip"
```

Sprint 16 integration packaging produced 42 files in each stack zip.

## Step 2 - Validate the Stack Roots

> EXECUTED - evidence: `progress/sprint_16/test_run_A1_smoke_20260430_141200.log`

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"

cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint16_orm_advanced/mount_target"
terraform init -backend=false
terraform validate

cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint16_orm_advanced/filesystem_export"
terraform init -backend=false
terraform validate
```

## Step 3 - Deploy the Mount Target Stack Locally

> NOT RUN - the Sprint 16 quality gate used OCI Resource Manager, not local Terraform state. Use this path only when local Terraform state is acceptable for the operator.

```bash
WORKDIR_MT="${REPO_ROOT}/progress/sprint_16/tf_state/manual_mount_target"
mkdir -p "${WORKDIR_MT}"
cp -R "${REPO_ROOT}/terraform/modules/fss_stack_sprint16_orm_advanced/mount_target/." \
  "${WORKDIR_MT}/"
cd "${WORKDIR_MT}"

terraform init

terraform apply \
  -var="region=${OCI_REGION}" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="availability_domain=${AD_NAME}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="mount_target_display_name=fss-sprint16-mt"
```

## Step 4 - Capture Mount Target Outputs

> NOT RUN - depends on Step 3 local Terraform apply.

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

## Step 5 - Deploy the Filesystem/Export Stack Locally

> NOT RUN - the Sprint 16 quality gate used OCI Resource Manager, not local Terraform state. Use this path only when local Terraform state is acceptable for the operator.

```bash
WORKDIR_FS="${REPO_ROOT}/progress/sprint_16/tf_state/manual_filesystem_export"
mkdir -p "${WORKDIR_FS}"
cp -R "${REPO_ROOT}/terraform/modules/fss_stack_sprint16_orm_advanced/filesystem_export/." \
  "${WORKDIR_FS}/"
cd "${WORKDIR_FS}"

terraform init

terraform apply \
  -var="region=${OCI_REGION}" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="availability_domain=${AD_NAME}" \
  -var="existing_mount_target_ocid=${MT_OCID}" \
  -var="filesystem_display_name=fss-sprint16-fs" \
  -var="export_1_path=/data" \
  -var="add_export_2=true" \
  -var="export_2_path=/logs"
```

## Step 6 - Read Filesystem/Export Outputs

> NOT RUN - depends on Step 5 local Terraform apply.

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
  "export_2" = "10.x.x.x:/logs"
}
```

## Step 7 - Mount and Verify

> NOT RUN - requires a compute instance with NFS client tooling and network access to the mount target subnet.

```bash
MOUNT_ADDRESS="${MT_MOUNT_ADDRESS}"

sudo mkdir -p /mnt/fss_data /mnt/fss_logs
sudo mount -t nfs "${MOUNT_ADDRESS}:/data" /mnt/fss_data
sudo mount -t nfs "${MOUNT_ADDRESS}:/logs" /mnt/fss_logs

sudo touch /mnt/fss_data/probe_sprint16 && echo "MOUNT_DATA_OK" || echo "MOUNT_DATA_FAIL"
sudo touch /mnt/fss_logs/probe_sprint16 && echo "MOUNT_LOGS_OK" || echo "MOUNT_LOGS_FAIL"

sudo umount /mnt/fss_data
sudo umount /mnt/fss_logs
```

## Step 8 - Destroy Local Terraform Stacks

> NOT RUN - depends on Steps 3 and 5 local Terraform apply.

```bash
# Destroy filesystem/export stack first.
cd "${WORKDIR_FS}"
terraform destroy \
  -var="region=${OCI_REGION}" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="availability_domain=${AD_NAME}" \
  -var="existing_mount_target_ocid=${MT_OCID}" \
  -var="export_1_path=/data"

# Then destroy mount target stack.
cd "${WORKDIR_MT}"
terraform destroy \
  -var="region=${OCI_REGION}" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="availability_domain=${AD_NAME}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

---

## OCI Resource Manager CLI Workflow

This workflow uses OCI Resource Manager instead of local Terraform state. ORM manages provider installation, state, and job history. Use this path when operators do not have Terraform installed locally or when ORM job audit history is required.

## ORM Prerequisites

> EXECUTED - evidence: `progress/sprint_16/test_run_A3_integration_20260430_141213.log`

```bash
export OCI_REGION="eu-zurich-1"
export COMPARTMENT_OCID="ocid1.compartment.oc1..example"
export SUBNET_OCID="ocid1.subnet.oc1.eu-zurich-1..example"
export AD_NAME="$(oci iam availability-domain list \
  --compartment-id "${COMPARTMENT_OCID}" \
  --query 'data[0].name' --raw-output)"
export REPO_ROOT="$(git rev-parse --show-toplevel)"
export PACKAGE_OUT="${REPO_ROOT}/progress/sprint_16/generated_tf/manual"
export ORM_WORKDIR="${REPO_ROOT}/progress/sprint_16/generated_tf/orm_apply"
mkdir -p "${PACKAGE_OUT}" "${ORM_WORKDIR}"

echo "Region:      ${OCI_REGION}"
echo "Compartment: ${COMPARTMENT_OCID}"
echo "Subnet:      ${SUBNET_OCID}"
echo "AD:          ${AD_NAME}"
```

## ORM Step 1 - Package

> EXECUTED - evidence: `progress/sprint_16/test_run_A3_integration_20260430_141213.log`

```bash
rm -f "${PACKAGE_OUT}/fss-mount-target.zip" \
      "${PACKAGE_OUT}/fss-filesystem-export.zip"

(cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint16_orm_advanced/mount_target" && \
  zip -qr "${PACKAGE_OUT}/fss-mount-target.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)

(cd "${REPO_ROOT}/terraform/modules/fss_stack_sprint16_orm_advanced/filesystem_export" && \
  zip -qr "${PACKAGE_OUT}/fss-filesystem-export.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)
```

## ORM Step 2 - Create and Apply the Mount Target Stack

> EXECUTED - evidence: `progress/sprint_16/test_run_A3_integration_20260430_141213.log`

```bash
cat >"${ORM_WORKDIR}/mt_vars.json" <<JSON
{
  "region":                    "${OCI_REGION}",
  "compartment_ocid":          "${COMPARTMENT_OCID}",
  "availability_domain":       "${AD_NAME}",
  "subnet_ocid":               "${SUBNET_OCID}",
  "mount_target_display_name": "fss-sprint16-orm-mt"
}
JSON

oci resource-manager stack create \
  --compartment-id   "${COMPARTMENT_OCID}" \
  --display-name     "fss-sprint16-orm-mount-target" \
  --description      "Sprint 16 advanced ORM mount target stack" \
  --config-source    "${PACKAGE_OUT}/fss-mount-target.zip" \
  --variables        "file://${ORM_WORKDIR}/mt_vars.json" \
  --wait-for-state   ACTIVE \
  --wait-for-state   FAILED \
  --max-wait-seconds 900 \
  >"${ORM_WORKDIR}/mt_stack_create.json"

export MT_STACK_ID="$(jq -r '.data.id' "${ORM_WORKDIR}/mt_stack_create.json")"
echo "Mount target stack: ${MT_STACK_ID}"

oci resource-manager job create-apply-job \
  --stack-id                "${MT_STACK_ID}" \
  --display-name            "fss-sprint16-orm-mt-apply" \
  --execution-plan-strategy AUTO_APPROVED \
  >"${ORM_WORKDIR}/mt_apply_job.json"

export MT_APPLY_JOB_ID="$(jq -r '.data.id' "${ORM_WORKDIR}/mt_apply_job.json")"

oci resource-manager job get \
  --job-id "${MT_APPLY_JOB_ID}" \
  --wait-for-state SUCCEEDED \
  --wait-for-state FAILED \
  --wait-for-state CANCELED \
  --max-wait-seconds 1800 \
  --wait-interval-seconds 20
```

## ORM Step 3 - Extract Mount Target Outputs

> EXECUTED - evidence: `progress/sprint_16/test_run_A3_integration_20260430_141213.log`

```bash
oci resource-manager job get-job-tf-state \
  --job-id "${MT_APPLY_JOB_ID}" \
  --file   "${ORM_WORKDIR}/mt_tf_state.json"

export MT_OCID="$(jq -r '.outputs.mount_target_ocid.value' \
  "${ORM_WORKDIR}/mt_tf_state.json")"
export MT_MOUNT_ADDRESS="$(jq -r '.outputs.mount_address.value' \
  "${ORM_WORKDIR}/mt_tf_state.json")"

echo "Mount target OCID: ${MT_OCID}"
echo "Mount address:     ${MT_MOUNT_ADDRESS}"
```

## ORM Step 4 - Create and Apply the Filesystem/Export Stack

> EXECUTED - evidence: `progress/sprint_16/test_run_A3_integration_20260430_141213.log`

```bash
cat >"${ORM_WORKDIR}/fs_vars.json" <<JSON
{
  "region":                     "${OCI_REGION}",
  "compartment_ocid":           "${COMPARTMENT_OCID}",
  "availability_domain":        "${AD_NAME}",
  "existing_mount_target_ocid": "${MT_OCID}",
  "filesystem_display_name":    "fss-sprint16-orm-fs",
  "export_1_path":              "/data",
  "add_export_2":               true,
  "export_2_path":              "/logs"
}
JSON

oci resource-manager stack create \
  --compartment-id   "${COMPARTMENT_OCID}" \
  --display-name     "fss-sprint16-orm-filesystem-export" \
  --description      "Sprint 16 advanced ORM filesystem export stack" \
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
  --display-name            "fss-sprint16-orm-fs-apply" \
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

## ORM Step 5 - Read NFS Mount Sources

> EXECUTED - evidence: `progress/sprint_16/test_run_A3_integration_20260430_141213.log`

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

## ORM Step 6 - Destroy and Delete

> EXECUTED - evidence: `progress/sprint_16/test_run_A3_integration_20260430_141213.log`; deletion verified in `progress/sprint_16/cleanup_verify_20260430_141850.log`.

```bash
oci resource-manager job create-destroy-job \
  --stack-id                "${FS_STACK_ID}" \
  --display-name            "fss-sprint16-orm-fs-destroy" \
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

oci resource-manager job create-destroy-job \
  --stack-id                "${MT_STACK_ID}" \
  --display-name            "fss-sprint16-orm-mt-destroy" \
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

oci resource-manager stack delete \
  --stack-id "${FS_STACK_ID}" --force \
  --wait-for-state DELETED --max-wait-seconds 300

oci resource-manager stack delete \
  --stack-id "${MT_STACK_ID}" --force \
  --wait-for-state DELETED --max-wait-seconds 300
```
