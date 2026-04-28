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

_tf_workdir() {
  local test_id="$1"
  local root_dir base dir

  root_dir="$(_root_dir)"
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_4/generated_tf}"
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

_write_stack_tf() {
  local workdir="$1"
  local test_id="$2"
  local root_dir filesystem_module mount_target_module export_module
  local compartment_ocid subnet_ocid subnet_cidr export_path display_suffix

  root_dir="$(_root_dir)"
  filesystem_module="${root_dir}/terraform/modules/fss_sprint3"
  mount_target_module="${root_dir}/terraform/modules/fss_sprint4_mount_target"
  export_module="${root_dir}/terraform/modules/fss_sprint4_export"

  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  subnet_cidr="$(_foundation_value '.subnet.cidr')"
  display_suffix="${test_id//_/-}"
  export_path="/sprint4-${display_suffix}"

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

module "fs" {
  source              = "${filesystem_module}"
  compartment_ocid    = "${compartment_ocid}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "fss-sprint4-${display_suffix}"
}

module "mt" {
  source              = "${mount_target_module}"
  compartment_ocid    = "${compartment_ocid}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_ocid         = "${subnet_ocid}"
  display_name        = "fss-sprint4-mt-${display_suffix}"
}

data "oci_core_private_ip" "mount_target" {
  private_ip_id = module.mt.mount_target_private_ip_ids[0]
}

module "export" {
  source           = "${export_module}"
  export_set_ocid  = module.mt.mount_target_export_set_ocid
  file_system_ocid = module.fs.filesystem_ocid
  path             = "${export_path}"
  source_cidr      = "${subnet_cidr}"
}

output "filesystem_ocid" {
  value = module.fs.filesystem_ocid
}

output "mount_target_ocid" {
  value = module.mt.mount_target_ocid
}

output "mount_target_export_set_ocid" {
  value = module.mt.mount_target_export_set_ocid
}

output "mount_target_private_ip_ids" {
  value = module.mt.mount_target_private_ip_ids
}

output "mount_target_private_ip" {
  value = data.oci_core_private_ip.mount_target.ip_address
}

output "export_ocid" {
  value = module.export.export_ocid
}

output "export_path" {
  value = module.export.export_path
}

output "source_cidr" {
  value = "${subnet_cidr}"
}
EOF
}

_apply_stack() {
  local test_id="$1"
  local workdir="$2"
  local artifacts_dir

  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_stack_tf "$workdir" "$test_id"

  (
    cd "$workdir"
    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"
  )
}

_output_raw() {
  local workdir="$1"
  local name="$2"
  (cd "$workdir" && terraform output -raw "$name")
}

_output_json_query() {
  local workdir="$1"
  local jq_expr="$2"
  jq -r "$jq_expr" "${workdir}/tf_test_artifacts/outputs.json"
}

_run_path_analyzer() {
  local test_id="$1"
  local dst_ip="$2"
  local root_dir scaffold_dir foundation_state npa_prefix npa_dir npa_state result

  root_dir="$(_root_dir)"
  scaffold_dir="${root_dir}/oci_scaffold"
  foundation_state="$(_foundation_scaffold_state_file "$root_dir")"
  npa_prefix="sprint4npa-${test_id//_/-}"
  npa_dir="${root_dir}/progress/sprint_4/scaffold/${npa_prefix}"
  npa_state="${npa_dir}/state-${npa_prefix}.json"

  if [[ ! -d "$scaffold_dir" ]]; then
    echo "FAIL: missing oci_scaffold submodule at ${scaffold_dir}" >&2
    return 1
  fi
  if [[ ! -f "$foundation_state" ]]; then
    echo "FAIL: missing Sprint 1 foundation state: ${foundation_state}" >&2
    return 1
  fi

  rm -rf "$npa_dir"
  mkdir -p "$npa_dir"
  jq \
    --arg dst_ip "$dst_ip" \
    --arg label "sprint4-${test_id}-nfs" \
    '.inputs.path_analyzer_dst_ip = $dst_ip
      | .inputs.path_analyzer_protocol = "tcp"
      | .inputs.path_analyzer_port = "2049"
      | .inputs.path_analyzer_label = $label
      | .inputs.path_analyzer_timeout = "180"
      | .path_analyzer = []' \
    "$foundation_state" >"$npa_state"

  (
    cd "$npa_dir"
    export NAME_PREFIX="$npa_prefix"
    export PATH="${scaffold_dir}/do:${scaffold_dir}/resource:${PATH}"
    bash "${scaffold_dir}/resource/ensure-path_analyzer.sh"
  )

  result="$(jq -r '.path_analyzer[-1].result // empty' "$npa_state")"
  echo "INFO: path analyzer result=${result} destination=${dst_ip}:2049"
  if [[ "$result" != "SUCCEEDED" ]]; then
    echo "FAIL: expected Network Path Analyzer result SUCCEEDED, got ${result:-empty}" >&2
    return 1
  fi
}

