#!/usr/bin/env bash
set -euo pipefail

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

_teardown_workdir() {
  local workdir="$1"
  local artifacts_dir="${workdir}/tf_test_artifacts"
  mkdir -p "$artifacts_dir"

  if [[ "${SKIP_TEARDOWN:-false}" == "true" ]]; then
    echo "INFO: SKIP_TEARDOWN=true - preserving ${workdir}" >&2
    return 0
  fi
  if [[ ! -f "${workdir}/terraform.tfstate" ]] || ! jq -e '(.resources // []) | length > 0' "${workdir}/terraform.tfstate" >/dev/null 2>&1; then
    echo "INFO: no Terraform-managed resources in ${workdir}; skipping destroy" >&2
    return 0
  fi
  echo "INFO: terraform destroy in ${workdir}" >&2
  (
    cd "$workdir"
    terraform destroy -auto-approve -input=false \
      -var="compartment_ocid=$(_foundation_value '.compartment.ocid')" \
      -var="subnet_ocid=$(_foundation_value '.subnet.ocid')" \
      2>&1 | tee "${artifacts_dir}/destroy.stdout.log"
  ) || true
}

test_IT1_generated_tfvars_apply_with_sprint12_stack() {
  echo "=== IT-1: generated tfvars apply with Sprint 12 stack ==="

  local root_dir workdir artifacts_dir compartment_ocid subnet_ocid ec=0
  root_dir="$(_root_dir)"
  workdir="${root_dir}/progress/sprint_14/generated_tf/it1_apply_template2"
  artifacts_dir="${workdir}/tf_test_artifacts"
  rm -rf "$workdir"
  mkdir -p "$artifacts_dir"

  "${root_dir}/tools/convert_pv_report_to_fss_tfvars.py" \
    "${root_dir}/etc/pv-template2-details" \
    -o "${workdir}/generated.auto.tfvars"

  cat >"${workdir}/main.tf" <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

variable "compartment_ocid" {
  type = string
}

variable "subnet_ocid" {
  type = string
}

module "fss" {
  source = "../../../../terraform/modules/fss_stack_sprint12"

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid
  mount_targets    = var.mount_targets
  filesystems      = var.filesystems
}

variable "mount_targets" {
  type = any
}

variable "filesystems" {
  type = any
}

output "mount_targets" {
  value = module.fss.mount_targets
}

output "filesystems" {
  value = module.fss.filesystems
}

output "nfs_mount_sources" {
  value = module.fss.nfs_mount_sources
}
EOF

  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"

  (
    cd "$workdir"
    terraform init -input=false
    terraform validate
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan" \
      -var="compartment_ocid=${compartment_ocid}" \
      -var="subnet_ocid=${subnet_ocid}"
    terraform show -no-color "${artifacts_dir}/deploy.tfplan" >"${artifacts_dir}/deploy.tfplan.txt"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 \
      | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    local mount_count fs_count export_count nfs_count
    mount_count="$(jq '.mount_targets.value | length' "${artifacts_dir}/outputs.json")"
    fs_count="$(jq '.filesystems.value | length' "${artifacts_dir}/outputs.json")"
    export_count="$(jq '[.filesystems.value[].exports | length] | add' "${artifacts_dir}/outputs.json")"
    nfs_count="$(jq '.nfs_mount_sources.value | length' "${artifacts_dir}/outputs.json")"

    [[ "$mount_count" -eq 1 ]] || { echo "FAIL: expected 1 mount target, got ${mount_count}" >&2; exit 1; }
    [[ "$fs_count" -eq 1 ]] || { echo "FAIL: expected 1 filesystem, got ${fs_count}" >&2; exit 1; }
    [[ "$export_count" -eq 1 ]] || { echo "FAIL: expected 1 export, got ${export_count}" >&2; exit 1; }
    [[ "$nfs_count" -eq 1 ]] || { echo "FAIL: expected 1 NFS mount source, got ${nfs_count}" >&2; exit 1; }
    jq -e '.nfs_mount_sources.value | to_entries[0].value | test(".+:.+")' "${artifacts_dir}/outputs.json" >/dev/null
    echo "PASS: IT-1"
  ) || ec=$?

  _teardown_workdir "$workdir"
  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_generated_tfvars_apply_with_sprint12_stack
fi
