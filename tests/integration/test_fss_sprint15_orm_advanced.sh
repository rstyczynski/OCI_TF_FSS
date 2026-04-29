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

_generated_dir() {
  local name="$1"
  local root_dir base dir

  root_dir="$(_root_dir)"
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_15/generated_tf}"
  dir="${base}/${name}"

  if [[ "${TF_RESET_TF_STATE:-true}" == "true" ]]; then
    rm -rf "$dir"
  fi
  mkdir -p "$dir"
  echo "$dir"
}

_create_stack_zip() {
  local stack_dir="$1"
  local workdir="$2"
  local zip_path="${workdir}/$(basename "$stack_dir").zip"

  rm -f "$zip_path"
  (
    cd "$stack_dir"
    zip -qr "$zip_path" . \
      -x '*/.terraform/*' \
      -x '.terraform/*' \
      -x '.terraform.lock.hcl' \
      -x 'terraform.tfstate' \
      -x 'terraform.tfstate.*' \
      -x '*.tfplan' \
      -x '*.log'
  )
  echo "$zip_path"
}

_wait_job_terminal() {
  local job_id="$1"
  local timeout_seconds="${2:-1800}"
  local start now state

  start="$(date +%s)"
  while true; do
    state="$(oci resource-manager job get --job-id "$job_id" --query 'data."lifecycle-state"' --raw-output)"
    echo "INFO: Resource Manager job ${job_id} state=${state}" >&2
    case "$state" in
      SUCCEEDED|FAILED|CANCELED)
        [[ "$state" == "SUCCEEDED" ]]
        return $?
        ;;
    esac

    now="$(date +%s)"
    if ((now - start > timeout_seconds)); then
      echo "FAIL: timeout waiting for Resource Manager job ${job_id}" >&2
      return 1
    fi
    sleep 20
  done
}

_delete_stack() {
  local stack_id="${1:-}"
  [[ -z "$stack_id" || "$stack_id" == "null" ]] && return 0
  echo "INFO: deleting Resource Manager stack ${stack_id}" >&2
  oci resource-manager stack delete \
    --stack-id "$stack_id" \
    --force \
    --wait-for-state DELETED \
    --wait-for-state FAILED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 15 >/dev/null || true
}

_first_availability_domain() {
  local compartment_ocid="$1"
  oci iam availability-domain list \
    --compartment-id "$compartment_ocid" \
    --query 'data[0].name' \
    --raw-output
}

_apply_stack() {
  local stack_id="$1"
  local display_name="$2"
  local out_json="$3"
  local job_id

  oci resource-manager job create-apply-job \
    --stack-id "$stack_id" \
    --display-name "$display_name" \
    --execution-plan-strategy AUTO_APPROVED >"$out_json"
  job_id="$(jq -r '.data.id // empty' "$out_json")"
  echo "$job_id"
  _wait_job_terminal "$job_id" 1800
}

_destroy_stack() {
  local stack_id="$1"
  local display_name="$2"
  local out_json="$3"
  local job_id

  oci resource-manager job create-destroy-job \
    --stack-id "$stack_id" \
    --display-name "$display_name" \
    --execution-plan-strategy AUTO_APPROVED >"$out_json"
  job_id="$(jq -r '.data.id // empty' "$out_json")"
  echo "$job_id"
  _wait_job_terminal "$job_id" 1800
}