test_IT1_mount_target_happy_path() {
  echo "=== IT-1: Mount target happy path ==="

  local workdir ec=0 mt_ocid export_set_ocid private_ip_count
  workdir="$(_tf_workdir it1_mount_target)"

  _apply_stack it1_mount_target "$workdir" || ec=$?
  if [[ "$ec" -eq 0 ]]; then
    mt_ocid="$(_output_raw "$workdir" mount_target_ocid)"
    export_set_ocid="$(_output_raw "$workdir" mount_target_export_set_ocid)"
    private_ip_count="$(_output_json_query "$workdir" '.mount_target_private_ip_ids.value | length')"

    if [[ -z "$mt_ocid" || "$mt_ocid" == "null" ]]; then
      echo "FAIL: mount_target_ocid output is empty" >&2
      ec=1
    elif [[ -z "$export_set_ocid" || "$export_set_ocid" == "null" ]]; then
      echo "FAIL: mount_target_export_set_ocid output is empty" >&2
      ec=1
    elif [[ "$private_ip_count" -lt 1 ]]; then
      echo "FAIL: expected at least one mount target private IP ID" >&2
      ec=1
    else
      echo "PASS: IT-1 (mount_target_ocid=${mt_ocid})"
    fi
  fi

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

test_IT2_export_happy_path() {
  echo "=== IT-2: Export happy path ==="

  local workdir ec=0 export_ocid export_path
  workdir="$(_tf_workdir it2_export)"

  _apply_stack it2_export "$workdir" || ec=$?
  if [[ "$ec" -eq 0 ]]; then
    export_ocid="$(_output_raw "$workdir" export_ocid)"
    export_path="$(_output_raw "$workdir" export_path)"

    if [[ -z "$export_ocid" || "$export_ocid" == "null" ]]; then
      echo "FAIL: export_ocid output is empty" >&2
      ec=1
    elif [[ "$export_path" != "/sprint4-it2-export" ]]; then
      echo "FAIL: unexpected export_path=${export_path}" >&2
      ec=1
    else
      echo "PASS: IT-2 (export_ocid=${export_ocid}, export_path=${export_path})"
    fi
  fi

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

test_IT3_path_analyzer_reachability() {
  echo "=== IT-3: Network Path Analyzer reachability ==="

  local workdir ec=0 mount_target_ip
  workdir="$(_tf_workdir it3_path_analyzer)"

  _apply_stack it3_path_analyzer "$workdir" || ec=$?
  if [[ "$ec" -eq 0 ]]; then
    mount_target_ip="$(_output_raw "$workdir" mount_target_private_ip)"
    if [[ -z "$mount_target_ip" || "$mount_target_ip" == "null" ]]; then
      echo "FAIL: mount_target_private_ip output is empty" >&2
      ec=1
    else
      _run_path_analyzer it3_path_analyzer "$mount_target_ip" || ec=$?
    fi
  fi

  _tf_teardown_workdir "$workdir"
  if [[ "$ec" -eq 0 ]]; then
    echo "PASS: IT-3"
  fi
  return "$ec"
}

main() {
  test_IT1_mount_target_happy_path
  test_IT2_export_happy_path
  test_IT3_path_analyzer_reachability
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
