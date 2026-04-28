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

_resolve_compartment_ocid() {
  local compartment_path="${1:-/oci_tf_fss}"
  local root_dir state_file compartment_ocid scaffold_dir

  root_dir="$(_root_dir)"
  if [[ -n "${COMPARTMENT_OCID:-}" ]]; then
    echo "INFO: compartment OCID from COMPARTMENT_OCID (override)" >&2
    echo "$COMPARTMENT_OCID"
    return 0
  fi

  state_file="$(_foundation_scaffold_state_file "$root_dir")"
  if [[ -f "$state_file" ]]; then
    compartment_ocid="$(jq -r '.compartment.ocid // .inputs.oci_compartment // empty' "$state_file" 2>/dev/null || true)"
    if [[ -n "$compartment_ocid" && "$compartment_ocid" != "null" ]]; then
      echo "INFO: compartment OCID from foundation scaffold state (${state_file})" >&2
      echo "$compartment_ocid"
      return 0
    fi
  fi

  scaffold_dir="${root_dir}/oci_scaffold"
  if [[ ! -d "$scaffold_dir" ]]; then
    echo "FAIL: oci_scaffold missing and COMPARTMENT_OCID not set" >&2
    return 1
  fi

  export NAME_PREFIX="tf_s3_lookup"
  exec 3>&1
  exec 1>&2
  # shellcheck source=/dev/null
  source "${scaffold_dir}/do/oci_scaffold.sh"
  exec 1>&3
  exec 3>&-

  compartment_ocid="$(_oci_compartment_ocid_by_path "$compartment_path")"
  if [[ -z "$compartment_ocid" || "$compartment_ocid" == "null" ]]; then
    echo "FAIL: could not resolve compartment OCID for ${compartment_path}" >&2
    return 1
  fi
  echo "$compartment_ocid"
}

_tf_workdir() {
  local test_id="$1"
  local root_dir base dir

  root_dir="$(_root_dir)"
  base="${TF_STATE_ROOT:-${root_dir}/progress/sprint_3/tf_state}"
  dir="${base}/${test_id}"

  if [[ "${TF_RESET_TF_STATE:-true}" == "true" ]]; then
    rm -rf "$dir"
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

test_IT1_error_path_missing_required_inputs() {
  echo "=== IT-1: Error path - missing required inputs fail ==="

  local root_dir module_dir workdir artifacts_dir rc=0 ec=0
  root_dir="$(_root_dir)"
  module_dir="${root_dir}/terraform/modules/fss_sprint3"
  workdir="$(_tf_workdir it1_error_missing_required_inputs)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"

  (
    cd "$workdir"
    cat >main.tf <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fs" {
  source = "${module_dir}"
}
EOF

    terraform init -input=false
    set +e
    terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 ]]; then
      echo "FAIL: terraform validate unexpectedly succeeded without required inputs" >&2
      exit 1
    fi
    echo "PASS: IT-1"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

test_IT2_happy_path_apply_explicit_inputs() {
  echo "=== IT-2: Happy path - apply creates filesystem with explicit inputs ==="

  local root_dir module_dir compartment_ocid workdir artifacts_dir ec=0
  root_dir="$(_root_dir)"
  module_dir="${root_dir}/terraform/modules/fss_sprint3"
  compartment_ocid="$(_resolve_compartment_ocid "${COMPARTMENT_PATH:-/oci_tf_fss}")"
  workdir="$(_tf_workdir it2_happy_path)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"

  (
    cd "$workdir"
    cat >main.tf <<EOF
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
  source              = "${module_dir}"
  compartment_ocid    = "${compartment_ocid}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "fss-sprint3-it2"
}

output "filesystem_ocid" {
  value = module.fs.filesystem_ocid
}

output "filesystem_display_name" {
  value = module.fs.filesystem_display_name
}
EOF

    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"

    local fs_ocid fs_name
    fs_ocid="$(terraform output -raw filesystem_ocid)"
    fs_name="$(terraform output -raw filesystem_display_name)"
    if [[ -z "$fs_ocid" || "$fs_ocid" == "null" ]]; then
      echo "FAIL: filesystem_ocid output is empty" >&2
      exit 1
    fi
    if [[ "$fs_name" != "fss-sprint3-it2" ]]; then
      echo "FAIL: unexpected filesystem_display_name=${fs_name}" >&2
      exit 1
    fi
    echo "PASS: IT-2 (filesystem_ocid=${fs_ocid})"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

test_IT3_tag_lifecycle_idempotency() {
  echo "=== IT-3: Tag lifecycle idempotency ==="

  local root_dir module_dir compartment_ocid workdir artifacts_dir ec=0
  root_dir="$(_root_dir)"
  module_dir="${root_dir}/terraform/modules/fss_sprint3"
  compartment_ocid="$(_resolve_compartment_ocid "${COMPARTMENT_PATH:-/oci_tf_fss}")"
  workdir="$(_tf_workdir it3_tag_lifecycle)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"

  (
    cd "$workdir"
    cat >main.tf <<EOF
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
  source              = "${module_dir}"
  compartment_ocid    = "${compartment_ocid}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "fss-sprint3-it3-create"
  defined_tags        = {}
}

output "filesystem_ocid" {
  value = module.fs.filesystem_ocid
}
EOF

    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"

    echo "INFO: waiting 10s for Oracle-managed defined tags propagation"
    sleep 10

    cat >main.tf <<EOF
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
  source              = "${module_dir}"
  compartment_ocid    = "${compartment_ocid}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "fss-sprint3-it3-update"
  defined_tags        = {}
}

output "filesystem_ocid" {
  value = module.fs.filesystem_ocid
}
EOF

    set +e
    terraform plan -detailed-exitcode -input=false -out="${artifacts_dir}/update.tfplan" 2>&1 | tee "${artifacts_dir}/update_plan.stdout.log"
    rc=$?
    set -e
    if [[ "$rc" -ne 2 ]]; then
      echo "FAIL: expected display_name update plan (exit 2), got ${rc}" >&2
      exit 1
    fi
    _tf_save_plan_text "${artifacts_dir}/update.tfplan"
    if grep -Eq 'Oracle-Tags\.CreatedBy|Oracle-Tags\.CreatedOn' "${artifacts_dir}/update.tfplan.txt"; then
      echo "FAIL: update plan mentions Oracle-managed defined tags" >&2
      exit 1
    fi

    terraform apply -auto-approve -input=false "${artifacts_dir}/update.tfplan" 2>&1 | tee "${artifacts_dir}/update.stdout.log"

    set +e
    terraform plan -detailed-exitcode -input=false -out="${artifacts_dir}/post_update.tfplan" 2>&1 | tee "${artifacts_dir}/post_update_plan.stdout.log"
    rc=$?
    set -e
    if [[ "$rc" -ne 0 ]]; then
      _tf_save_plan_text "${artifacts_dir}/post_update.tfplan"
      echo "FAIL: expected no-change post-update plan (exit 0), got ${rc}" >&2
      exit 1
    fi
    _tf_save_plan_text "${artifacts_dir}/post_update.tfplan"
    echo "PASS: IT-3"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

main() {
  test_IT1_error_path_missing_required_inputs
  test_IT2_happy_path_apply_explicit_inputs
  test_IT3_tag_lifecycle_idempotency
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
