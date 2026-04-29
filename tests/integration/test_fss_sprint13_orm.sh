#!/usr/bin/env bash
set -euo pipefail

# Sprint 13 integration tests: OCI Resource Manager packaging for fss_stack_sprint12.

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
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_13/generated_tf}"
  dir="${base}/${name}"

  if [[ "${TF_RESET_TF_STATE:-true}" == "true" ]]; then
    rm -rf "$dir"
  fi
  mkdir -p "$dir"
  echo "$dir"
}

_copy_package_tree() {
  local dest="$1"
  local root_dir

  root_dir="$(_root_dir)"
  mkdir -p "${dest}/terraform/modules"
  cp -R "${root_dir}/terraform/modules/fss_stack_sprint13_orm" "${dest}/terraform/modules/"
  find "$dest" \
    \( -name .terraform -o -name terraform.tfstate -o -name 'terraform.tfstate.*' -o -name '*.tfplan' \) \
    -exec rm -rf {} + 2>/dev/null || true
}

_create_package_zip() {
  local workdir="$1"
  local zip_path="${workdir}/fss_stack_sprint13_orm.zip"
  local package_dir="${workdir}/terraform/modules/fss_stack_sprint13_orm"

  rm -f "$zip_path"
  (
    cd "$package_dir"
    zip -qr "$zip_path" . \
      -x '*/.terraform/*' \
      -x '*/terraform.tfstate' \
      -x '*/terraform.tfstate.*' \
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
    echo "INFO: Resource Manager job ${job_id} state=${state}"
    case "$state" in
      SUCCEEDED|FAILED|CANCELED)
        [[ "$state" == "SUCCEEDED" ]]
        return $?
        ;;
    esac

    now="$(date +%s)"
    if (( now - start > timeout_seconds )); then
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

test_IT1_orm_package_validates_locally() {
  echo "=== IT-1: ORM package validates locally ==="

  local workdir package_dir schema_path
  workdir="$(_generated_dir orm_package_static)"
  _copy_package_tree "$workdir"
  package_dir="${workdir}/terraform/modules/fss_stack_sprint13_orm"
  schema_path="${package_dir}/schema.yaml"

  python3 - "$schema_path" <<'PY'
import sys
import yaml

schema_path = sys.argv[1]
with open(schema_path, "r", encoding="utf-8") as fh:
    schema = yaml.safe_load(fh)

required_top = ["schemaVersion", "variableGroups", "variables", "outputGroups", "outputs"]
missing = [key for key in required_top if key not in schema]
if missing:
    raise SystemExit(f"missing schema keys: {missing}")

variables = schema["variables"]
for name in ["region", "compartment_ocid", "subnet_ocid"]:
    item = variables.get(name)
    if not item or item.get("required") is not True:
        raise SystemExit(f"{name} must be present and required")

outputs = schema["outputs"]
for name in ["nfs_mount_sources", "mount_targets", "resource_manager_summary"]:
    if name not in outputs:
        raise SystemExit(f"missing output declaration: {name}")

print("PASS: schema.yaml parses and declares required variables/outputs")
PY

  (
    cd "$package_dir"
    terraform init -input=false
    terraform validate
  )

  echo "PASS: IT-1"
}

test_IT2_orm_stack_upload_succeeds() {
  echo "=== IT-2: ORM stack upload succeeds ==="

  local root_dir workdir zip_path region compartment_ocid subnet_ocid variables_json stack_json stack_id
  root_dir="$(_root_dir)"
  workdir="$(_generated_dir orm_package_upload)"
  _copy_package_tree "$workdir"
  zip_path="$(_create_package_zip "$workdir")"
  region="$(_foundation_value '.inputs.oci_region')"
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  variables_json="${workdir}/variables.json"

  jq -n \
    --arg region "$region" \
    --arg compartment_ocid "$compartment_ocid" \
    --arg subnet_ocid "$subnet_ocid" \
    '{region: $region, compartment_ocid: $compartment_ocid, subnet_ocid: $subnet_ocid}' >"$variables_json"

  stack_json="${workdir}/stack_create.json"
  oci resource-manager stack create \
    --compartment-id "$compartment_ocid" \
    --display-name "fss-sprint13-orm-upload" \
    --description "Sprint 13 ORM package upload validation" \
    --config-source "$zip_path" \
    --variables "file://${variables_json}" \
    --wait-for-state ACTIVE \
    --wait-for-state FAILED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 15 >"$stack_json"

  stack_id="$(jq -r '.data.id // empty' "$stack_json")"
  if [[ -z "$stack_id" || "$stack_id" == "null" ]]; then
    echo "FAIL: stack create response did not include stack OCID" >&2
    return 1
  fi

  echo "$stack_id" >"${workdir}/stack_ocid.txt"
  _delete_stack "$stack_id"

  echo "PASS: IT-2 (stack_id=${stack_id})"
}

test_IT3_orm_apply_destroy_outputs_visible() {
  echo "=== IT-3: ORM apply/destroy outputs visible ==="

  local workdir zip_path region compartment_ocid subnet_ocid variables_json stack_json stack_id
  local apply_json apply_job_id state_json destroy_json destroy_job_id ec=0

  workdir="$(_generated_dir orm_package_apply)"
  _copy_package_tree "$workdir"
  zip_path="$(_create_package_zip "$workdir")"
  region="$(_foundation_value '.inputs.oci_region')"
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  variables_json="${workdir}/variables.json"
  stack_json="${workdir}/stack_create.json"

  jq -n \
    --arg region "$region" \
    --arg compartment_ocid "$compartment_ocid" \
    --arg subnet_ocid "$subnet_ocid" \
    '{region: $region, compartment_ocid: $compartment_ocid, subnet_ocid: $subnet_ocid}' >"$variables_json"

  oci resource-manager stack create \
    --compartment-id "$compartment_ocid" \
    --display-name "fss-sprint13-orm-apply" \
    --description "Sprint 13 ORM package apply validation" \
    --config-source "$zip_path" \
    --variables "file://${variables_json}" \
    --wait-for-state ACTIVE \
    --wait-for-state FAILED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 15 >"$stack_json"

  stack_id="$(jq -r '.data.id // empty' "$stack_json")"
  echo "$stack_id" >"${workdir}/stack_ocid.txt"

  apply_json="${workdir}/apply_job.json"
  destroy_json="${workdir}/destroy_job.json"
  state_json="${workdir}/apply_tf_state.json"

  (
    oci resource-manager job create-apply-job \
      --stack-id "$stack_id" \
      --display-name "fss-sprint13-orm-apply" \
      --execution-plan-strategy AUTO_APPROVED >"$apply_json"

    apply_job_id="$(jq -r '.data.id // empty' "$apply_json")"
    echo "$apply_job_id" >"${workdir}/apply_job_ocid.txt"
    if ! _wait_job_terminal "$apply_job_id" 1800; then
      oci resource-manager job get --job-id "$apply_job_id" >"${workdir}/apply_job_final_failure.json" || true
      oci resource-manager job get-job-logs-content --job-id "$apply_job_id" >"${workdir}/apply_job_failure.log" || true
      echo "FAIL: Resource Manager apply job failed; see ${workdir}/apply_job_failure.log" >&2
      exit 1
    fi

    oci resource-manager job get-job-logs-content --job-id "$apply_job_id" >"${workdir}/apply_job.log" || true
    oci resource-manager job get-job-tf-state \
      --job-id "$apply_job_id" \
      --file "$state_json"

    local nfs_mount_source
    nfs_mount_source="$(jq -r '.outputs.nfs_mount_sources.value.data__primary // empty' "$state_json")"
    if [[ -z "$nfs_mount_source" || "$nfs_mount_source" == "null" ]]; then
      echo "FAIL: nfs_mount_sources.data__primary missing from Resource Manager Terraform state outputs" >&2
      exit 1
    fi
    if ! grep -qE '.+:.+' <<<"$nfs_mount_source"; then
      echo "FAIL: nfs_mount_source '${nfs_mount_source}' does not match <addr>:<path>" >&2
      exit 1
    fi

    oci resource-manager job create-destroy-job \
      --stack-id "$stack_id" \
      --display-name "fss-sprint13-orm-destroy" \
      --execution-plan-strategy AUTO_APPROVED >"$destroy_json"

    destroy_job_id="$(jq -r '.data.id // empty' "$destroy_json")"
    echo "$destroy_job_id" >"${workdir}/destroy_job_ocid.txt"
    if ! _wait_job_terminal "$destroy_job_id" 1800; then
      oci resource-manager job get --job-id "$destroy_job_id" >"${workdir}/destroy_job_final_failure.json" || true
      oci resource-manager job get-job-logs-content --job-id "$destroy_job_id" >"${workdir}/destroy_job_failure.log" || true
      echo "FAIL: Resource Manager destroy job failed; see ${workdir}/destroy_job_failure.log" >&2
      exit 1
    fi

    echo "PASS: IT-3 (nfs_mount_source=${nfs_mount_source})"
  ) || ec=$?

  if [[ "$ec" -ne 0 ]]; then
    if [[ -n "${apply_job_id:-}" ]]; then
      oci resource-manager job get --job-id "$apply_job_id" >"${workdir}/apply_job_final_failure.json" || true
      oci resource-manager job get-job-logs-content --job-id "$apply_job_id" >"${workdir}/apply_job_failure.log" || true
    fi
    if [[ -n "${stack_id:-}" && "${SKIP_TEARDOWN:-false}" != "true" ]]; then
      local cleanup_destroy_json cleanup_destroy_job_id
      cleanup_destroy_json="${workdir}/destroy_after_failure_job.json"
      oci resource-manager job create-destroy-job \
        --stack-id "$stack_id" \
        --display-name "fss-sprint13-orm-destroy-after-failure" \
        --execution-plan-strategy AUTO_APPROVED >"$cleanup_destroy_json" || true
      cleanup_destroy_job_id="$(jq -r '.data.id // empty' "$cleanup_destroy_json" 2>/dev/null || true)"
      if [[ -n "$cleanup_destroy_job_id" && "$cleanup_destroy_job_id" != "null" ]]; then
        _wait_job_terminal "$cleanup_destroy_job_id" 1800 || true
        oci resource-manager job get-job-logs-content --job-id "$cleanup_destroy_job_id" >"${workdir}/destroy_after_failure_job.log" || true
      fi
    fi
  fi

  if [[ "${SKIP_TEARDOWN:-false}" != "true" ]]; then
    _delete_stack "$stack_id"
  fi

  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_orm_package_validates_locally
  test_IT2_orm_stack_upload_succeeds
  test_IT3_orm_apply_destroy_outputs_visible
fi
