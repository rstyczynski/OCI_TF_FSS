#!/usr/bin/env bash
set -euo pipefail

# Sprint 8 integration test: optional OCI Logging for FSS mount targets.
# PBI-016: Add logging to mount targets.

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
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_8/generated_tf}"
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
  default_generated_root="${root_dir}/progress/sprint_8/generated_tf"
  if [[ "$workdir" == "${default_generated_root}/"* ]]; then
    echo "../../../../terraform/modules/${module_name}"
  else
    echo "${root_dir}/terraform/modules/${module_name}"
  fi
}

_ensure_sprint5_mek() {
  local root_dir mek_prefix mek_dir mek_state key_ocid

  root_dir="$(_root_dir)"
  mek_prefix="${SPRINT5_MEK_NAME_PREFIX:-sprint5-fss-mek}"
  mek_dir="${root_dir}/progress/sprint_5/scaffold/fss-mek"
  mek_state="${mek_dir}/state-${mek_prefix}.json"

  if [[ ! -f "$mek_state" ]]; then
    echo "FAIL: Sprint 5 MEK state not found at ${mek_state}" >&2
    return 1
  fi

  key_ocid="$(jq -r '.key.ocid // empty' "$mek_state")"
  if [[ -z "$key_ocid" || "$key_ocid" == "null" ]]; then
    echo "FAIL: Sprint 5 MEK state missing .key.ocid: ${mek_state}" >&2
    return 1
  fi
  echo "$key_ocid"
}

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

_utc_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

_utc_minutes_ago() {
  local minutes="$1"

  if date -u -v-"${minutes}"M '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1; then
    date -u -v-"${minutes}"M '+%Y-%m-%dT%H:%M:%SZ'
  else
    date -u -d "${minutes} minutes ago" '+%Y-%m-%dT%H:%M:%SZ'
  fi
}

_write_logging_stack_tf() {
  local workdir="$1"
  local compartment_ocid="$2"
  local subnet_ocid="$3"
  local subnet_cidr="$4"
  local kms_key_id="$5"
  local module_source

  module_source="$(_module_source "$workdir" fss_sprint8_stack)"
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

  mount_targets = {
    mt_logged = {
      display_name = "fss-sprint8-mt-logged"
      logging = {
        enabled            = true
        log_group_name     = "fss-sprint8-mt-logs"
        log_display_name   = "fss-sprint8-mt-nfs"
        retention_duration = 30
        freeform_tags = {
          sprint = "8"
          test   = "logging"
        }
      }
    }
  }

  filesystems = {
    fs_logged = {
      display_name = "fss-sprint8-logged"
      freeform_tags = {
        sprint = "8"
        test   = "logging"
      }
      exports = {
        export_logged = {
          mount_target_key = "mt_logged"
          path             = "/sprint8-logging"
          identity_squash  = "NONE"
        }
      }
    }
  }
}

output "mount_targets" {
  value = module.stack.mount_targets
}

output "mount_target_ocids" {
  value = module.stack.mount_target_ocids
}

output "mount_target_log_group_ocids" {
  value = module.stack.mount_target_log_group_ocids
}

output "mount_target_log_ocids" {
  value = module.stack.mount_target_log_ocids
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}
EOF
}

