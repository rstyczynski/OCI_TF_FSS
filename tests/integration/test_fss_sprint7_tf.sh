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
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_7/generated_tf}"
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
  default_generated_root="${root_dir}/progress/sprint_7/generated_tf"
  if [[ "$workdir" == "${default_generated_root}/"* ]]; then
    echo "../../../../terraform/modules/${module_name}"
  else
    echo "${root_dir}/terraform/modules/${module_name}"
  fi
}

_ensure_sprint5_mek() {
  local root_dir scaffold_dir foundation_state mek_prefix mek_dir mek_state
  local compartment_ocid vault_mgmt_endpoint key_ocid

  root_dir="$(_root_dir)"
  scaffold_dir="${root_dir}/oci_scaffold"
  foundation_state="$(_foundation_scaffold_state_file "$root_dir")"
  mek_prefix="${SPRINT5_MEK_NAME_PREFIX:-sprint5-fss-mek}"
  mek_dir="${root_dir}/progress/sprint_5/scaffold/fss-mek"
  mek_state="${mek_dir}/state-${mek_prefix}.json"

  if [[ ! -f "$mek_state" ]]; then
    echo "FAIL: Sprint 5 MEK state not found at ${mek_state} — run Sprint 5 IT-2 or IT-3 first to provision the MEK" >&2
    return 1
  fi

  key_ocid="$(jq -r '.key.ocid // empty' "$mek_state")"
  if [[ -z "$key_ocid" || "$key_ocid" == "null" ]]; then
    echo "FAIL: Sprint 5 MEK state missing .key.ocid: ${mek_state}" >&2
    return 1
  fi
  echo "$key_ocid"
}

_write_static_validate_tf() {
  local workdir="$1"
  local module_source

  module_source="$(_module_source "$workdir" fss_sprint7_stack)"
  cat >"${workdir}/main.tf" <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "stack" {
  source              = "${module_source}"
  compartment_ocid    = "ocid1.compartment.oc1..example"
  availability_domain = "example:AD-1"
  subnet_ocid         = "ocid1.subnet.oc1..example"
  kms_key_id          = "ocid1.key.oc1..example"
  default_source_cidr = "10.0.0.0/24"

  mount_targets = {
    mt_primary = {
      display_name = "fss-sprint7-mt-primary"
    }
    mt_secondary = {
      display_name = "fss-sprint7-mt-secondary"
    }
  }

  filesystems = {
    fs_alpha = {
      display_name = "fss-sprint7-alpha"
      exports = {
        export_to_primary = {
          mount_target_key = "mt_primary"
          path             = "/sprint7-alpha-primary"
        }
        export_to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/sprint7-alpha-secondary"
          identity_squash  = "NONE"
        }
      }
    }
    fs_beta = {
      display_name = "fss-sprint7-beta"
      exports = {
        export_to_primary = {
          mount_target_key = "mt_primary"
          path             = "/sprint7-beta-primary"
          identity_squash  = "NONE"
        }
        export_to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/sprint7-beta-secondary"
          identity_squash  = "ROOT"
        }
      }
    }
  }
}
EOF
}

_write_stack_tf() {
  local workdir="$1"
  local compartment_ocid="$2"
  local subnet_ocid="$3"
  local subnet_cidr="$4"
  local kms_key_id="$5"
  local module_source

  module_source="$(_module_source "$workdir" fss_sprint7_stack)"
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
      display_name = "fss-sprint7-mt-primary"
    }
    mt_secondary = {
      display_name = "fss-sprint7-mt-secondary"
    }
  }

  filesystems = {
    fs_alpha = {
      display_name = "fss-sprint7-alpha"
      freeform_tags = {
        sprint = "7"
        test   = "it2"
      }
      exports = {
        export_to_primary = {
          mount_target_key = "mt_primary"
          path             = "/sprint7-alpha-primary"
        }
        export_to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/sprint7-alpha-secondary"
          identity_squash  = "NONE"
        }
      }
    }
    fs_beta = {
      display_name = "fss-sprint7-beta"
      freeform_tags = {
        sprint = "7"
        test   = "it2"
      }
      exports = {
        export_to_primary = {
          mount_target_key = "mt_primary"
          path             = "/sprint7-beta-primary"
          identity_squash  = "NONE"
        }
        export_to_secondary = {
          mount_target_key = "mt_secondary"
          path             = "/sprint7-beta-secondary"
          identity_squash  = "ROOT"
        }
      }
    }
  }
}

output "mount_targets" {
  value = module.stack.mount_targets
}

output "filesystems" {
  value = module.stack.filesystems
}

output "mount_target_ocids" {
  value = module.stack.mount_target_ocids
}

output "filesystem_ocids" {
  value = module.stack.filesystem_ocids
}

output "nfs_mount_sources" {
  value = module.stack.nfs_mount_sources
}

output "export_paths" {
  value = module.stack.export_paths
}
EOF
}

# ---------------------------------------------------------------------------

