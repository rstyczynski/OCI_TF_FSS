# Sprint 14 - Operator Manual

Status: Complete

## Purpose

Sprint 14 converts a legacy Kubernetes/NFS PV report into Terraform variables for the current FSS stack package at `terraform/modules/fss_stack_sprint12/`.

The normal operator flow is:

1. Pick a legacy PV report.
2. Generate an `.auto.tfvars` file.
3. Review the generated mount targets, filesystems, and export paths.
4. Apply the generated variables with the Sprint 12 stack.
5. Capture NFS mount source outputs.
6. Destroy the test stack when validation is complete.

## Prerequisites

Run from the repository root.

```bash
pwd
# /Users/rstyczynski/projects/OCI_TF_FSS
```

Set the OCI placement variables. These values can come from the Sprint 1 foundation state or from your target environment.

```bash
export COMPARTMENT_OCID="<target-compartment-ocid>"
export SUBNET_OCID="<target-subnet-ocid>"
```

Python 3 and Terraform must be available on `PATH`.

```bash
python3 --version
terraform version
```

## Step 1 - Choose the Report

The anonymized templates are stored under `etc/`:

```bash
ls -1 etc/pv-template*-details
```

Use the smallest template for a first deploy test:

```bash
export PV_REPORT="etc/pv-template2-details"
```

Use a larger report when you are ready to review more generated filesystems:

```bash
export PV_REPORT="etc/pv-template1-details"
# or
export PV_REPORT="etc/pv-template3-details"
```

## Step 2 - Generate Terraform Variables

Create the operator review directory under the sprint home:

```bash
mkdir -p progress/sprint_14/generated_tf/operator_apply
```

Generate the `.auto.tfvars` file:

```bash
tools/convert_pv_report_to_fss_tfvars.py \
  "${PV_REPORT}" \
  -o progress/sprint_14/generated_tf/operator_apply/generated.auto.tfvars
```

The generated file contains:

- one mount target per distinct legacy NFS server
- one filesystem per PV
- one `primary` export per filesystem
- freeform tags with legacy PV name, NFS server, storage class, and original path

Review the generated file before applying:

```bash
sed -n '1,220p' progress/sprint_14/generated_tf/operator_apply/generated.auto.tfvars
```

The generated export path preserves the legacy NFS path. This is intentional because the old mount contract is encoded in the PV `path` field.

## Step 3 - Review the Terraform Root

The Sprint 14 operator root is stored at:

```bash
progress/sprint_14/generated_tf/operator_apply/main.tf
```

It passes generated `mount_targets` and `filesystems` directly into `terraform/modules/fss_stack_sprint12/`.

```bash
sed -n '1,220p' progress/sprint_14/generated_tf/operator_apply/main.tf
```

## Step 4 - Initialize and Validate

Move into the generated Terraform root:

```bash
cd progress/sprint_14/generated_tf/operator_apply
```

Initialize providers:

```bash
terraform init
```

Validate the root module:

```bash
terraform validate
```

## Step 5 - Plan

Create a plan and keep it for review:

```bash
terraform plan \
  -out=tfplan \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

Inspect the plan:

```bash
terraform show -no-color tfplan | less
```

Check that the number of created mount targets and filesystems matches the generated variables before applying.

## Step 6 - Apply

Apply the reviewed plan:

```bash
terraform apply tfplan
```

## Step 7 - Read Mount Information

Print ready-to-use NFS mount sources:

```bash
terraform output -json nfs_mount_sources | jq
```

Example shape:

```json
{
  "pv_static_007__primary": "10.0.0.105:/legacy-nas-b/tenant-gamma/pv-static-007"
}
```

Print mount target details:

```bash
terraform output -json mount_targets | jq
```

The `mount_address` field is the preferred NFS server address. It is an FQDN when OCI returns one, otherwise it falls back to the mount target private IP.

## Step 8 - Mount From a Client

Use one value from `nfs_mount_sources` on a compute instance that can reach the mount target subnet.

```bash
NFS_SOURCE="$(terraform output -json nfs_mount_sources | jq -r 'to_entries[0].value')"
export SSH_CMD="ssh opc@1.1.2.2"

${SSH_CMD} "sudo mkdir -p /mnt/fss-test && \
  sudo mount -t nfs -o vers=3,noacl ${NFS_SOURCE} /mnt/fss-test && \
  df -h /mnt/fss-test"
```

## Step 9 - Destroy

Destroy the test deployment from the same directory:

```bash
terraform destroy \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

Return to the repository root:

```bash
cd ../../../..
```

## Troubleshooting

If the converter fails with `missing storageclass`, `missing path`, `missing server`, or `missing name`, the source report has an incomplete PV block. Fix the source report or remove the incomplete block before regenerating variables.

If `terraform plan` creates more resources than expected, inspect `generated.auto.tfvars`. The converter creates one filesystem per PV block and one mount target per distinct `server` value.

If a client cannot mount the output source, check subnet routing, security lists or NSGs, and whether the client is in a network path that can reach the mount target private IP.

## Evidence

The Sprint 14 quality gates executed the same workflow with the Sprint 12 stack:

- Converter command pattern: `progress/sprint_14/test_run_A2_unit_20260429_130459.log`
- Sprint 12 stack apply/destroy path: `progress/sprint_14/test_run_A3_integration_20260429_130514.log`
- Operator root `terraform init` and `terraform validate`: `progress/sprint_14/operator_manual_validate_20260429_135500.log`
