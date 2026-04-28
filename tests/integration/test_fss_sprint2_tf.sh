#!/usr/bin/env bash
set -euo pipefail

# Aligns with tools/infra_setup.sh + sprint1_foundation_infra_setup: oci_scaffold state under
# progress/sprint_1/scaffold/<NAME_PREFIX>/state-<NAME_PREFIX>.json — compartment at .compartment.ocid .
_foundation_scaffold_prefix() {
  if [[ "${SPRINT1_USE_ENV_NAME_PREFIX:-false}" == "true" ]] && [[ -n "${NAME_PREFIX:-}" ]]; then
    echo "$NAME_PREFIX"
  else
    echo "${SPRINT1_NAME_PREFIX:-infra}"
  fi
}

_foundation_scaffold_state_file() {
  local root_dir="$1"
  local prefix state_path

  if [[ -n "${SPRINT1_FOUNDATION_STATE_FILE:-}" ]]; then
    echo "${SPRINT1_FOUNDATION_STATE_FILE}"
    return 0
  fi

  prefix="$(_foundation_scaffold_prefix)"
  if [[ -n "${WORKDIR:-}" ]]; then
    state_path="${WORKDIR}/state-${prefix}.json"
  else
    state_path="${root_dir}/progress/sprint_1/scaffold/${prefix}/state-${prefix}.json"
  fi
  echo "$state_path"
}

_resolve_compartment_ocid() {
  local compartment_path="${1:-/oci_tf_fss}"
  local root_dir scaffold_dir compartment_ocid state_file

  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  compartment_ocid="${COMPARTMENT_OCID:-}"

  if [[ -n "$compartment_ocid" ]]; then
    echo "INFO: compartment OCID from COMPARTMENT_OCID (override)" >&2
    echo "$compartment_ocid"
    return 0
  fi

  state_file="$(_foundation_scaffold_state_file "$root_dir")"
  if [[ -f "$state_file" ]]; then
    compartment_ocid="$(jq -r '.compartment.ocid // .inputs.oci_compartment // empty' "$state_file" 2>/dev/null || true)"
    if [[ -n "$compartment_ocid" && "$compartment_ocid" != "null" ]]; then
      echo "INFO: compartment OCID from foundation scaffold state (${state_file}) — same stack as tools/infra_setup.sh" >&2
      echo "$compartment_ocid"
      return 0
    fi
    echo "WARN: foundation state file exists but has no compartment OCID: ${state_file}" >&2
  else
    echo "WARN: no foundation scaffold state at ${state_file} — run ./tools/infra_setup.sh first, or set COMPARTMENT_OCID" >&2
  fi

  if [[ "${TF_REQUIRE_FOUNDATION_SCAFFOLD_STATE:-false}" == "true" ]]; then
    echo "FAIL: TF_REQUIRE_FOUNDATION_SCAFFOLD_STATE=true but could not read .compartment.ocid from foundation state (${state_file})" >&2
    return 1
  fi

  scaffold_dir="${root_dir}/oci_scaffold"
  if [[ ! -d "$scaffold_dir" ]]; then
    echo "FAIL: oci_scaffold missing at ${scaffold_dir}; cannot fall back to path lookup for ${compartment_path}" >&2
    return 1
  fi

  # oci_scaffold prints informational messages to stdout when sourced.
  # Ensure we return ONLY the OCID on stdout.
  export NAME_PREFIX="tf_fs_lookup"
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

  echo "INFO: compartment OCID from oci_scaffold path lookup (${compartment_path}) — not foundation state file" >&2
  echo "$compartment_ocid"
}

# Resolve Terraform working directory.
# - With a stable test_id: reuse progress/sprint_2/tf_state/<test_id> across runs (avoids repeated terraform init).
# - Without test_id: ephemeral mktemp dir (legacy isolation).
# - TF_RESET_TF_STATE=true: remove <test_id> dir before use (clean create / conflict recovery).
# - TF_TEST_ID: default id if no argument passed (optional).
_tf_workdir() {
  local root_dir base test_id dir
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  base="${TF_STATE_ROOT:-${root_dir}/progress/sprint_2/tf_state}"
  test_id="${1:-${TF_TEST_ID:-}}"
  mkdir -p "$base"
  if [[ -z "$test_id" ]]; then
    export TF_WORKDIR_EPHEMERAL=1
    mktemp -d "${base}/tf_fs_XXXXXX"
    return 0
  fi
  export TF_WORKDIR_EPHEMERAL=0
  dir="${base}/${test_id}"
  if [[ "${TF_RESET_TF_STATE:-false}" == "true" ]]; then
    rm -rf "$dir"
  fi
  mkdir -p "$dir"
  echo "$dir"
}

