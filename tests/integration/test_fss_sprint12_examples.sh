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

_tf_artifacts_dir() {
  local workdir="$1"
  mkdir -p "${workdir}/tf_test_artifacts"
  echo "${workdir}/tf_test_artifacts"
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

# ---------------------------------------------------------------------------

test_IT1_examples_validate() {
  echo "=== IT-1: Examples validate ==="

  local root_dir ec=0
  root_dir="$(_root_dir)"

  for example in basic_fss multi_fss_with_logging; do
    local example_dir="${root_dir}/terraform/modules/fss_stack_sprint12/examples/${example}"
    local artifacts_dir="${root_dir}/progress/sprint_12/generated_tf/${example}/tf_test_artifacts"
    mkdir -p "$artifacts_dir"

    echo "--- validating ${example} ---"
    (
      cd "$example_dir"
      terraform init -input=false
      set +e
      terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
      local rc=$?
      set -e
      if [[ "$rc" -ne 0 ]]; then
        echo "FAIL: terraform validate failed for ${example}" >&2
        exit 1
      fi
      if ! grep -q "The configuration is valid" "${artifacts_dir}/validate.stdout.log"; then
        echo "FAIL: validate output does not confirm success for ${example}" >&2
        exit 1
      fi
      echo "PASS: ${example} validates"
    ) || { echo "FAIL: IT-1 failed for ${example}" >&2; ec=1; }
  done

  [[ "$ec" -eq 0 ]] && echo "PASS: IT-1"
  return "$ec"
}

test_IT2_basic_example_applies() {
  echo "=== IT-2: Basic example applies ==="

  local root_dir compartment_ocid subnet_ocid example_dir artifacts_dir ec=0
  root_dir="$(_root_dir)"
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  example_dir="${root_dir}/terraform/modules/fss_stack_sprint12/examples/basic_fss"
  artifacts_dir="${root_dir}/progress/sprint_12/generated_tf/basic_fss/tf_test_artifacts"
  mkdir -p "$artifacts_dir"

  (
    cd "$example_dir"
    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan" \
      -var="compartment_ocid=${compartment_ocid}" \
      -var="subnet_ocid=${subnet_ocid}"
    terraform show -no-color "${artifacts_dir}/deploy.tfplan" >"${artifacts_dir}/deploy.tfplan.txt"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 \
      | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    local nfs_source ad_source kms_mode
    nfs_source="$(jq -r '.nfs_mount_sources.value | to_entries[0].value // empty' "${artifacts_dir}/outputs.json")"
    ad_source="$(jq -r '.availability_domain_source.value // empty' "${artifacts_dir}/outputs.json")"
    kms_mode="$(jq -r '.kms_key_mode.value // empty' "${artifacts_dir}/outputs.json")"

    if [[ -z "$nfs_source" || "$nfs_source" == "null" ]]; then
      echo "FAIL: nfs_mount_sources output is empty" >&2
      exit 1
    fi
    if ! echo "$nfs_source" | grep -qE '.+:.+'; then
      echo "FAIL: nfs_mount_source '${nfs_source}' does not match <addr>:<path> pattern" >&2
      exit 1
    fi
    if [[ "$kms_mode" != "ORACLE_MANAGED" ]]; then
      echo "FAIL: expected kms_key_mode=ORACLE_MANAGED, got ${kms_mode}" >&2
      exit 1
    fi
    echo "PASS: IT-2 (nfs_source=${nfs_source}, ad_source=${ad_source}, kms=${kms_mode})"
  ) || ec=$?

  if [[ "${SKIP_TEARDOWN:-false}" != "true" ]]; then
    local state_json="${example_dir}/terraform.tfstate"
    if [[ -f "$state_json" ]] && jq -e '(.resources // []) | length > 0' "$state_json" >/dev/null 2>&1; then
      echo "INFO: terraform destroy (test teardown) in ${example_dir}" >&2
      (cd "$example_dir" && terraform destroy -auto-approve -input=false \
        -var="compartment_ocid=${compartment_ocid}" \
        -var="subnet_ocid=${subnet_ocid}" \
        2>&1 | tee "${artifacts_dir}/destroy.stdout.log") || true
    fi
  fi
  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_examples_validate
  test_IT2_basic_example_applies
fi