test_IT1_logging_enabled_mount_target() {
  echo "=== IT-1: Logging-enabled mount target is discoverable ==="

  local root_dir compartment_ocid subnet_ocid subnet_cidr kms_key_id compute_public_ip
  local workdir artifacts_dir ssh_key ec=0

  root_dir="$(_root_dir)"
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  subnet_cidr="$(_foundation_value '.subnet.cidr')"
  compute_public_ip="$(_foundation_value '.compute.public_ip')"
  kms_key_id="$(_ensure_sprint5_mek)"

  workdir="$(_tf_workdir it1_logging_enabled)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_logging_stack_tf "$workdir" "$compartment_ocid" "$subnet_ocid" "$subnet_cidr" "$kms_key_id"

  ssh_key="$(mktemp)"
  _materialize_ssh_key "$root_dir" "$ssh_key"

  _it1_cleanup() {
    rm -f "$ssh_key"
    _tf_teardown_workdir "$workdir"
  }

  (
    set -euo pipefail
    cd "$workdir"

    terraform init -input=false
    terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    local log_group_ocid log_ocid log_resource_ocid mt_ocid nfs_mount_source
    log_group_ocid="$(jq -r '.mount_target_log_group_ocids.value.mt_logged // empty' "${artifacts_dir}/outputs.json")"
    log_ocid="$(jq -r '.mount_target_log_ocids.value.mt_logged // empty' "${artifacts_dir}/outputs.json")"
    log_resource_ocid="$(jq -r '.mount_targets.value.mt_logged.logging.resource // empty' "${artifacts_dir}/outputs.json")"
    mt_ocid="$(jq -r '.mount_target_ocids.value.mt_logged // empty' "${artifacts_dir}/outputs.json")"
    nfs_mount_source="$(jq -r '.nfs_mount_sources.value.fs_logged__export_logged // empty' "${artifacts_dir}/outputs.json")"

    if [[ -z "$log_group_ocid" || -z "$log_ocid" ]]; then
      echo "FAIL: logging outputs do not include log group and log OCIDs" >&2
      exit 1
    fi
    if [[ "$log_resource_ocid" != "$mt_ocid" ]]; then
      echo "FAIL: log resource OCID ${log_resource_ocid} does not match mount target OCID ${mt_ocid}" >&2
      exit 1
    fi
    if ! jq -e '.mount_targets.value.mt_logged.logging.service == "filestorage" and .mount_targets.value.mt_logged.logging.category == "nfslogs"' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: mount_targets logging does not identify filestorage/nfslogs" >&2
      exit 1
    fi
    if ! jq -e '.mount_targets.value.mt_logged.logging.log_ocid == .mount_target_log_ocids.value.mt_logged' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: mount_targets composite output does not include matching log OCID" >&2
      exit 1
    fi
    if [[ -z "$nfs_mount_source" ]]; then
      echo "FAIL: missing fs_logged__export_logged NFS mount source" >&2
      exit 1
    fi

    oci logging log get \
      --log-group-id "$log_group_ocid" \
      --log-id "$log_ocid" \
      >"${artifacts_dir}/oci_logging_log_get.json"

    if ! jq -e --arg id "$log_ocid" '.data.id == $id and .data."is-enabled" == true' "${artifacts_dir}/oci_logging_log_get.json" >/dev/null; then
      echo "FAIL: OCI Logging CLI did not return the expected enabled log" >&2
      exit 1
    fi

    local mount_point="/mnt/fss/sprint8logging"
    local test_file="${mount_point}/logging_test_$$.txt"

    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo yum install -y nfs-utils 2>/dev/null || true" \
      2>&1 | tee "${artifacts_dir}/nfs_install.log"

    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo mkdir -p ${mount_point} && sudo mount -t nfs -o vers=3,noacl ${nfs_mount_source} ${mount_point}" \
      2>&1 | tee "${artifacts_dir}/mount.log"

    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "echo 'Sprint 8 logging proof' | sudo tee ${test_file} && sudo cat ${test_file}" \
      2>&1 | tee "${artifacts_dir}/nfs_operation.log"

    ssh -i "$ssh_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes \
      "opc@${compute_public_ip}" \
      "sudo rm -f ${test_file} && sudo umount ${mount_point} && sudo rmdir ${mount_point}" \
      2>&1 | tee "${artifacts_dir}/nfs_cleanup.log"

    local time_start time_end search_query
    time_start="$(_utc_minutes_ago 15)"
    time_end="$(_utc_now)"
    search_query="search \"${compartment_ocid}/${log_group_ocid}/${log_ocid}\" | sort by datetime desc"

    oci logging-search search-logs \
      --time-start "$time_start" \
      --time-end "$time_end" \
      --search-query "$search_query" \
      --limit 10 \
      >"${artifacts_dir}/oci_logging_search.json"

    if ! jq -e '.data.results // []' "${artifacts_dir}/oci_logging_search.json" >/dev/null; then
      echo "FAIL: OCI Logging Search output is not in the expected JSON shape" >&2
      exit 1
    fi

    local search_count
    search_count="$(jq '.data.results | length' "${artifacts_dir}/oci_logging_search.json")"
    echo "INFO: OCI logging search returned ${search_count} result(s); ingestion can lag after fresh service-log creation."
    echo "PASS: IT-1 (log_ocid=${log_ocid}, log_group_ocid=${log_group_ocid})"
  ) || ec=$?

  _it1_cleanup
  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_logging_enabled_mount_target
fi