test_IT1_static_validate_new_variable_structure() {
  echo "=== IT-1: New variable structure passes static validation ==="

  local workdir artifacts_dir ec=0
  workdir="$(_tf_workdir it1_static_validate)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  # TODO: implement — call _write_static_validate_tf and run terraform validate
  _write_static_validate_tf "$workdir"

  (
    cd "$workdir"
    terraform init -input=false
    set +e
    terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
    local rc=$?
    set -e
    if [[ "$rc" -ne 0 ]]; then
      echo "FAIL: terraform validate failed unexpectedly" >&2
      exit 1
    fi
    if ! grep -q "The configuration is valid" "${artifacts_dir}/validate.stdout.log"; then
      echo "FAIL: validate output does not confirm success" >&2
      exit 1
    fi
    echo "PASS: IT-1"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

test_IT2_stack_applies_with_cross_referenced_mount_targets() {
  echo "=== IT-2: Stack applies with cross-referenced mount targets and filesystems ==="

  local compartment_ocid subnet_ocid subnet_cidr kms_key_id workdir artifacts_dir ec=0
  # TODO: implement — retrieve foundation values and run full apply
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  subnet_cidr="$(_foundation_value '.subnet.cidr')"
  kms_key_id="$(_ensure_sprint5_mek)"
  workdir="$(_tf_workdir it2_stack_cross_ref)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_stack_tf "$workdir" "$compartment_ocid" "$subnet_ocid" "$subnet_cidr" "$kms_key_id"

  (
    cd "$workdir"
    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    # Assert mount_target_ocids contains both keys
    for mt_key in mt_primary mt_secondary; do
      if ! jq -e --arg k "$mt_key" '.mount_target_ocids.value[$k] | length > 0' "${artifacts_dir}/outputs.json" >/dev/null; then
        echo "FAIL: mount_target_ocids missing or empty for key ${mt_key}" >&2
        exit 1
      fi
    done

    # Assert filesystem_ocids contains both keys
    for fs_key in fs_alpha fs_beta; do
      if ! jq -e --arg k "$fs_key" '.filesystem_ocids.value[$k] | length > 0' "${artifacts_dir}/outputs.json" >/dev/null; then
        echo "FAIL: filesystem_ocids missing or empty for key ${fs_key}" >&2
        exit 1
      fi
    done

    # Assert 4 nfs_mount_sources entries (2 filesystems × 2 exports each)
    local mount_source_count
    mount_source_count="$(jq '.nfs_mount_sources.value | length' "${artifacts_dir}/outputs.json")"
    if [[ "$mount_source_count" -ne 4 ]]; then
      echo "FAIL: expected 4 nfs_mount_sources entries, got ${mount_source_count}" >&2
      exit 1
    fi

    # Assert both filesystems each have 2 nested exports
    for fs_key in fs_alpha fs_beta; do
      if ! jq -e --arg k "$fs_key" '.filesystems.value[$k].exports | keys | length == 2' "${artifacts_dir}/outputs.json" >/dev/null; then
        echo "FAIL: ${fs_key} should have 2 nested exports" >&2
        exit 1
      fi
    done

    # Assert identity_squash values — NONE on cross-exports, ROOT on same-side exports
    local squash
    squash="$(jq -r '.filesystems.value.fs_alpha.exports.export_to_secondary.identity_squash' "${artifacts_dir}/outputs.json")"
    if [[ "$squash" != "NONE" ]]; then
      echo "FAIL: fs_alpha/export_to_secondary identity_squash expected NONE, got ${squash}" >&2
      exit 1
    fi
    squash="$(jq -r '.filesystems.value.fs_beta.exports.export_to_primary.identity_squash' "${artifacts_dir}/outputs.json")"
    if [[ "$squash" != "NONE" ]]; then
      echo "FAIL: fs_beta/export_to_primary identity_squash expected NONE, got ${squash}" >&2
      exit 1
    fi
    squash="$(jq -r '.filesystems.value.fs_alpha.exports.export_to_primary.identity_squash' "${artifacts_dir}/outputs.json")"
    if [[ "$squash" != "ROOT" ]]; then
      echo "FAIL: fs_alpha/export_to_primary identity_squash expected ROOT, got ${squash}" >&2
      exit 1
    fi
    squash="$(jq -r '.filesystems.value.fs_beta.exports.export_to_secondary.identity_squash' "${artifacts_dir}/outputs.json")"
    if [[ "$squash" != "ROOT" ]]; then
      echo "FAIL: fs_beta/export_to_secondary identity_squash expected ROOT, got ${squash}" >&2
      exit 1
    fi

    # Assert all nfs_mount_source strings match <addr>:<path> pattern
    if ! jq -e '[.nfs_mount_sources.value[]] | all(. | test(".+:.+"))' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: one or more nfs_mount_sources values do not match <addr>:<path> format" >&2
      exit 1
    fi

    echo "PASS: IT-2"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_static_validate_new_variable_structure
  test_IT2_stack_applies_with_cross_referenced_mount_targets
fi
