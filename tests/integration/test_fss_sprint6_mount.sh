#!/usr/bin/env bash
set -euo pipefail

# Sprint 6 integration tests: FSS mount and administration operations.
# PBI-010: Mount FSS file system(s) on a compute instance
# PBI-011: Perform administrator tasks for FSS mount(s)

_root_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

_foundation_scaffold_prefix() {
  if [[ "${SPRINT1_USE_ENV_NAME_PREFIX:-false}" == "true" && -n "${NAME_PREFIX:-}" ]]; then
    echo "$NAME_PREFIX"
  else
    echo "${SPRINT1_NAME_PREFIX:-infra}"
  fi
}

_foundation_scaffold_state_file() {
  local root_dir="$1"
  local prefix

  if [[ -n "${SPRINT1_FOUNDATION_STATE_FILE:-}" ]]; then
    echo "${SPRINT1_FOUNDATION_STATE_FILE}"
    return 0
  fi

  prefix="$(_foundation_scaffold_prefix)"
  if [[ -n "${WORKDIR:-}" ]]; then
    echo "${WORKDIR}/state-${prefix}.json"
  else
    echo "${root_dir}/progress/sprint_1/scaffold/${prefix}/state-${prefix}.json"
  fi
}

_foundation_value() {
  local jq_expr="$1"
  local root_dir state_file value

  root_dir="$(_root_dir)"
  state_file="$(_foundation_scaffold_state_file "$root_dir")"
  if [[ ! -f "$state_file" ]]; then
    echo "FAIL: missing Sprint 1 foundation state: ${state_file}" >&2
    return 1
  fi

  value="$(jq -r "${jq_expr} // empty" "$state_file")"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "FAIL: foundation state ${state_file} missing ${jq_expr}" >&2
    return 1
  fi
  echo "$value"
}

_tf_workdir() {
  local test_id="$1"
  local root_dir base dir

  root_dir="$(_root_dir)"
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_6/generated_tf}"
  dir="${base}/${test_id}"

  if [[ "${TF_RESET_TF_STATE:-true}" == "true" ]]; then
    find "$dir" -mindepth 1 \
      ! -name main.tf \
      ! -name README.md \
      -exec rm -rf {} + 2>/dev/null || true
  fi
  mkdir -p "$dir"
  echo "$dir"
}

_tf_artifacts_dir() {
  local workdir="$1"
  mkdir -p "${workdir}/tf_test_artifacts"
  echo "${workdir}/tf_test_artifacts"
}

_tf_save_plan_text() {
  local plan_bin="$1"
  terraform show -no-color "$plan_bin" >"${plan_bin}.txt"
}

_tf_teardown_workdir() {
  local workdir="$1"
  local skip_teardown="${SKIP_TEARDOWN:-false}"
  local state_json="${workdir}/terraform.tfstate"

  [[ -z "$workdir" || ! -d "$workdir" ]] && return 0

  if [[ "$skip_teardown" == "true" ]]; then
    echo "INFO: SKIP_TEARDOWN=true - terraform state preserved at: ${workdir}" >&2
    return 0
  fi

  mkdir -p "${workdir}/tf_test_artifacts"
  if [[ ! -f "$state_json" ]] || ! jq -e '(.resources // []) | length > 0' "$state_json" >/dev/null 2>&1; then
    echo "INFO: no Terraform-managed resources in state - skipping terraform destroy (${workdir})" >&2
    return 0
  fi

  echo "INFO: terraform destroy (test teardown) in ${workdir}" >&2
  (cd "$workdir" && terraform destroy -auto-approve -input=false 2>&1 | tee "${workdir}/tf_test_artifacts/destroy.stdout.log") || true
}

_module_source() {
  local workdir="$1"
  local module_name="$2"
  local root_dir default_generated_root

  root_dir="$(_root_dir)"
  default_generated_root="${root_dir}/progress/sprint_6/generated_tf"
  if [[ "$workdir" == "${default_generated_root}/"* ]]; then
    echo "../../../../terraform/modules/${module_name}"
  else
    echo "${root_dir}/terraform/modules/${module_name}"
  fi
}

# Ensure Sprint 5 MEK exists (reuse from Sprint 5 test)
_ensure_sprint5_mek() {
  local root_dir scaffold_dir foundation_state mek_prefix mek_dir mek_state
  local compartment_ocid vault_mgmt_endpoint key_ocid

  root_dir="$(_root_dir)"
  scaffold_dir="${root_dir}/oci_scaffold"
  foundation_state="$(_foundation_scaffold_state_file "$root_dir")"
  mek_prefix="${SPRINT5_MEK_NAME_PREFIX:-sprint5-fss-mek}"
  mek_dir="${root_dir}/progress/sprint_5/scaffold/fss-mek"
  mek_state="${mek_dir}/state-${mek_prefix}.json"

  if [[ -f "$mek_state" ]]; then
    key_ocid="$(jq -r '.key.ocid // empty' "$mek_state")"
    if [[ -n "$key_ocid" && "$key_ocid" != "null" ]]; then
      echo "$key_ocid"
      return 0
    fi
  fi

  echo "FAIL: Sprint 5 MEK not found. Run Sprint 5 tests first to create MEK." >&2
  return 1
}