test_IT1_resource_manager_advanced_workflow() {
  echo "=== IT-1: Resource Manager advanced workflow ==="

  local root_dir package_dir workdir region compartment_ocid subnet_ocid availability_domain
  local mt_zip fs_zip mt_vars fs_vars mt_stack_json fs_stack_json mt_stack_id fs_stack_id
  local mt_apply_json fs_apply_json fs_state_json mt_state_json mt_ocid fs_destroy_json mt_destroy_json
  local ec=0

  root_dir="$(_root_dir)"
  package_dir="${root_dir}/terraform/modules/fss_stack_sprint15_orm_advanced"
  workdir="$(_generated_dir orm_advanced_apply)"

  region="$(_foundation_value '.inputs.oci_region')"
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  availability_domain="$(_first_availability_domain "$compartment_ocid")"

  mt_zip="$(_create_stack_zip "${package_dir}/mount_target" "$workdir")"
  fs_zip="$(_create_stack_zip "${package_dir}/filesystem_export" "$workdir")"

  mt_vars="${workdir}/mount_target_variables.json"
  fs_vars="${workdir}/filesystem_export_variables.json"
  mt_stack_json="${workdir}/mount_target_stack_create.json"
  fs_stack_json="${workdir}/filesystem_export_stack_create.json"

  jq -n \
    --arg region "$region" \
    --arg compartment_ocid "$compartment_ocid" \
    --arg availability_domain "$availability_domain" \
    --arg subnet_ocid "$subnet_ocid" \
    --arg display_name "fss-sprint15-orm-mt" \
    '{region: $region, compartment_ocid: $compartment_ocid, availability_domain: $availability_domain, subnet_ocid: $subnet_ocid, mount_target_display_name: $display_name}' >"$mt_vars"

  (
    oci resource-manager stack create \
      --compartment-id "$compartment_ocid" \
      --display-name "fss-sprint15-orm-mount-target" \
      --description "Sprint 15 advanced ORM mount target stack" \
      --config-source "$mt_zip" \
      --variables "file://${mt_vars}" \
      --wait-for-state ACTIVE \
      --wait-for-state FAILED \
      --max-wait-seconds 900 \
      --wait-interval-seconds 15 >"$mt_stack_json"

    mt_stack_id="$(jq -r '.data.id // empty' "$mt_stack_json")"
    echo "$mt_stack_id" >"${workdir}/mount_target_stack_ocid.txt"

    mt_apply_json="${workdir}/mount_target_apply_job.json"
    _apply_stack "$mt_stack_id" "fss-sprint15-orm-mount-target-apply" "$mt_apply_json" >"${workdir}/mount_target_apply_job_ocid.txt"
    oci resource-manager job get-job-tf-state \
      --job-id "$(cat "${workdir}/mount_target_apply_job_ocid.txt")" \
      --file "${workdir}/mount_target_tf_state.json"
    mt_state_json="${workdir}/mount_target_tf_state.json"
    mt_ocid="$(jq -r '.outputs.mount_target_ocid.value // empty' "$mt_state_json")"
    if [[ -z "$mt_ocid" || "$mt_ocid" == "null" ]]; then
      echo "FAIL: mount_target_ocid missing from mount target stack outputs" >&2
      exit 1
    fi

    jq -n \
      --arg region "$region" \
      --arg compartment_ocid "$compartment_ocid" \
      --arg availability_domain "$availability_domain" \
      --arg mount_target_ocid "$mt_ocid" \
      '{region: $region, compartment_ocid: $compartment_ocid, availability_domain: $availability_domain, existing_mount_target_ocid: $mount_target_ocid, filesystem_display_name: "fss-sprint15-orm-fs", export_1_path: "/data", add_export_2: true, export_2_path: "/logs"}' >"$fs_vars"

    oci resource-manager stack create \
      --compartment-id "$compartment_ocid" \
      --display-name "fss-sprint15-orm-filesystem-export" \
      --description "Sprint 15 advanced ORM filesystem export stack" \
      --config-source "$fs_zip" \
      --variables "file://${fs_vars}" \
      --wait-for-state ACTIVE \
      --wait-for-state FAILED \
      --max-wait-seconds 900 \
      --wait-interval-seconds 15 >"$fs_stack_json"

    fs_stack_id="$(jq -r '.data.id // empty' "$fs_stack_json")"
    echo "$fs_stack_id" >"${workdir}/filesystem_export_stack_ocid.txt"

    fs_apply_json="${workdir}/filesystem_export_apply_job.json"
    _apply_stack "$fs_stack_id" "fss-sprint15-orm-filesystem-export-apply" "$fs_apply_json" >"${workdir}/filesystem_export_apply_job_ocid.txt"
    oci resource-manager job get-job-tf-state \
      --job-id "$(cat "${workdir}/filesystem_export_apply_job_ocid.txt")" \
      --file "${workdir}/filesystem_export_tf_state.json"
    fs_state_json="${workdir}/filesystem_export_tf_state.json"

    local nfs_count
    nfs_count="$(jq '.outputs.nfs_mount_sources.value | length' "$fs_state_json")"
    [[ "$nfs_count" -eq 2 ]] || { echo "FAIL: expected 2 NFS mount sources, got ${nfs_count}" >&2; exit 1; }
    jq -e '.outputs.nfs_mount_sources.value.export_1 | test(".+:/data")' "$fs_state_json" >/dev/null
    jq -e '.outputs.nfs_mount_sources.value.export_2 | test(".+:/logs")' "$fs_state_json" >/dev/null

    fs_destroy_json="${workdir}/filesystem_export_destroy_job.json"
    _destroy_stack "$fs_stack_id" "fss-sprint15-orm-filesystem-export-destroy" "$fs_destroy_json" >"${workdir}/filesystem_export_destroy_job_ocid.txt"

    mt_destroy_json="${workdir}/mount_target_destroy_job.json"
    _destroy_stack "$mt_stack_id" "fss-sprint15-orm-mount-target-destroy" "$mt_destroy_json" >"${workdir}/mount_target_destroy_job_ocid.txt"

    echo "PASS: IT-1 (mount_target_ocid=${mt_ocid}, nfs_count=${nfs_count})"
  ) || ec=$?

  if [[ "$ec" -ne 0 && "${SKIP_TEARDOWN:-false}" != "true" ]]; then
    if [[ -n "${fs_stack_id:-}" && "${fs_stack_id}" != "null" ]]; then
      _destroy_stack "$fs_stack_id" "fss-sprint15-orm-filesystem-export-cleanup" "${workdir}/filesystem_export_cleanup_destroy_job.json" || true
      _delete_stack "$fs_stack_id"
    fi
    if [[ -n "${mt_stack_id:-}" && "${mt_stack_id}" != "null" ]]; then
      _destroy_stack "$mt_stack_id" "fss-sprint15-orm-mount-target-cleanup" "${workdir}/mount_target_cleanup_destroy_job.json" || true
      _delete_stack "$mt_stack_id"
    fi
  fi

  if [[ "${SKIP_TEARDOWN:-false}" != "true" ]]; then
    _delete_stack "${fs_stack_id:-}"
    _delete_stack "${mt_stack_id:-}"
  fi

  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_resource_manager_advanced_workflow
fi
