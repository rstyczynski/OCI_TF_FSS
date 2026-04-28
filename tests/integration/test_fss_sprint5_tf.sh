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
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_5/generated_tf}"
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
  default_generated_root="${root_dir}/progress/sprint_5/generated_tf"
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

  if [[ ! -d "$scaffold_dir" ]]; then
    echo "FAIL: missing oci_scaffold submodule at ${scaffold_dir}" >&2
    return 1
  fi
  if [[ ! -f "$foundation_state" ]]; then
    echo "FAIL: missing Sprint 1 foundation state: ${foundation_state}" >&2
    return 1
  fi

  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  vault_mgmt_endpoint="$(_foundation_value '.vault.mgmt_endpoint')"

  mkdir -p "$mek_dir"
  jq -n \
    --arg compartment_ocid "$compartment_ocid" \
    --arg name_prefix "$mek_prefix" \
    --arg vault_mgmt_endpoint "$vault_mgmt_endpoint" \
    '{
      inputs: {
        oci_compartment: $compartment_ocid,
        name_prefix: $name_prefix,
        key_algorithm: "AES",
        key_length: 32,
        key_protection_mode: "SOFTWARE"
      },
      vault: {
        mgmt_endpoint: $vault_mgmt_endpoint
      }
    }' >"$mek_state"

  (cd "$mek_dir" && NAME_PREFIX="$mek_prefix" "${scaffold_dir}/resource/ensure-key.sh" >&2)
  key_ocid="$(jq -r '.key.ocid // empty' "$mek_state")"
  if [[ -z "$key_ocid" || "$key_ocid" == "null" ]]; then
    echo "FAIL: Sprint 5 MEK state missing .key.ocid: ${mek_state}" >&2
    return 1
  fi
  echo "$key_ocid"
}

_write_missing_kms_tf() {
  local workdir="$1"
  local module_source

  module_source="$(_module_source "$workdir" fss_sprint5_filesystem)"
  cat >"${workdir}/main.tf" <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fs" {
  source              = "${module_source}"
  compartment_ocid    = "ocid1.compartment.oc1..example"
  availability_domain = "example:AD-1"
  display_name        = "fss-sprint5-missing-kms"
}
EOF
}

_write_filesystem_tf() {
  local workdir="$1"
  local compartment_ocid="$2"
  local kms_key_id="$3"
  local module_source

  module_source="$(_module_source "$workdir" fss_sprint5_filesystem)"
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
  source              = "${module_source}"
  compartment_ocid    = "${compartment_ocid}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "fss-sprint5-it2"
  kms_key_id          = "${kms_key_id}"

  freeform_tags = {
    sprint          = "5"
    optional_check  = "freeform_tags"
  }
}

output "filesystem_ocid" {
  value = module.fs.filesystem_ocid
}

output "kms_key_id" {
  value = module.fs.kms_key_id
}

output "freeform_tags" {
  value = module.fs.freeform_tags
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

  module_source="$(_module_source "$workdir" fss_sprint5_stack)"
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

  filesystems = {
    alpha = {
      filesystem_display_name = "fss-sprint5-alpha"
      export_path             = "/sprint5-alpha"
      freeform_tags = {
        stack = "alpha"
      }
    }
    beta = {
      filesystem_display_name   = "fss-sprint5-beta"
      mount_target_display_name = "fss-sprint5-mt-beta"
      export_path               = "/sprint5-beta"
      source_cidr               = "${subnet_cidr}"
      freeform_tags = {
        stack = "beta"
      }
    }
  }
}

output "filesystem_ocids" {
  value = module.stack.filesystem_ocids
}

output "mount_target_ocids" {
  value = module.stack.mount_target_ocids
}

output "export_ocids" {
  value = module.stack.export_ocids
}

output "export_paths" {
  value = module.stack.export_paths
}

output "effective_source_cidrs" {
  value = module.stack.effective_source_cidrs
}
EOF
}