# Run after each test body. EXIT traps are unsafe here: run.sh may invoke several test_* functions in one
# shell (manifest entries), and each trap would overwrite the previous — only the last workdir would be destroyed.
_tf_teardown_workdir() {
  local workdir="$1"
  local skip_teardown="${2:-false}"
  local ephemeral="${3:-1}"

  [[ -z "$workdir" || ! -d "$workdir" ]] && return 0

  if [[ "$skip_teardown" == "true" ]]; then
    echo "INFO: SKIP_TEARDOWN=true — terraform state preserved at: ${workdir}" >&2
    return 0
  fi

  mkdir -p "${workdir}/tf_test_artifacts"
  # Avoid `terraform state list` here — it can invoke providers and block. Local backend state file is enough.
  local state_json="${workdir}/terraform.tfstate"
  if [[ ! -f "$state_json" ]] || ! jq -e '(.resources // []) | length > 0' "$state_json" >/dev/null 2>&1; then
    echo "INFO: no Terraform-managed resources in state — skipping terraform destroy (${workdir})" >&2
  else
    echo "INFO: terraform destroy (test teardown) in ${workdir} …" >&2
    (cd "$workdir" && terraform destroy -auto-approve -input=false 2>&1 | tee "${workdir}/tf_test_artifacts/destroy.stdout.log") || true
  fi

  if [[ "$ephemeral" == "1" ]]; then
    rm -rf "$workdir"
  else
    echo "INFO: kept TF workdir for reuse (terraform init skipped on next run): ${workdir}" >&2
  fi
}

_pick_alternate_ad_name() {
  local current_ad="$1"
  local other

  other="$(oci iam availability-domain list --query "data[?name!='${current_ad}'].name | [0]" --raw-output 2>/dev/null || true)"
  if [[ -z "$other" || "$other" == "null" ]]; then
    return 1
  fi
  echo "$other"
}

# Read availability_domain from authoritative Terraform JSON state (not terraform state show text).
_tf_filesystem_used_ad_from_state() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "FAIL: jq is required for IT-3 state parsing (terraform state pull | jq)" >&2
    return 1
  fi
  terraform state pull | jq -r '
    .resources[]
    | select(.module == "module.fs" and .type == "oci_file_storage_file_system" and .name == "this")
    | .instances[0].attributes.availability_domain // empty
  ' | head -n1
}

# Terraform integration artifacts (see progress/sprint_2/sprint_2_tf_rules.md).
_tf_artifacts_dir() {
  local workdir="$1"
  local d="${workdir}/tf_test_artifacts"
  mkdir -p "$d"
  echo "$d"
}

_tf_save_plan_text() {
  local plan_bin="$1"
  terraform show -no-color "$plan_bin" >"${plan_bin}.txt"
}

test_IT4_happy_path_apply_creates_filesystem() {
  echo "=== IT-4: Happy path — terraform apply creates filesystem and returns OCID ==="

  local root_dir module_dir compartment_path workdir skip_teardown ephemeral ec=0
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_sprint2"

  if [[ ! -d "$module_dir" ]]; then
    echo "FAIL: missing module dir: ${module_dir}" >&2
    return 1
  fi

  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  workdir="$(_tf_workdir it4_happy_path)"
  ephemeral="${TF_WORKDIR_EPHEMERAL:-1}"
  echo "INFO: workdir=${workdir}"

  skip_teardown="${SKIP_TEARDOWN:-false}"

  (
    cd "$workdir"
    local artifacts_dir
    artifacts_dir="$(_tf_artifacts_dir "$workdir")"

    local compartment_ocid
    compartment_ocid="$(_resolve_compartment_ocid "$compartment_path")"

    cat > main.tf <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fs" {
  source           = "${module_dir}"
  compartment_ocid = "${compartment_ocid}"
  name_prefix      = "fss_it"
}

output "filesystem_ocid" {
  value = module.fs.filesystem_ocid
}
EOF

    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"

    local fs_ocid
    fs_ocid="$(terraform output -raw filesystem_ocid)"
    if [[ -z "$fs_ocid" || "$fs_ocid" == "null" ]]; then
      echo "FAIL: filesystem_ocid output is empty" >&2
      exit 1
    fi

    echo "PASS: IT-4 (filesystem_ocid=${fs_ocid})"
  ) || ec=$?

  _tf_teardown_workdir "$workdir" "$skip_teardown" "$ephemeral"
  return "$ec"
}

