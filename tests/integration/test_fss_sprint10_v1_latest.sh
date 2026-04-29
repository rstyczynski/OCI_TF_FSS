#!/usr/bin/env bash
set -euo pipefail

# Sprint 10 integration tests: rebase v1 stack on the latest Sprint 8 interface.
# PBI-020: Rebase v1 stack on latest Sprint 8 stack interface.

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
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_10/generated_tf}"
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
  default_generated_root="${root_dir}/progress/sprint_10/generated_tf"
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

_write_v1_latest_stack_tf() {
  local workdir="$1"
  local compartment_ocid="$2"
  local subnet_ocid="$3"
  local subnet_cidr="$4"
  local kms_key_id="$5"
  local module_source

  module_source="$(_module_source "$workdir" fss_v1_stack)"
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
    mt_primary = {
      display_name = "fss-v1-mt-primary"
      logging = {
        enabled            = true
        log_group_name     = "fss-v1-primary-logs"
        log_display_name   = "fss-v1-primary-nfs"
        retention_duration = 30
        freeform_tags = {
          release = "v1"
          entry   = "mt_primary"
        }
      }
    }
    mt_secondary = {
      display_name = "fss-v1-mt-secondary"
    }
  }

  filesystems = {
    fs_data = {
      display_name = "fss-v1-data"
      freeform_tags = {
        release = "v1"
        entry   = "fs_data"
      }
      exports = {
        to_primary = {
          mount_target_key = "mt_primary"
          path             = "/v1-data-primary"
          identity_squash  = "NONE"
        }
        to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/v1-data-secondary"
        }
      }
    }
    fs_backup = {
      display_name = "fss-v1-backup"
      freeform_tags = {
        release = "v1"
        entry   = "fs_backup"
      }
      exports = {
        to_primary = {
          mount_target_key = "mt_primary"
          path             = "/v1-backup"
        }
      }
    }
  }
}

output "filesystems" {
  value = module.stack.filesystems
}

output "filesystem_ocids" {
  value = module.stack.filesystem_ocids
}

output "mount_targets" {
  value = module.stack.mount_targets
}

output "mount_target_ocids" {
  value = module.stack.mount_target_ocids
}

output "export_paths" {
  value = module.stack.export_paths
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}

output "mount_target_log_ocids" {
  value = module.stack.mount_target_log_ocids
}

output "mount_target_log_group_ocids" {
  value = module.stack.mount_target_log_group_ocids
}
EOF
}

_write_latest_documented_example_tf() {
  local workdir="$1"
  local module_source

  module_source="$(_module_source "$workdir" fss_v1_stack)"
  cat >"${workdir}/main.tf" <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fss" {
  source              = "${module_source}"
  compartment_ocid    = "ocid1.compartment.oc1..example"
  availability_domain = "example:AD-1"
  subnet_ocid         = "ocid1.subnet.oc1..example"
  kms_key_id          = "ocid1.key.oc1..example"
  default_source_cidr = "10.0.0.0/24"

  mount_targets = {
    primary = {
      display_name = "fss-primary"
      logging = {
        enabled = true
      }
    }
    secondary = {
      display_name = "fss-secondary"
    }
  }

  filesystems = {
    data = {
      display_name = "fss-data"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/data"
          identity_squash  = "NONE"
        }
        secondary = {
          mount_target_key = "secondary"
          path             = "/data-secondary"
        }
      }
    }
    backup = {
      display_name = "fss-backup"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/backup"
        }
      }
    }
  }
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
}

test_IT1_v1_latest_stack_applies() {
  echo "=== IT-1: v1 stack uses latest Sprint 8 interface ==="

  local compartment_ocid subnet_ocid subnet_cidr kms_key_id workdir artifacts_dir ec=0

  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  subnet_cidr="$(_foundation_value '.subnet.cidr')"
  kms_key_id="$(_ensure_sprint5_mek)"
  workdir="$(_tf_workdir it1_v1_latest_stack_apply)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_v1_latest_stack_tf "$workdir" "$compartment_ocid" "$subnet_ocid" "$subnet_cidr" "$kms_key_id"

  (
    cd "$workdir"
    terraform init -input=false
    terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    for output_name in filesystems filesystem_ocids; do
      if ! jq -e --arg name "$output_name" '.[$name].value | keys == ["fs_backup", "fs_data"]' "${artifacts_dir}/outputs.json" >/dev/null; then
        echo "FAIL: ${output_name} output does not contain expected fs_backup/fs_data keys" >&2
        exit 1
      fi
    done
    for output_name in mount_targets mount_target_ocids; do
      if ! jq -e --arg name "$output_name" '.[$name].value | keys == ["mt_primary", "mt_secondary"]' "${artifacts_dir}/outputs.json" >/dev/null; then
        echo "FAIL: ${output_name} output does not contain expected mt_primary/mt_secondary keys" >&2
        exit 1
      fi
    done
    if ! jq -e '.filesystems.value.fs_data.exports.to_primary.path == "/v1-data-primary"' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: fs_data/to_primary export path mismatch" >&2
      exit 1
    fi
    if ! jq -e '.filesystems.value.fs_data.exports.to_secondary.mount_target_key == "mt_secondary"' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: fs_data/to_secondary does not point to mt_secondary" >&2
      exit 1
    fi
    if ! jq -e '.nfs_mount_sources.value | keys == ["fs_backup__to_primary", "fs_data__to_primary", "fs_data__to_secondary"]' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: nfs_mount_sources keys do not match expected filesystem/export composite keys" >&2
      exit 1
    fi
    if ! jq -e '[.nfs_mount_sources.value[]] | all(. | test(".+:.+"))' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: nfs_mount_sources values are not in <mount-address>:<export-path> form" >&2
      exit 1
    fi
    if ! jq -e '.mount_targets.value.mt_primary.logging.service == "filestorage" and .mount_targets.value.mt_primary.logging.category == "nfslogs"' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: mt_primary logging details missing from mount_targets output" >&2
      exit 1
    fi
    if ! jq -e '.mount_targets.value.mt_secondary.logging == null' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: mt_secondary logging should be null" >&2
      exit 1
    fi
    if ! jq -e '.mount_target_log_ocids.value.mt_primary | length > 0' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: mt_primary log OCID is empty" >&2
      exit 1
    fi
    echo "PASS: IT-1"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

test_IT2_latest_documented_example_validates() {
  echo "=== IT-2: latest v1 documented example validates ==="

  local workdir artifacts_dir ec=0

  workdir="$(_tf_workdir it2_latest_documented_example_validate)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_latest_documented_example_tf "$workdir"

  (
    cd "$workdir"
    terraform init -input=false
    terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
    if ! grep -q "The configuration is valid" "${artifacts_dir}/validate.stdout.log"; then
      echo "FAIL: validate output does not confirm documented example success" >&2
      exit 1
    fi
    echo "PASS: IT-2"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_v1_latest_stack_applies
  test_IT2_latest_documented_example_validates
fi
