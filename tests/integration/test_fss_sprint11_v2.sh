#!/usr/bin/env bash
set -euo pipefail

# Sprint 11 integration tests: v2 stack optimized mandatory parameters.
# PBI-021: Create v2 stack with optimized mandatory parameters.
# PBI-022: Complete v2 stack package and README.

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
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_11/generated_tf}"
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

_seed_plugin_cache() {
  local root_dir cache_dir

  root_dir="$(_root_dir)"
  cache_dir="${TF_PLUGIN_CACHE_DIR:-${HOME}/.terraform.d/plugin-cache}"
  mkdir -p "$cache_dir"
  export TF_PLUGIN_CACHE_DIR="$cache_dir"

  mkdir -p "${cache_dir}/registry.terraform.io/oracle/oci"
  while IFS= read -r cached_oci; do
    cp -R "${cached_oci}/"* "${cache_dir}/registry.terraform.io/oracle/oci/" 2>/dev/null || true
  done < <(find "$root_dir" -path '*/.terraform/providers/registry.terraform.io/oracle/oci' -type d)

  mkdir -p "${cache_dir}/registry.terraform.io/hashicorp/random"
  while IFS= read -r cached_random; do
    cp -R "${cached_random}/"* "${cache_dir}/registry.terraform.io/hashicorp/random/" 2>/dev/null || true
  done < <(find "$root_dir" -path '*/.terraform/providers/registry.terraform.io/hashicorp/random' -type d)
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
  local root_dir default_generated_root

  root_dir="$(_root_dir)"
  default_generated_root="${root_dir}/progress/sprint_11/generated_tf"
  if [[ "$workdir" == "${default_generated_root}/"* ]]; then
    echo "../../../../terraform/modules/fss_v2_stack"
  else
    echo "${root_dir}/terraform/modules/fss_v2_stack"
  fi
}

_write_minimal_v2_tf() {
  local workdir="$1"
  local module_source

  module_source="$(_module_source "$workdir")"
  cat >"${workdir}/main.tf" <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fss" {
  source           = "${module_source}"
  compartment_ocid = "ocid1.compartment.oc1..example"
  subnet_ocid      = "ocid1.subnet.oc1..example"

  mount_targets = {
    primary = {}
  }

  filesystems = {
    data = {
      display_name = "fss-v2-data"
      exports = {
        primary = {
          mount_target_key = "primary"
          path             = "/data"
        }
      }
    }
  }
}

output "availability_domain_source" {
  value = module.fss.availability_domain_source
}

output "kms_key_mode" {
  value = module.fss.kms_key_mode
}

output "default_source_cidr" {
  value = module.fss.default_source_cidr
}
EOF
}

_write_full_v2_tf() {
  local workdir="$1"
  local compartment_ocid="$2"
  local subnet_ocid="$3"
  local module_source

  module_source="$(_module_source "$workdir")"
  cat >"${workdir}/main.tf" <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "stack" {
  source           = "${module_source}"
  compartment_ocid = "${compartment_ocid}"
  subnet_ocid      = "${subnet_ocid}"

  mount_targets = {
    mt_primary = {
      display_name = "fss-v2-mt-primary"
      logging = {
        enabled            = true
        log_group_name     = "fss-v2-primary-logs"
        log_display_name   = "fss-v2-primary-nfs"
        retention_duration = 30
        freeform_tags = {
          release = "v2"
          entry   = "mt_primary"
        }
      }
    }
    mt_secondary = {
      display_name = "fss-v2-mt-secondary"
    }
  }

  filesystems = {
    fs_data = {
      display_name = "fss-v2-data"
      freeform_tags = {
        release = "v2"
        entry   = "fs_data"
      }
      exports = {
        to_primary = {
          mount_target_key = "mt_primary"
          path             = "/v2-data-primary"
          identity_squash  = "NONE"
        }
        to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/v2-data-secondary"
        }
      }
    }
    fs_backup = {
      display_name = "fss-v2-backup"
      freeform_tags = {
        release = "v2"
        entry   = "fs_backup"
      }
      exports = {
        to_primary = {
          mount_target_key = "mt_primary"
          path             = "/v2-backup"
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

output "effective_availability_domain" {
  value = module.stack.effective_availability_domain
}

output "availability_domain_source" {
  value = module.stack.availability_domain_source
}

output "effective_kms_key_id" {
  value = module.stack.effective_kms_key_id
}

output "kms_key_mode" {
  value = module.stack.kms_key_mode
}

output "default_source_cidr" {
  value = module.stack.default_source_cidr
}
EOF
}

test_IT1_minimal_v2_example_validates() {
  echo "=== IT-1: minimal v2 example validates ==="

  local workdir artifacts_dir ec=0

  workdir="$(_tf_workdir it1_minimal_validate)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_minimal_v2_tf "$workdir"

  (
    cd "$workdir"
    _seed_plugin_cache
    terraform init -input=false
    terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
    if ! grep -q "The configuration is valid" "${artifacts_dir}/validate.stdout.log"; then
      echo "FAIL: validate output does not confirm minimal v2 example success" >&2
      exit 1
    fi
    if grep -Eq '^[[:space:]]+(availability_domain|kms_key_id|default_source_cidr)[[:space:]]*=' main.tf; then
      echo "FAIL: minimal v2 example should not set AD, KMS, or default CIDR inputs" >&2
      exit 1
    fi
    echo "PASS: IT-1"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

test_IT2_full_v2_stack_applies() {
  echo "=== IT-2: full v2 stack applies with optimized defaults ==="

  local compartment_ocid subnet_ocid workdir artifacts_dir ec=0

  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  workdir="$(_tf_workdir it2_full_apply)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_full_v2_tf "$workdir" "$compartment_ocid" "$subnet_ocid"

  (
    cd "$workdir"
    _seed_plugin_cache
    terraform init -input=false
    terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    if ! jq -e '.kms_key_mode.value == "ORACLE_MANAGED" and .effective_kms_key_id.value == null' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: v2 should use Oracle-managed encryption when kms_key_id is omitted" >&2
      exit 1
    fi
    if ! jq -e '.default_source_cidr.value == "0.0.0.0/0"' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: v2 default source CIDR should be 0.0.0.0/0" >&2
      exit 1
    fi
    if ! jq -e '.availability_domain_source.value == "subnet" or .availability_domain_source.value == "random"' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: v2 AD source should be subnet or random when AD input is omitted" >&2
      exit 1
    fi
    if ! jq -e '.effective_availability_domain.value | length > 0' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: v2 effective AD output is empty" >&2
      exit 1
    fi
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
    if ! jq -e '.filesystems.value.fs_data.exports.to_primary.source_cidr == "0.0.0.0/0"' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: fs_data/to_primary did not inherit v2 default source CIDR" >&2
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
    echo "PASS: IT-2"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_minimal_v2_example_validates
  test_IT2_full_v2_stack_applies
fi