test_IT2_defaults_when_name_missing() {
  echo "=== IT-2: Defaults path — defaults work when name inputs are omitted ==="

  local root_dir module_dir compartment_path workdir skip_teardown ephemeral ec=0
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_sprint2"
  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  workdir="$(_tf_workdir it2_defaults_name)"
  ephemeral="${TF_WORKDIR_EPHEMERAL:-1}"
  echo "INFO: workdir=${workdir}"
  skip_teardown="${SKIP_TEARDOWN:-false}"

  (
    cd "$workdir"
    local artifacts_dir
    artifacts_dir="$(_tf_artifacts_dir "$workdir")"

    local compartment_ocid
    compartment_ocid="$(_resolve_compartment_ocid "$compartment_path")"

    # AD behavior is covered by IT-4. Here we focus ONLY on name/display_name defaults.
    cat > main.tf <<EOF
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
  source           = "${module_dir}"
  compartment_ocid = "${compartment_ocid}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
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
    if [[ -z "$fs_name" || "$fs_name" == "null" ]]; then
      echo "FAIL: filesystem_display_name output is empty" >&2
      exit 1
    fi

    echo "PASS: IT-2 (filesystem_display_name=${fs_name})"
  ) || ec=$?

  _tf_teardown_workdir "$workdir" "$skip_teardown" "$ephemeral"
  return "$ec"
}

test_IT1_error_path_missing_compartment_is_error() {
  echo "=== IT-1: Error path — missing required compartment_ocid fails ==="

  local root_dir module_dir workdir skip_teardown ephemeral ec=0
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_sprint2"

  workdir="$(_tf_workdir it1_error_missing_compartment)"
  ephemeral="${TF_WORKDIR_EPHEMERAL:-1}"
  echo "INFO: workdir=${workdir}"
  skip_teardown="${SKIP_TEARDOWN:-false}"

  (
    cd "$workdir"
    local artifacts_dir
    artifacts_dir="$(_tf_artifacts_dir "$workdir")"

    # Intentionally omit compartment_ocid.
    cat > main.tf <<EOF
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
      echo "FAIL: terraform validate unexpectedly succeeded without compartment_ocid" >&2
      exit 1
    fi

    echo "PASS: IT-1"
  ) || ec=$?

  _tf_teardown_workdir "$workdir" "$skip_teardown" "$ephemeral"
  return "$ec"
}

test_IT3_defaults_path_ad_behavior_sequence_plan_replace() {
  echo "=== IT-3: Defaults path — AD behavior sequence (apply default, no-change, plan replace) ==="

  local root_dir module_dir compartment_path workdir skip_teardown ephemeral ec=0
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_sprint2"
  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  workdir="$(_tf_workdir it3_ad_sequence_replace)"
  ephemeral="${TF_WORKDIR_EPHEMERAL:-1}"
  echo "INFO: workdir=${workdir}"
  skip_teardown="${SKIP_TEARDOWN:-false}"

  (
    cd "$workdir"
    local artifacts_dir
    artifacts_dir="$(_tf_artifacts_dir "$workdir")"

    local compartment_ocid
    compartment_ocid="$(_resolve_compartment_ocid "$compartment_path")"

    # 1) Create FSS w/o AD specified (module picks default and persists it in state).
    cat > main.tf <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fs" {
  source           = "${module_dir}"
  compartment_ocid = "${compartment_ocid}"
  name_prefix      = "fss_it_ad"
}

output "filesystem_ocid" {
  value = module.fs.filesystem_ocid
}
EOF

    terraform init -input=false
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"

    # Capture the AD actually used from state JSON (terraform state show text format is not reliable across versions).
    local used_ad
    used_ad="$(_tf_filesystem_used_ad_from_state)"
    if [[ -z "$used_ad" || "$used_ad" == "null" ]]; then
      echo "FAIL: could not determine used availability_domain from terraform state pull (module.fs oci_file_storage_file_system.this)" >&2
      exit 1
    fi
    echo "INFO: used_ad=${used_ad}"

    # 2) Execute TF again — expected no configuration/state drift without an OCI refresh.
    #
    # OCI may inject Oracle-managed tags asynchronously; refresh can observe those changes as drift.
    # We validate module idempotency here without refresh to avoid false negatives.
    set +e
    terraform plan -detailed-exitcode -input=false -refresh=false -out="${artifacts_dir}/plan_no_change.tfplan" 2>&1 | tee "${artifacts_dir}/plan_no_change.stdout.log"
    rc=$?
    set -e
    _tf_save_plan_text "${artifacts_dir}/plan_no_change.tfplan"
    if [[ "$rc" -ne 0 ]]; then
      plan_text="$(terraform show -no-color "${artifacts_dir}/plan_no_change.tfplan")"
      if [[ "$rc" -eq 2 \
        && "$plan_text" == *"0 to add, 1 to change, 0 to destroy"* \
        && "$plan_text" == *"defined_tags"* \
        && "$plan_text" == *"Oracle-Tags.Created"* ]]; then
        echo "INFO: tolerated immediate Oracle-managed defined_tags propagation in IT-3 no-change check; IT-5 covers refreshed tag idempotency"
      else
        echo "FAIL: expected no-change plan with -refresh=false (exit 0), got exit ${rc}" >&2
        exit 1
      fi
    fi

    # 3) Execute TF with AD provided as another value - plan must show replacement.
    local other_ad
    other_ad="$(_pick_alternate_ad_name "$used_ad")" || {
      echo "SKIP: tenancy/region appears to have only one AD; cannot test replacement behavior"
      exit 0
    }
    echo "INFO: other_ad=${other_ad}"

    cat > override.tf <<EOF
module "fs" {
  availability_domain = "${other_ad}"
}
EOF

    set +e
    terraform plan -detailed-exitcode -input=false -out="${artifacts_dir}/plan_replace.tfplan" 2>&1 | tee "${artifacts_dir}/plan_replace.stdout.log"
    rc=$?
    set -e
    if [[ "$rc" -ne 2 ]]; then
      echo "FAIL: expected plan with changes (exit 2), got exit ${rc}" >&2
      exit 1
    fi

    _tf_save_plan_text "${artifacts_dir}/plan_replace.tfplan"
    plan_text="$(terraform show -no-color "${artifacts_dir}/plan_replace.tfplan")"
    if [[ "$plan_text" != *"module.fs.oci_file_storage_file_system.this"* ]]; then
      echo "FAIL: plan does not mention filesystem resource" >&2
      exit 1
    fi
    if [[ "$plan_text" != *"destroy"* || "$plan_text" != *"create"* ]]; then
      echo "FAIL: expected plan to indicate destroy/create replacement" >&2
      exit 1
    fi

    echo "PASS: IT-3"
  ) || ec=$?

  _tf_teardown_workdir "$workdir" "$skip_teardown" "$ephemeral"
  return "$ec"
}

