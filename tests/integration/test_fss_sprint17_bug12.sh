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
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_17/generated_tf}"
  dir="${base}/${test_id}"

  if [[ "${TF_RESET_TF_STATE:-true}" == "true" ]]; then
    rm -rf "$dir"
  fi
  mkdir -p "${dir}/tf_test_artifacts"
  echo "$dir"
}

_first_availability_domain() {
  local compartment_ocid="$1"
  oci iam availability-domain list \
    --compartment-id "$compartment_ocid" \
    --query 'data[0].name' \
    --raw-output
}

_wait_for_log_group_id() {
  local compartment_ocid="$1"
  local display_name="$2"
  local attempts=30
  local id=""

  while ((attempts > 0)); do
    id="$(oci logging log-group list \
      --compartment-id "$compartment_ocid" \
      --display-name "$display_name" \
      | jq -r '.data[0].id // empty')"
    if [[ -n "$id" && "$id" != "null" ]]; then
      echo "$id"
      return 0
    fi
    attempts=$((attempts - 1))
    sleep 5
  done

  echo "FAIL: timed out waiting for log group '${display_name}'" >&2
  return 1
}

test_IT_bug12_existing_log_group_name_is_reused() {
  echo "=== IT-BUG-12: existing log group display name is reused ==="

  local root_dir compartment_ocid subnet_ocid availability_domain workdir artifacts_dir
  local suffix log_group_name log_display_name precreated_log_group_id ec=0

  root_dir="$(_root_dir)"
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  availability_domain="$(_first_availability_domain "$compartment_ocid")"
  workdir="$(_tf_workdir bug12_logging_reuse)"
  artifacts_dir="${workdir}/tf_test_artifacts"
  suffix="$(date -u '+%Y%m%d%H%M%S')"
  log_group_name="fss-bug12-existing-${suffix}"
  log_display_name="fss-bug12-nfs-${suffix}"

  oci logging log-group create \
    --compartment-id "$compartment_ocid" \
    --display-name "$log_group_name" \
    --description "BUG-12 precreated log group for reuse test" \
    --wait-for-state SUCCEEDED \
    --max-wait-seconds 900 \
    --wait-interval-seconds 10 \
    >"${artifacts_dir}/precreate_log_group.json"

  precreated_log_group_id="$(_wait_for_log_group_id "$compartment_ocid" "$log_group_name")"
  echo "$precreated_log_group_id" >"${artifacts_dir}/precreated_log_group_ocid.txt"

  cat >"${workdir}/main.tf" <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "stack" {
  source = "${root_dir}/terraform/modules/fss_stack_sprint17"

  compartment_ocid    = "${compartment_ocid}"
  subnet_ocid         = "${subnet_ocid}"
  availability_domain = "${availability_domain}"

  mount_targets = {
    primary = {
      display_name = "fss-bug12-mt-${suffix}"
      logging = {
        enabled            = true
        log_group_name     = "${log_group_name}"
        log_display_name   = "${log_display_name}"
        retention_duration = 30
      }
    }
  }

  filesystems = {}
}

output "mount_targets" {
  value = module.stack.mount_targets
}

output "mount_target_log_group_ocids" {
  value = module.stack.mount_target_log_group_ocids
}

output "mount_target_log_ocids" {
  value = module.stack.mount_target_log_ocids
}
EOF

  (
    set -euo pipefail
    cd "$workdir"
    terraform init -input=false
    terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    terraform show -no-color "${artifacts_dir}/deploy.tfplan" >"${artifacts_dir}/deploy.tfplan.txt"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    local resolved_log_group_id log_ocid log_resource mt_ocid
    resolved_log_group_id="$(jq -r '.mount_target_log_group_ocids.value.primary // empty' "${artifacts_dir}/outputs.json")"
    log_ocid="$(jq -r '.mount_target_log_ocids.value.primary // empty' "${artifacts_dir}/outputs.json")"
    log_resource="$(jq -r '.mount_targets.value.primary.logging.resource // empty' "${artifacts_dir}/outputs.json")"
    mt_ocid="$(jq -r '.mount_targets.value.primary.ocid // empty' "${artifacts_dir}/outputs.json")"

    if [[ "$resolved_log_group_id" != "$precreated_log_group_id" ]]; then
      echo "FAIL: expected reused log group ${precreated_log_group_id}, got ${resolved_log_group_id}" >&2
      exit 1
    fi
    if [[ -z "$log_ocid" || "$log_ocid" == "null" ]]; then
      echo "FAIL: missing service log OCID" >&2
      exit 1
    fi
    if [[ "$log_resource" != "$mt_ocid" ]]; then
      echo "FAIL: service log resource ${log_resource} does not match mount target ${mt_ocid}" >&2
      exit 1
    fi
    if ! jq -e '.mount_targets.value.primary.logging.service == "filestorage" and .mount_targets.value.primary.logging.category == "nfslogs"' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: logging output does not describe File Storage NFS logs" >&2
      exit 1
    fi
  ) || ec=$?

  if [[ "${SKIP_TEARDOWN:-false}" != "true" ]]; then
    if [[ -f "${workdir}/terraform.tfstate" ]]; then
      (cd "$workdir" && terraform destroy -auto-approve -input=false 2>&1 | tee "${artifacts_dir}/destroy.stdout.log") || true
    fi
    oci logging log-group delete \
      --log-group-id "$precreated_log_group_id" \
      --force \
      --wait-for-state SUCCEEDED \
      --max-wait-seconds 900 \
      --wait-interval-seconds 10 \
      >"${artifacts_dir}/delete_precreated_log_group.json" || true
  fi

  if [[ "$ec" -eq 0 ]]; then
    echo "PASS: IT-BUG-12 (reused_log_group=${precreated_log_group_id})"
  fi
  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT_bug12_existing_log_group_name_is_reused
fi
