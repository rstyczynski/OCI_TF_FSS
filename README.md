# OCI TF FSS

Terraform components to create and manage OCI File Storage Service on Oracle Cloud.

## Contents

- [Packages](#packages)
- [Infrastructure Setup (Sprint 1, PBI-005)](#infrastructure-setup-sprint-1-pbi-005)
- [Legacy PV Converter](#legacy-pv-converter)
- [Terraform CLI](#terraform-cli)
  - [fss_stack — Basic FSS](#fss_stack--basic-fss)
  - [fss_stack — Multiple Filesystems with Logging](#fss_stack--multiple-filesystems-with-logging)
  - [fss_stack — Mount Target Only](#fss_stack--mount-target-only)
  - [fss_stack — External Mount Target](#fss_stack--external-mount-target)
  - [fss_stack — Multiple Exports on One Filesystem](#fss_stack--multiple-exports-on-one-filesystem)
- [OCI Resource Manager](#oci-resource-manager)
  - [fss_stack_orm — single stack](#fss_stack_orm--oci-resource-manager-single-stack)
  - [fss_stack_orm_advanced — split stacks](#fss_stack_orm_advanced--oci-resource-manager-split-stacks)
- [Foundation Teardown](#foundation-teardown)
- [Sprint History](#sprint-history)

## Packages

Stable release lives under `terraform/packages/` (symlinks introduced Sprint 18, PBI-033):

| Package | Sprint | Purpose |
| ------- | ------ | ------- |
| `terraform/packages/fss_stack` | Sprint 17 | Core FSS stack — Terraform CLI |
| `terraform/packages/fss_stack_orm` | Sprint 13 | OCI Resource Manager — single combined stack |
| `terraform/packages/fss_stack_orm_advanced` | Sprint 16 | OCI Resource Manager — split mount target / filesystem stacks |

---

## Infrastructure Setup (Sprint 1, PBI-005)

Provision a foundation compute instance with compartment, VCN, subnet, and KMS vault. All OCIDs needed by the FSS examples come from the scaffold state file. State is kept in `./working`.

Prerequisites: OCI CLI configured, `jq`, `ssh`, `ssh-keygen` on PATH.

```bash
export COMPARTMENT_PATH=/oci_tf_fss
export SPRINT1_NAME_PREFIX=infra
export WORKDIR=./working

mkdir -p ./working
bash tools/infra_setup.sh
```

Read OCIDs from state:

```bash
STATE_FILE="./working/state-infra.json"

export COMPARTMENT_OCID="$(jq -r '.compartment.ocid' ${STATE_FILE})"
export SUBNET_OCID="$(jq -r '.subnet.ocid' ${STATE_FILE})"
export COMPUTE_IP="$(jq -r '.compute.public_ip' ${STATE_FILE})"
export OCI_REGION="$(jq -r '.inputs.oci_region' ${STATE_FILE})"

echo "Compartment: ${COMPARTMENT_OCID}"
echo "Subnet:      ${SUBNET_OCID}"
echo "Compute:     ${COMPUTE_IP}"
echo "Region:      ${OCI_REGION}"
```

Set repo root (run once per shell session):

```bash
export REPO_ROOT="$(git rev-parse --show-toplevel)"
```

SSH to the instance:

```bash
WORKDIR="${REPO_ROOT}/working" "${REPO_ROOT}/tools/go_remote.sh"
# or a one-shot command:
WORKDIR="${REPO_ROOT}/working" "${REPO_ROOT}/tools/go_remote.sh" sudo cloud-init status
```

---

## Legacy PV Converter

Convert a legacy Kubernetes/NFS PV report to `fss_stack` variables, then apply. Each distinct legacy `server` becomes one mount target; each PV becomes one filesystem with a `primary` export preserving the legacy NFS `path`.

Template files for testing: `etc/pv-template1-details`, `etc/pv-template2-details`, `etc/pv-template3-details`.

```bash
cd "${REPO_ROOT}"

export PV_REPORT="etc/pv-template2-details"   # use template1 or template3 for larger sets

mkdir -p working

"${REPO_ROOT}/tools/convert_pv_report_to_fss_tfvars.py" \
  "${PV_REPORT}" \
  -o working/generated.auto.tfvars

# Review before applying
sed -n '1,80p' working/generated.auto.tfvars
```

Plan and apply directly against the `fss_stack` package root, passing the generated vars file explicitly:

```bash
EXAMPLE=pv_converter
export TF_DATA_DIR="${REPO_ROOT}/working/${EXAMPLE}/.terraform"
mkdir -p "${REPO_ROOT}/working/${EXAMPLE}"

cd "${REPO_ROOT}/terraform/packages/fss_stack"
terraform init

terraform plan \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var-file="${REPO_ROOT}/working/generated.auto.tfvars" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -out="${REPO_ROOT}/working/${EXAMPLE}/tfplan"

terraform show -no-color "${REPO_ROOT}/working/${EXAMPLE}/tfplan" | less   # confirm resource count

terraform apply \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  "${REPO_ROOT}/working/${EXAMPLE}/tfplan"
```

Read mount sources:

```bash
terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources | jq
# { "pv_static_007__primary": "10.0.0.105:/legacy-nas-b/tenant-gamma/pv-static-007" }
```

Mount from a client:

```bash
NFS_SOURCE="$(terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources | jq -r 'to_entries[0].value')"
WORKDIR="${REPO_ROOT}/working" "${REPO_ROOT}/tools/go_remote.sh" <<EOF
  sudo mkdir -p /mnt/fss-test
  sudo mount -t nfs -o vers=3,noacl ${NFS_SOURCE} /mnt/fss-test
  df -h /mnt/fss-test
  sudo umount /mnt/fss-test
EOF
```

Teardown:

```bash
terraform destroy -auto-approve \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var-file="${REPO_ROOT}/working/generated.auto.tfvars" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

---

## Terraform CLI

### fss_stack — Basic FSS

One mount target, one filesystem, one NFS export. Only `compartment_ocid` and `subnet_ocid` required. AD is derived automatically; encryption is Oracle-managed by default.

```bash
EXAMPLE=basic_fss
export TF_DATA_DIR="${REPO_ROOT}/working/${EXAMPLE}/.terraform"
mkdir -p "${REPO_ROOT}/working/${EXAMPLE}"

cd "${REPO_ROOT}/terraform/packages/fss_stack/examples/${EXAMPLE}"
terraform init
terraform apply -auto-approve \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

Read the mount source and mount it:

```bash
terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources
# { "data__primary" = "10.0.0.5:/data" }

NFS_SOURCE=$(terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources | jq -r '."data__primary"')
WORKDIR="${REPO_ROOT}/working" "${REPO_ROOT}/tools/go_remote.sh" <<EOF
  sudo mkdir -p /mnt/data
  sudo mount -t nfs -o vers=3,noacl ${NFS_SOURCE} /mnt/data 
  df -h /mnt/data
  sudo umount /mnt/data
EOF
```

Read AD selection and encryption mode:

```bash
terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -raw availability_domain_source   # "subnet" or "random"
terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -raw kms_key_mode                 # "ORACLE_MANAGED"
```

Teardown:

```bash
terraform destroy -auto-approve \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

---

### fss_stack — Multiple Filesystems with Logging

Two mount targets, two filesystems, three exports. `primary` mount target has OCI Logging enabled. One export uses `identity_squash = "NONE"` for administrator access.

```bash
EXAMPLE=multi_fss_with_logging
export TF_DATA_DIR="${REPO_ROOT}/working/${EXAMPLE}/.terraform"
mkdir -p "${REPO_ROOT}/working/${EXAMPLE}"

cd "${REPO_ROOT}/terraform/packages/fss_stack/examples/${EXAMPLE}"
terraform init
terraform apply -auto-approve \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

Read all mount sources and identity_squash per export:

```bash
terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources
# {
#   "backup__primary"  = "10.0.0.5:/backup",
#   "data__primary"    = "10.0.0.5:/data",
#   "data__secondary"  = "10.0.0.6:/data-secondary"
# }

terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json filesystems | jq '.data.exports | to_entries[] | {(.key): .value.identity_squash}'
# { "primary": "NONE" }
# { "secondary": "ROOT" }
```

Mount `data__primary` (identity_squash=NONE — admin writes allowed) and verify:

```bash
NFS_SOURCE=$(terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources | jq -r '."data__primary"')
WORKDIR="${REPO_ROOT}/working" "${REPO_ROOT}/tools/go_remote.sh" <<EOF
  sudo mkdir -p /mnt/data
  sudo mount -t nfs -o vers=3,noacl ${NFS_SOURCE} /mnt/data
  df -h /mnt/data
  sudo touch /mnt/data/admin_probe && echo "WRITE_OK" || echo "WRITE_FAIL"
  sudo umount /mnt/data
EOF
```

Verify OCI Logging is active and search for NFS events:

```bash
LOG_GROUP=$(terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json mount_targets | jq -r '.primary.logging.log_group_ocid')
LOG_OCID=$(terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json mount_targets | jq -r '.primary.logging.log_ocid')

# Confirm log is ACTIVE
oci logging log get \
  --log-group-id "${LOG_GROUP}" \
  --log-id       "${LOG_OCID}" \
  | jq '.data | {id, "is-enabled", "lifecycle-state"}'

# Search for NFS log events from the last 15 minutes
# (macOS date; on Linux replace -v-15M with -d '15 minutes ago')
TIME_START=$(date -u -v-15M '+%Y-%m-%dT%H:%M:%SZ')
TIME_END=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

oci logging-search search-logs \
  --time-start  "${TIME_START}" \
  --time-end    "${TIME_END}" \
  --search-query "search \"${COMPARTMENT_OCID}/${LOG_GROUP}/${LOG_OCID}\" | sort by datetime desc" \
  --limit 10 \
  | jq '[.data.results[] | {time: .data.logContent.time, message: .data.logContent.data}]'
```

> **OCI FSS `nfslogs` behavior** (confirmed by Sprint 8 integration test): the only log entry ever produced is the activation message `"Public Logging is enabled for nfs with log level ERROR"`. Mount operations, file I/O, CIDR access denials, and identity squash events do **not** generate log entries. The activation message confirms the logging pipeline is correctly wired to the mount target — that is the complete expected output.

Teardown:

```bash
terraform destroy -auto-approve \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

---

### fss_stack — Mount Target Only

Create a standalone mount target without any filesystems. Its OCID is then used as an external reference in the next example.

```bash
EXAMPLE=mount_target_only
export TF_DATA_DIR="${REPO_ROOT}/working/${EXAMPLE}/.terraform"
mkdir -p "${REPO_ROOT}/working/${EXAMPLE}"

cd "${REPO_ROOT}/terraform/packages/fss_stack/examples/${EXAMPLE}"
terraform init
terraform apply -auto-approve \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

Capture the mount target OCID for use in the next example:

```bash
export EXTERNAL_MOUNT_TARGET_OCID=$(terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json mount_target_ocids | jq -r '.primary')

echo "Mount target OCID: ${EXTERNAL_MOUNT_TARGET_OCID}"
```

Teardown section moved to next example as we need this resource.

---

### fss_stack — External Mount Target

Attach a filesystem to an existing mount target not managed by this stack. Uses the mount target created above via `EXTERNAL_MOUNT_TARGET_OCID`.

```bash
EXAMPLE=external_mount_target
export TF_DATA_DIR="${REPO_ROOT}/working/${EXAMPLE}/.terraform"
mkdir -p "${REPO_ROOT}/working/${EXAMPLE}"

cd "${REPO_ROOT}/terraform/packages/fss_stack/examples/${EXAMPLE}"
terraform init
terraform apply -auto-approve \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="external_mount_target_ocid=${EXTERNAL_MOUNT_TARGET_OCID}"
```

Read outputs:

```bash
terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources
terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json filesystems
```

Teardown — destroy filesystem exports first, then the mount target:

```bash
cd "${REPO_ROOT}/terraform/packages/fss_stack/examples/external_mount_target"
terraform destroy -auto-approve \
  -state="${REPO_ROOT}/working/external_mount_target/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}" \
  -var="external_mount_target_ocid=${EXTERNAL_MOUNT_TARGET_OCID}"

cd "${REPO_ROOT}/terraform/packages/fss_stack/examples/mount_target_only"
terraform destroy -auto-approve \
  -state="${REPO_ROOT}/working/mount_target_only/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

---

### fss_stack — Multiple Exports on One Filesystem

One mount target, one filesystem, two NFS export paths (`/vol1` and `/vol2`).

> **SAME-ROOT behavior** (verified Sprint 19, PBI-035): both paths expose the same filesystem root. A file written via `/vol1` is immediately visible via `/vol2`. Use separate filesystems for data isolation.

```bash
EXAMPLE=multi_exports_one_fs
export TF_DATA_DIR="${REPO_ROOT}/working/${EXAMPLE}/.terraform"
mkdir -p "${REPO_ROOT}/working/${EXAMPLE}"

cd "${REPO_ROOT}/terraform/packages/fss_stack/examples/${EXAMPLE}"
terraform init
terraform apply -auto-approve \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

Read mount sources:

```bash
terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources
# { "shared__vol1": "<mt_ip>:/vol1", "shared__vol2": "<mt_ip>:/vol2" }
```

Mount both exports and verify SAME-ROOT behavior:

```bash
VOL1=$(terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources | jq -r '."shared__vol1"')
VOL2=$(terraform output \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -json nfs_mount_sources | jq -r '."shared__vol2"')

WORKDIR="${REPO_ROOT}/working" "${REPO_ROOT}/tools/go_remote.sh" <<EOF
  sudo yum install -y nfs-utils 2>/dev/null || true
  sudo mkdir -p /mnt/vol1 /mnt/vol2
  sudo mount -t nfs -o vers=3,noacl ${VOL1} /mnt/vol1
  sudo mount -t nfs -o vers=3,noacl ${VOL2} /mnt/vol2
  df -hT /mnt/vol1 /mnt/vol2

  SENTINEL="sentinel_\$(date +%Y%m%d%H%M%S).txt"
  echo "written_via_vol1" | sudo tee /mnt/vol1/\${SENTINEL}

  echo "--- /mnt/vol1 after write:"
  ls /mnt/vol1
  echo "--- /mnt/vol2 after write (identical if SAME-ROOT):"
  ls /mnt/vol2

  test -f /mnt/vol2/\${SENTINEL} && echo "SAME_ROOT=YES" || echo "SAME_ROOT=NO"

  sudo rm -f /mnt/vol1/\${SENTINEL}
  sudo umount /mnt/vol1
  sudo umount /mnt/vol2
EOF
```

Teardown:

```bash
terraform destroy -auto-approve \
  -state="${REPO_ROOT}/working/${EXAMPLE}/terraform.tfstate" \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

---

## OCI Resource Manager

### fss_stack_orm — OCI Resource Manager (single stack)

Creates one mount target, one filesystem, and one export. Managed entirely by OCI Resource Manager.

Build the upload package:

```bash
mkdir -p working
(cd terraform/packages/fss_stack_orm && \
  zip -r "$(pwd)/../working/fss_stack_orm.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)
```

Create and apply the stack:

```bash
cat > working/vars.json <<EOF
{
  "region":           "${OCI_REGION}",
  "compartment_ocid": "${COMPARTMENT_OCID}",
  "subnet_ocid":      "${SUBNET_OCID}"
}
EOF

oci resource-manager stack create \
  --compartment-id   "${COMPARTMENT_OCID}" \
  --display-name     "fss-stack-orm" \
  --config-source    working/fss_stack_orm.zip \
  --variables        file://working/vars.json \
  --wait-for-state   ACTIVE \
  > working/stack_create.json

export STACK_OCID="$(jq -r '.data.id' working/stack_create.json)"

oci resource-manager job create-apply-job \
  --stack-id                "${STACK_OCID}" \
  --display-name            "fss-stack-orm-apply" \
  --execution-plan-strategy AUTO_APPROVED
```

Read NFS mount sources from the apply job:

```bash
oci resource-manager job get-job-tf-state \
  --job-id "${APPLY_JOB_OCID}" \
  --file   working/apply_tf_state.json

jq '.outputs.nfs_mount_sources.value' working/apply_tf_state.json
# { "data__primary": "10.0.0.76:/data" }
```

Destroy and delete:

```bash
oci resource-manager job create-destroy-job \
  --stack-id                "${STACK_OCID}" \
  --display-name            "fss-stack-orm-destroy" \
  --execution-plan-strategy AUTO_APPROVED

oci resource-manager stack delete \
  --stack-id "${STACK_OCID}" --force \
  --wait-for-state DELETED
```

---

### fss_stack_orm_advanced — OCI Resource Manager (split stacks)

Two independent stacks: create the mount target first, then attach filesystems. Destroy in reverse order.

Build both packages:

```bash
mkdir -p working

(cd terraform/packages/fss_stack_orm_advanced/mount_target && \
  zip -qr "$(pwd)/../../working/fss-mount-target.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)

(cd terraform/packages/fss_stack_orm_advanced/filesystem_export && \
  zip -qr "$(pwd)/../../working/fss-filesystem-export.zip" \
    main.tf variables.tf outputs.tf schema.yaml versions.tf modules/)
```

**Step 1 — create mount target:**

```bash
export AD_NAME="$(oci iam availability-domain list \
  --compartment-id "${COMPARTMENT_OCID}" \
  --query 'data[0].name' --raw-output)"

cat > working/mt_vars.json <<EOF
{
  "region":                    "${OCI_REGION}",
  "compartment_ocid":          "${COMPARTMENT_OCID}",
  "availability_domain":       "${AD_NAME}",
  "subnet_ocid":               "${SUBNET_OCID}",
  "mount_target_display_name": "fss-mt"
}
EOF

oci resource-manager stack create \
  --compartment-id   "${COMPARTMENT_OCID}" \
  --display-name     "fss-mount-target" \
  --config-source    working/fss-mount-target.zip \
  --variables        file://working/mt_vars.json \
  --wait-for-state   ACTIVE \
  > working/mt_stack_create.json

export MT_STACK_OCID="$(jq -r '.data.id' working/mt_stack_create.json)"

oci resource-manager job create-apply-job \
  --stack-id                "${MT_STACK_OCID}" \
  --display-name            "fss-mt-apply" \
  --execution-plan-strategy AUTO_APPROVED \
  > working/mt_apply_job.json

export MT_APPLY_JOB_OCID="$(jq -r '.data.id' working/mt_apply_job.json)"

oci resource-manager job get \
  --job-id "${MT_APPLY_JOB_OCID}" \
  --wait-for-state SUCCEEDED --wait-for-state FAILED \
  --max-wait-seconds 1800 --wait-interval-seconds 20
```

Extract mount target OCID for step 2:

```bash
oci resource-manager job get-job-tf-state \
  --job-id "${MT_APPLY_JOB_OCID}" \
  --file   working/mt_tf_state.json

export MT_OCID="$(jq -r '.outputs.mount_target_ocid.value' working/mt_tf_state.json)"
echo "Mount target OCID: ${MT_OCID}"
```

**Step 2 — create filesystem and exports:**

```bash
cat > working/fs_vars.json <<EOF
{
  "region":                     "${OCI_REGION}",
  "compartment_ocid":           "${COMPARTMENT_OCID}",
  "availability_domain":        "${AD_NAME}",
  "existing_mount_target_ocid": "${MT_OCID}",
  "filesystem_display_name":    "fss-data",
  "export_1_path":              "/data",
  "add_export_2":               true,
  "export_2_path":              "/logs"
}
EOF

oci resource-manager stack create \
  --compartment-id   "${COMPARTMENT_OCID}" \
  --display-name     "fss-filesystem-export" \
  --config-source    working/fss-filesystem-export.zip \
  --variables        file://working/fs_vars.json \
  --wait-for-state   ACTIVE \
  > working/fs_stack_create.json

export FS_STACK_OCID="$(jq -r '.data.id' working/fs_stack_create.json)"

oci resource-manager job create-apply-job \
  --stack-id                "${FS_STACK_OCID}" \
  --display-name            "fss-fs-apply" \
  --execution-plan-strategy AUTO_APPROVED \
  > working/fs_apply_job.json

export FS_APPLY_JOB_OCID="$(jq -r '.data.id' working/fs_apply_job.json)"

oci resource-manager job get \
  --job-id "${FS_APPLY_JOB_OCID}" \
  --wait-for-state SUCCEEDED --wait-for-state FAILED \
  --max-wait-seconds 1800 --wait-interval-seconds 20
```

Read NFS mount sources:

```bash
oci resource-manager job get-job-tf-state \
  --job-id "${FS_APPLY_JOB_OCID}" \
  --file   working/fs_tf_state.json

jq '.outputs.nfs_mount_sources.value' working/fs_tf_state.json
# { "export_1": "10.x.x.x:/data", "export_2": "10.x.x.x:/logs" }
```

Destroy (filesystem first, mount target second):

```bash
oci resource-manager job create-destroy-job \
  --stack-id "${FS_STACK_OCID}" --execution-plan-strategy AUTO_APPROVED \
  > working/fs_destroy_job.json
oci resource-manager job get \
  --job-id "$(jq -r '.data.id' working/fs_destroy_job.json)" \
  --wait-for-state SUCCEEDED --wait-for-state FAILED --max-wait-seconds 1800

oci resource-manager job create-destroy-job \
  --stack-id "${MT_STACK_OCID}" --execution-plan-strategy AUTO_APPROVED \
  > working/mt_destroy_job.json
oci resource-manager job get \
  --job-id "$(jq -r '.data.id' working/mt_destroy_job.json)" \
  --wait-for-state SUCCEEDED --wait-for-state FAILED --max-wait-seconds 1800

oci resource-manager stack delete --stack-id "${FS_STACK_OCID}" --force \
  --wait-for-state DELETED
oci resource-manager stack delete --stack-id "${MT_STACK_OCID}" --force \
  --wait-for-state DELETED
```

---

## Foundation Teardown

Run this only after all FSS resources provisioned in the examples above have been destroyed.

```bash
cd ./working
export NAME_PREFIX="${SPRINT1_NAME_PREFIX:-infra}"
export PATH="$(git rev-parse --show-toplevel)/oci_scaffold/do:$(git rev-parse --show-toplevel)/oci_scaffold/resource:${PATH}"
bash "$(git rev-parse --show-toplevel)/oci_scaffold/do/teardown.sh"
```

---

## Sprint History

| Sprint | PBI | Topic |
| ------ | --- | ----- |
| 1 | PBI-005 | Foundation compute for integration tests |
| 2–3 | PBI-001, PBI-006 | FSS filesystem module + Terraform architecture rules |
| 4 | PBI-002–004 | Mount target, export, Network Path Analyzer test |
| 5 | PBI-007–009 | KMS key support, full config surface, stack module |
| 6 | PBI-010–011 | NFS mount + admin task validation |
| 7 | PBI-019 | Stack variable refactor (M:N mount target / filesystem topology) |
| 8 | PBI-016 | Mount target logging |
| 9–11 | PBI-013, PBI-014, PBI-020–022 | v1/v2 packaging and README |
| 12 | PBI-024 | Examples + modules layout (`fss_stack_sprint12`) |
| 13 | PBI-023 | OCI Resource Manager packaging |
| 14 | PBI-027 | Legacy PV report converter |
| 15–16 | PBI-026, PBI-028, PBI-030 | ORM advanced stacks (BUG-11 fix in Sprint 16) |
| 17 | PBI-031, PBI-032 | External mount targets + per-MT placement overrides |
| 18 | PBI-033 | Stable `terraform/packages/` release symlinks |
| 19 | PBI-035 | Multi-export SAME-ROOT experiment |