# Materialize SSH key from Vault
_materialize_ssh_key() {
  local root_dir="$1"
  local dest="$2"
  local foundation_state secret_ocid

  foundation_state="$(_foundation_scaffold_state_file "$root_dir")"
  secret_ocid="$(jq -r '.secret.ocid // empty' "$foundation_state")"

  if [[ -z "$secret_ocid" || "$secret_ocid" == "null" ]]; then
    echo "FAIL: no .secret.ocid in foundation state" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  source "${root_dir}/tools/infra_setup.sh"
  sprint1__raw_key_from_secret_bundle "$secret_ocid" "$dest"
}

# Write Terraform config for Sprint 6 FSS stack
_write_sprint6_stack_tf() {
  local workdir="$1"
  local compartment_ocid="$2"
  local subnet_ocid="$3"
  local subnet_cidr="$4"
  local kms_key_id="$5"
  local module_source

  module_source="$(_module_source "$workdir" fss_sprint5_stack)"
  cat >"${workdir}/main.tf" <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = "${compartment_ocid}"
}

module "stack" {
  source              = "${module_source}"
  compartment_ocid    = "${compartment_ocid}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = "${subnet_ocid}"
  kms_key_id          = "${kms_key_id}"
  default_source_cidr = "${subnet_cidr}"

  filesystems = {
    sprint6test = {
      filesystem_display_name = "fss-sprint6-test"
      export_path             = "/sprint6-test"
      identity_squash         = "NONE"
      freeform_tags = {
        sprint = "6"
        test   = "mount"
      }
    }
  }
}

output "filesystems" {
  value = module.stack.filesystems
}

output "mount_target_mount_addresses" {
  value = module.stack.mount_target_mount_addresses
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}
EOF
}

