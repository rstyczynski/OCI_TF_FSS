# Sprint 14 - Operator Manual

Status: Complete

## Convert a Legacy PV Report

Prerequisite: run from the repository root with Python 3 available.

```bash
tools/convert_pv_report_to_fss_tfvars.py \
  etc/pv-template1-details \
  -o progress/sprint_14/generated_tf/template1.auto.tfvars
```

The generated `.auto.tfvars` file is compatible with `terraform/modules/fss_stack_sprint12/` and contains:

- one mount target per distinct legacy NFS server
- one filesystem per PV
- one `primary` export per filesystem

## Use With FSS Stack

Create a Terraform root that uses `terraform/modules/fss_stack_sprint12/` and pass the generated `.auto.tfvars` file together with required placement variables:

```bash
terraform apply \
  -var-file=progress/sprint_14/generated_tf/template1.auto.tfvars \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

Evidence for the converter command is captured by the Sprint 14 unit gate. Evidence for the stack apply path is captured by the Sprint 14 integration gate.

Evidence:

- Converter command pattern: `progress/sprint_14/test_run_A2_unit_20260429_130459.log`
- Sprint 12 stack apply/destroy path: `progress/sprint_14/test_run_A3_integration_20260429_130514.log`