test_IT1_missing_kms_key_fails() {
  echo "=== IT-1: Missing mandatory KMS key fails ==="

  local workdir artifacts_dir rc=0 ec=0
  workdir="$(_tf_workdir it1_missing_kms_key)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_missing_kms_tf "$workdir"

  (
    cd "$workdir"
    terraform init -input=false
    set +e
    terraform validate 2>&1 | tee "${artifacts_dir}/validate.stdout.log"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 ]]; then
      echo "FAIL: terraform validate unexpectedly succeeded without kms_key_id" >&2
      exit 1
    fi
    if ! grep -q 'kms_key_id' "${artifacts_dir}/validate.stdout.log"; then
      echo "FAIL: validation failed, but output did not mention kms_key_id" >&2
      exit 1
    fi
    echo "PASS: IT-1"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

test_IT2_filesystem_with_kms_and_optional_argument() {
  echo "=== IT-2: Filesystem applies with Sprint 5 MEK and optional argument ==="

  local compartment_ocid kms_key_id workdir artifacts_dir ec=0
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  kms_key_id="$(_ensure_sprint5_mek)"
  workdir="$(_tf_workdir it2_filesystem_kms_optional)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_filesystem_tf "$workdir" "$compartment_ocid" "$kms_key_id"

  (
    cd "$workdir"
    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    local fs_ocid output_kms optional_tag
    fs_ocid="$(terraform output -raw filesystem_ocid)"
    output_kms="$(terraform output -raw kms_key_id)"
    optional_tag="$(jq -r '.freeform_tags.value.optional_check // empty' "${artifacts_dir}/outputs.json")"
    if [[ -z "$fs_ocid" || "$fs_ocid" == "null" ]]; then
      echo "FAIL: filesystem_ocid output is empty" >&2
      exit 1
    fi
    if [[ "$output_kms" != "$kms_key_id" ]]; then
      echo "FAIL: kms_key_id output mismatch" >&2
      exit 1
    fi
    if [[ "$optional_tag" != "freeform_tags" ]]; then
      echo "FAIL: optional freeform_tags evidence missing" >&2
      exit 1
    fi
    echo "PASS: IT-2 (filesystem_ocid=${fs_ocid})"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

test_IT3_stack_creates_multiple_entries() {
  echo "=== IT-3: Stack module creates multiple FSS entries from map input ==="

  local compartment_ocid subnet_ocid subnet_cidr kms_key_id workdir artifacts_dir ec=0
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  subnet_cidr="$(_foundation_value '.subnet.cidr')"
  kms_key_id="$(_ensure_sprint5_mek)"
  workdir="$(_tf_workdir it3_stack_multi_entry)"
  artifacts_dir="$(_tf_artifacts_dir "$workdir")"
  _write_stack_tf "$workdir" "$compartment_ocid" "$subnet_ocid" "$subnet_cidr" "$kms_key_id"

  (
    cd "$workdir"
    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    for output_name in filesystem_ocids mount_target_ocids export_ocids export_paths effective_source_cidrs; do
      if ! jq -e --arg name "$output_name" '.[$name].value | keys == ["alpha", "beta"]' "${artifacts_dir}/outputs.json" >/dev/null; then
        echo "FAIL: ${output_name} output does not contain expected alpha/beta keys" >&2
        exit 1
      fi
    done
    if ! jq -e '.filesystem_ocids.value.alpha | length > 0' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: alpha filesystem OCID is empty" >&2
      exit 1
    fi
    if ! jq -e '.export_paths.value.beta == "/sprint5-beta"' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: beta export path mismatch" >&2
      exit 1
    fi
    if ! jq -e --arg subnet_cidr "$subnet_cidr" '.effective_source_cidrs.value.alpha == $subnet_cidr' "${artifacts_dir}/outputs.json" >/dev/null; then
      echo "FAIL: alpha did not inherit default_source_cidr" >&2
      exit 1
    fi
    echo "PASS: IT-3"
  ) || ec=$?

  _tf_teardown_workdir "$workdir"
  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT1_missing_kms_key_fails
  test_IT2_filesystem_with_kms_and_optional_argument
  test_IT3_stack_creates_multiple_entries
fi