# IT-1: Mount FSS export on compute instance
test_IT1_mount_fss_export() {
  echo "=== IT-1: Mount FSS export on compute instance ==="

  local root_dir compartment_ocid subnet_ocid subnet_cidr kms_key_id
  local workdir artifacts_dir ec=0
  local compute_public_ip ssh_key

  root_dir="$(_root_dir)"
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  subnet_cidr="$(_foundation_value '.subnet.cidr')"
  compute_public_ip="$(_foundation_value '.compute.public_ip')"
  kms_key_id="$(_ensure_sprint5_mek)"

  workdir="$(_tf_workdir it1_mount_fss)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_sprint6_stack_tf "$workdir" "$compartment_ocid" "$subnet_ocid" "$subnet_cidr" "$kms_key_id"

  ssh_key="$(mktemp)"
  _materialize_ssh_key "$root_dir" "$ssh_key"

  _it1_cleanup() {
    rm -f "$ssh_key"
    _tf_teardown_workdir "$workdir"
  }

  (
    set -euo pipefail
    cd "$workdir"

    # Deploy FSS stack
    echo "INFO: deploying FSS stack..."
    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    # Get ready-to-use NFS mount source from stack output.
    local nfs_mount_source
    nfs_mount_source="$(jq -r '.nfs_mount_sources.value.sprint6test' "${artifacts_dir}/outputs.json")"

    if [[ -z "$nfs_mount_source" || "$nfs_mount_source" == "null" ]]; then
      echo "FAIL: NFS mount source not found in stack outputs" >&2
      exit 1
    fi

    echo "INFO: nfs_mount_source=${nfs_mount_source}"

    # SSH to compute and mount FSS
    local mount_point="/mnt/fss/sprint6test"
    local test_file="${mount_point}/test_file_$$"

    echo "INFO: connecting to compute instance at ${compute_public_ip}..."

    # Install NFS utils if needed
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo yum install -y nfs-utils 2>/dev/null || echo 'nfs-utils already installed or yum unavailable'" \
      2>&1 | tee "${artifacts_dir}/nfs_install.log"

    # Create mount point and mount FSS
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo mkdir -p ${mount_point} && \
       sudo mount -t nfs -o vers=3,noacl ${nfs_mount_source} ${mount_point}" \
      2>&1 | tee "${artifacts_dir}/mount.log"

    # Verify mount
    local mount_check
    mount_check=$(ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "mount | grep '${mount_point}' || true")

    if [[ -z "$mount_check" ]]; then
      echo "FAIL: FSS not mounted at ${mount_point}" >&2
      exit 1
    fi
    echo "INFO: mount verified: ${mount_check}"

    # Test file write and read
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "echo 'Sprint 6 test content' | sudo tee ${test_file} && \
       sudo cat ${test_file}" \
      2>&1 | tee "${artifacts_dir}/file_test.log"

    # Verify file content
    local file_content
    file_content=$(ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo cat ${test_file}")

    if [[ "$file_content" != "Sprint 6 test content" ]]; then
      echo "FAIL: file content mismatch" >&2
      exit 1
    fi
    echo "INFO: file write/read verified"

    # Cleanup: remove test file and unmount
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo rm -f ${test_file} && sudo umount ${mount_point}" \
      2>&1 | tee "${artifacts_dir}/cleanup.log"

    echo "PASS: IT-1 (nfs_mount_source=${nfs_mount_source})"
  ) || ec=$?

  _it1_cleanup
  return "$ec"
}

# IT-2: Administrator operations on mounted FSS
test_IT2_admin_operations() {
  echo "=== IT-2: Administrator operations on mounted FSS ==="

  local root_dir compartment_ocid subnet_ocid subnet_cidr kms_key_id
  local workdir artifacts_dir ec=0
  local compute_public_ip ssh_key

  root_dir="$(_root_dir)"
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  subnet_cidr="$(_foundation_value '.subnet.cidr')"
  compute_public_ip="$(_foundation_value '.compute.public_ip')"
  kms_key_id="$(_ensure_sprint5_mek)"

  workdir="$(_tf_workdir it2_admin_ops)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_sprint6_stack_tf "$workdir" "$compartment_ocid" "$subnet_ocid" "$subnet_cidr" "$kms_key_id"

  ssh_key="$(mktemp)"
  _materialize_ssh_key "$root_dir" "$ssh_key"

  _it2_cleanup() {
    rm -f "$ssh_key"
    _tf_teardown_workdir "$workdir"
  }

  (
    set -euo pipefail
    cd "$workdir"

    # Deploy FSS stack
    echo "INFO: deploying FSS stack..."
    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    # Get ready-to-use NFS mount source from stack output.
    local nfs_mount_source
    nfs_mount_source="$(jq -r '.nfs_mount_sources.value.sprint6test' "${artifacts_dir}/outputs.json")"
    if [[ -z "$nfs_mount_source" || "$nfs_mount_source" == "null" ]]; then
      echo "FAIL: NFS mount source not found in stack outputs" >&2
      exit 1
    fi

    local mount_point="/mnt/fss/sprint6admin"
    local test_dir="${mount_point}/admin_test_$$"
    local test_user="opc"

    echo "INFO: mounting FSS for admin operations..."

    # Install NFS utils and mount
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo yum install -y nfs-utils 2>/dev/null || true && \
       sudo mkdir -p ${mount_point} && \
       sudo mount -t nfs -o vers=3,noacl ${nfs_mount_source} ${mount_point}" \
      2>&1 | tee "${artifacts_dir}/mount.log"

    # Admin operation 1: Create directory structure
    echo "INFO: testing directory creation..."
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo mkdir -p ${test_dir}/subdir1/subdir2" \
      2>&1 | tee "${artifacts_dir}/mkdir.log"

    # Admin operation 2: Change ownership
    echo "INFO: testing chown..."
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo chown -R ${test_user}:${test_user} ${test_dir}" \
      2>&1 | tee "${artifacts_dir}/chown.log"

    # Verify ownership
    local owner
    owner=$(ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "stat -c '%U' ${test_dir}")

    if [[ "$owner" != "$test_user" ]]; then
      echo "FAIL: ownership change failed, expected ${test_user}, got ${owner}" >&2
      exit 1
    fi
    echo "INFO: ownership verified: ${owner}"

    # Admin operation 3: Set permissions
    echo "INFO: testing chmod..."
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "chmod 750 ${test_dir}" \
      2>&1 | tee "${artifacts_dir}/chmod.log"

    # Verify permissions
    local perms
    perms=$(ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "stat -c '%a' ${test_dir}")

    if [[ "$perms" != "750" ]]; then
      echo "FAIL: permission change failed, expected 750, got ${perms}" >&2
      exit 1
    fi
    echo "INFO: permissions verified: ${perms}"

    # Admin operation 4: Create and delete files
    echo "INFO: testing file creation and deletion..."
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "echo 'test content' > ${test_dir}/testfile.txt && \
       ls -la ${test_dir}/testfile.txt && \
       rm ${test_dir}/testfile.txt && \
       ! test -f ${test_dir}/testfile.txt && echo 'File deleted successfully'" \
      2>&1 | tee "${artifacts_dir}/file_ops.log"

    # Admin operation 5: Test remount persistence
    echo "INFO: testing remount persistence..."
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "echo 'persistent data' > ${test_dir}/persist.txt && \
       sudo umount ${mount_point} && \
       sudo mount -t nfs -o vers=3,noacl ${nfs_mount_source} ${mount_point} && \
       cat ${test_dir}/persist.txt" \
      2>&1 | tee "${artifacts_dir}/remount.log"

    # Verify persistent data
    local persist_content
    persist_content=$(ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "cat ${test_dir}/persist.txt")

    if [[ "$persist_content" != "persistent data" ]]; then
      echo "FAIL: data persistence check failed after remount" >&2
      exit 1
    fi
    echo "INFO: remount persistence verified"

    # Cleanup: remove test artifacts and unmount
    echo "INFO: cleaning up..."
    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "rm -rf ${test_dir} && sudo umount ${mount_point} && sudo rmdir ${mount_point}" \
      2>&1 | tee "${artifacts_dir}/cleanup.log"

    echo "PASS: IT-2"
  ) || ec=$?

  _it2_cleanup
  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_mount_fss_export
  test_IT2_admin_operations
fi