test_IT5_defaults_path_tags_create_then_update_same_tags() {
  echo "=== IT-5: Defaults path — tags behavior (create then update with same tags) ==="

  local root_dir module_dir compartment_path workdir skip_teardown ephemeral ec=0
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_sprint2"
  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  workdir="$(_tf_workdir it5_tags_create_update)"
  ephemeral="${TF_WORKDIR_EPHEMERAL:-1}"
  echo "INFO: workdir=${workdir}"
  skip_teardown="${SKIP_TEARDOWN:-false}"

  (
    cd "$workdir"
    local artifacts_dir
    artifacts_dir="$(_tf_artifacts_dir "$workdir")"

    local compartment_ocid
    compartment_ocid="$(_resolve_compartment_ocid "$compartment_path")"

    # Create with explicit tags: freeform tags are set; defined_tags is {} (no test namespace).
    cat > main.tf <<EOF
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

module "fs" {
  source           = "${module_dir}"
  compartment_ocid = "${compartment_ocid}"
  name_prefix      = "fss_it_tags"

  freeform_tags = {
    test_case = "IT-5"
    owner     = "oci_tf_fss"
  }

  defined_tags = {}
}

output "filesystem_ocid" {
  value = module.fs.filesystem_ocid
}
EOF

    terraform init -input=false

    # (1) Create
    terraform plan -input=false -out="${artifacts_dir}/deploy.tfplan"
    _tf_save_plan_text "${artifacts_dir}/deploy.tfplan"
    terraform apply -auto-approve -input=false "${artifacts_dir}/deploy.tfplan" 2>&1 | tee "${artifacts_dir}/deploy.stdout.log"

    # Oracle may inject Oracle-Tags.* defined tags on create; wait so list data reads include them before assert.
    local wait_secs
    wait_secs="${IT5_ORACLE_TAGS_WAIT_SECONDS:-10}"
    echo "INFO: waiting ${wait_secs}s before tag idempotency plan (Oracle managed tags propagation)"
    sleep "${wait_secs}"

    # (2) Update (same tags): refresh + plan must be no-change
    set +e
    terraform plan -detailed-exitcode -input=false -out="${artifacts_dir}/plan_after_create.tfplan" 2>&1 | tee "${artifacts_dir}/plan_after_create.stdout.log"
    rc=$?
    set -e
    if [[ "$rc" -ne 0 ]]; then
      echo "FAIL: expected no-change plan after create when using same tags (exit 0), got exit ${rc}" >&2
      exit 1
    fi
    _tf_save_plan_text "${artifacts_dir}/plan_after_create.tfplan"

    echo "PASS: IT-5"
  ) || ec=$?

  _tf_teardown_workdir "$workdir" "$skip_teardown" "$ephemeral"
  return "$ec"
}

main() {
  # error_path
  test_IT1_error_path_missing_compartment_is_error

  # defaults_path
  test_IT2_defaults_when_name_missing
  test_IT3_defaults_path_ad_behavior_sequence_plan_replace
  test_IT5_defaults_path_tags_create_then_update_same_tags

  # happy_path (run last)
  test_IT4_happy_path_apply_creates_filesystem
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
