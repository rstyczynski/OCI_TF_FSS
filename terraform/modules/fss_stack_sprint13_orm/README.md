# FSS Resource Manager Package

This Terraform root packages the current `fss_stack_sprint12` stack for OCI Resource Manager.

It creates the common Resource Manager Console topology:

- one mount target
- one filesystem
- one export
- optional mount target NFS service logging

For multi-filesystem, multi-mount-target, or M:N export topologies, use `terraform/modules/fss_stack_sprint12/` directly.

## Files

| File | Purpose |
|---|---|
| `schema.yaml` | OCI Resource Manager Console metadata, variables, groups, and output labels. |
| `main.tf` | Maps console-friendly scalar inputs into the current stack module maps. |
| `variables.tf` | Terraform variables that match `schema.yaml`. |
| `outputs.tf` | Resource Manager-visible stack outputs. |

## Package for Resource Manager

Create the upload zip from the repository root so the package can reference the current stack package as a sibling module:

```bash
cd terraform/modules/fss_stack_sprint13_orm

zip -r ../../../progress/sprint_13/generated_tf/fss_stack_sprint13_orm.zip . \
  -x '*/.terraform/*' \
  -x '*/terraform.tfstate' \
  -x '*/terraform.tfstate.*' \
  -x '*.tfplan' \
  -x '*.log'
```

Upload the zip as a `.zip file` in OCI Resource Manager. The zip root contains `schema.yaml`, `main.tf`, and the embedded `modules/fss_stack_sprint12/` implementation.

Create the stack with OCI CLI:

```bash
oci resource-manager stack create \
  --compartment-id "${COMPARTMENT_OCID}" \
  --display-name "fss-stack-sprint13-orm" \
  --config-source progress/sprint_13/generated_tf/fss_stack_sprint13_orm.zip \
  --variables "{\"region\":\"${OCI_REGION}\",\"compartment_ocid\":\"${COMPARTMENT_OCID}\",\"subnet_ocid\":\"${SUBNET_OCID}\"}"
```

Run an apply job:

```bash
oci resource-manager job create-apply-job \
  --stack-id "${STACK_OCID}" \
  --execution-plan-strategy AUTO_APPROVED \
  --wait-for-state SUCCEEDED \
  --wait-for-state FAILED
```

Read mount information from Resource Manager outputs:

```bash
oci resource-manager job get-job-tf-state --job-id "${APPLY_JOB_OCID}" --file -
```

The key output is `nfs_mount_sources`, with values in `<mount-address>:<export-path>` form.
