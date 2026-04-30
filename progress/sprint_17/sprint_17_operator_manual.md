# Sprint 17 — Operator manual

This manual covers `terraform/modules/fss_stack_sprint17`, which supports:

- mount targets that are created by the stack (default)
- mount targets that are externally managed and referenced by OCID (`mount_targets[*].external_ocid`)
- per-mount-target placement overrides (`mount_targets[*].subnet_ocid`, `mount_targets[*].availability_domain`)

## Prerequisites

- Terraform >= 1.5
- OCI Terraform provider prerequisites configured (tenancy/user/region/auth)
- Variables ready:
  - `COMPARTMENT_OCID`
  - `SUBNET_OCID`

If you plan to use externally managed mount targets, you also need:

- `EXTERNAL_MOUNT_TARGET_OCID` (an existing mount target OCID)

## Quick validate (no OCI credentials required)

Purpose: confirm the module and examples are syntactically valid.

Evidence: see the D1 gate logs referenced in `progress/sprint_17/sprint_17_tests.md`.

```bash
cd terraform/modules/fss_stack_sprint17
terraform init -backend=false
terraform validate
```

```bash
cd examples/basic_fss
terraform init -backend=false
terraform validate
```

```bash
cd ../multi_fss_with_logging
terraform init -backend=false
terraform validate
```

```bash
cd ../mount_target_only
terraform init -backend=false
terraform validate
```

```bash
cd ../external_mount_target
terraform init -backend=false
terraform validate
```

## Example: create only mount target(s)

Directory: `terraform/modules/fss_stack_sprint17/examples/mount_target_only`

### Apply

NOT RUN — requires live OCI environment and credentials.

```bash
cd terraform/modules/fss_stack_sprint17/examples/mount_target_only
terraform init
terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

### Read outputs

NOT RUN — requires live OCI environment and credentials.

```bash
cd terraform/modules/fss_stack_sprint17/examples/mount_target_only
terraform output -json mount_targets
terraform output -json mount_target_ocids
```

### Destroy

NOT RUN — requires live OCI environment and credentials.

```bash
cd terraform/modules/fss_stack_sprint17/examples/mount_target_only
terraform destroy \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

## Example: create filesystem+export using an externally managed mount target

Directory: `terraform/modules/fss_stack_sprint17/examples/external_mount_target`

This example is intended to be used after you have an existing mount target OCID (for example created by `mount_target_only` above, or created by another stack).

### Configure the mount target entry

Edit `terraform/modules/fss_stack_sprint17/examples/external_mount_target/main.tf` to set:

- `mount_targets.existing_mt.external_ocid = EXTERNAL_MOUNT_TARGET_OCID`
- optional placement overrides:
  - `mount_targets.existing_mt.subnet_ocid`
  - `mount_targets.existing_mt.availability_domain`

### Apply

NOT RUN — requires live OCI environment and credentials.

```bash
cd terraform/modules/fss_stack_sprint17/examples/external_mount_target
terraform init
terraform apply
```

### Read outputs

NOT RUN — requires live OCI environment and credentials.

```bash
cd terraform/modules/fss_stack_sprint17/examples/external_mount_target
terraform output -json nfs_mount_sources
terraform output -json filesystems
```

### Destroy

NOT RUN — requires live OCI environment and credentials.

```bash
cd terraform/modules/fss_stack_sprint17/examples/external_mount_target
terraform destroy
```

## Example: basic stack

Directory: `terraform/modules/fss_stack_sprint17/examples/basic_fss`

NOT RUN — requires live OCI environment and credentials.

```bash
cd terraform/modules/fss_stack_sprint17/examples/basic_fss
terraform init
terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

## Example: multi stack with logging

Directory: `terraform/modules/fss_stack_sprint17/examples/multi_fss_with_logging`

NOT RUN — requires live OCI environment and credentials.

```bash
cd terraform/modules/fss_stack_sprint17/examples/multi_fss_with_logging
terraform init
terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

