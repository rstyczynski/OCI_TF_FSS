# Sprint 13 - Operator Manual

Status: Complete

## Resource Manager Package

Use `terraform/modules/fss_stack_sprint13_orm/` when deploying the current FSS stack package through OCI Resource Manager.

This package is intentionally console-friendly. It creates one mount target, one filesystem, and one export. Use `terraform/modules/fss_stack_sprint12/` directly for map-based multi-filesystem or multi-mount-target topologies.

## Build Upload Package

From the repository root:

```bash
PACKAGE_OUT="$(pwd)/progress/sprint_13/generated_tf/manual"
mkdir -p "${PACKAGE_OUT}"

cd terraform/modules/fss_stack_sprint13_orm

zip -r "${PACKAGE_OUT}/fss_stack_sprint13_orm.zip" . \
  -x '*/.terraform/*' \
  -x '*/terraform.tfstate' \
  -x '*/terraform.tfstate.*' \
  -x '*.tfplan' \
  -x '*.log'

cd -
```

Evidence: package creation snippet rerun successfully in `progress/sprint_13/operator_manual_package_fix_20260429_172327.log`.

## Create Resource Manager Stack

```bash
export OCI_REGION=
export COMPARTMENT_OCID=
export SUBNET_OCID=

cat > progress/sprint_13/generated_tf/manual/variables.json <<EOF
{
  "region": "${OCI_REGION}",
  "compartment_ocid": "${COMPARTMENT_OCID}",
  "subnet_ocid": "${SUBNET_OCID}"
}
EOF

oci resource-manager stack create \
  --compartment-id "${COMPARTMENT_OCID}" \
  --display-name "fss-stack-sprint13-orm" \
  --config-source progress/sprint_13/generated_tf/manual/fss_stack_sprint13_orm.zip \
  --variables file://progress/sprint_13/generated_tf/manual/variables.json \
  --wait-for-state ACTIVE \
  --wait-for-state FAILED
```

For OCI Console upload, select `.zip file`. The zip root must contain `schema.yaml`, `main.tf`, `variables.tf`, and `modules/fss_stack_sprint12/`. If you upload a folder instead, select `terraform/modules/fss_stack_sprint13_orm/`, not `terraform/modules/fss_stack_sprint13_orm/modules/fss_stack_sprint12/`.

## Apply

```bash
oci resource-manager job create-apply-job \
  --stack-id "${STACK_OCID}" \
  --display-name "fss-stack-sprint13-orm-apply" \
  --execution-plan-strategy AUTO_APPROVED
```

After the job succeeds, read Terraform state outputs:

```bash
oci resource-manager job get-job-tf-state \
  --job-id "${APPLY_JOB_OCID}" \
  --file progress/sprint_13/generated_tf/manual/apply_tf_state.json

jq '.outputs.nfs_mount_sources.value' \
  progress/sprint_13/generated_tf/manual/apply_tf_state.json
```

Expected shape:

```json
{
  "data__primary": "10.0.0.76:/data"
}
```

## Destroy

```bash
oci resource-manager job create-destroy-job \
  --stack-id "${STACK_OCID}" \
  --display-name "fss-stack-sprint13-orm-destroy" \
  --execution-plan-strategy AUTO_APPROVED

oci resource-manager stack delete \
  --stack-id "${STACK_OCID}" \
  --force \
  --wait-for-state DELETED \
  --wait-for-state FAILED
```
