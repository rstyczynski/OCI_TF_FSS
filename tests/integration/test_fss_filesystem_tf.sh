#!/usr/bin/env bash
set -euo pipefail

_resolve_compartment_ocid() {
  local compartment_path="${1:-/oci_tf_fss}"
  local root_dir scaffold_dir compartment_ocid

  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  compartment_ocid="${COMPARTMENT_OCID:-}"

  if [[ -n "$compartment_ocid" ]]; then
    echo "$compartment_ocid"
    return 0
  fi

  scaffold_dir="${root_dir}/oci_scaffold"
  if [[ ! -d "$scaffold_dir" ]]; then
    echo "FAIL: COMPARTMENT_OCID not set and oci_scaffold missing at ${scaffold_dir}" >&2
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

  echo "$compartment_ocid"
}

_tf_workdir() {
  local root_dir base
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  base="${TF_STATE_ROOT:-${root_dir}/progress/sprint_2/tf_state}"
  mkdir -p "$base"
  mktemp -d "${base}/tf_fs_XXXXXX"
}

_tf_cleanup_trap() {
  local workdir="$1"
  local skip_teardown="${2:-false}"
  # shellcheck disable=SC2154
  trap 'ec=$?; if [[ -n "'"$workdir"'" && "'"$skip_teardown"'" != "true" ]]; then (cd "'"$workdir"'" && terraform destroy -auto-approve || true); rm -rf "'"$workdir"'"; else [[ -n "'"$workdir"'" ]] && echo "INFO: SKIP_TEARDOWN=true — terraform state preserved at: '"$workdir"'"; fi; exit $ec' EXIT
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

test_IT4_happy_path_apply_creates_filesystem() {
  echo "=== IT-4: Happy path — terraform apply creates filesystem and returns OCID ==="

  local root_dir module_dir compartment_path
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_filesystem"

  if [[ ! -d "$module_dir" ]]; then
    echo "FAIL: missing module dir: ${module_dir}" >&2
    return 1
  fi

  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  workdir="$(_tf_workdir)"
  echo "INFO: workdir=${workdir}"

  skip_teardown="${SKIP_TEARDOWN:-false}"
  _tf_cleanup_trap "$workdir" "$skip_teardown"

  (
    cd "$workdir"

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
    terraform apply -auto-approve -input=false

    local fs_ocid
    fs_ocid="$(terraform output -raw filesystem_ocid)"
    if [[ -z "$fs_ocid" || "$fs_ocid" == "null" ]]; then
      echo "FAIL: filesystem_ocid output is empty" >&2
      exit 1
    fi

    echo "PASS: IT-4 (filesystem_ocid=${fs_ocid})"
  )
}

test_IT2_defaults_when_name_missing() {
  echo "=== IT-2: Defaults path — defaults work when name inputs are omitted ==="

  local root_dir module_dir compartment_path
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_filesystem"
  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  workdir="$(_tf_workdir)"
  echo "INFO: workdir=${workdir}"
  skip_teardown="${SKIP_TEARDOWN:-false}"
  _tf_cleanup_trap "$workdir" "$skip_teardown"

  (
    cd "$workdir"
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
    terraform apply -auto-approve -input=false

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
  )
}

test_IT1_error_path_missing_compartment_is_error() {
  echo "=== IT-1: Error path — missing required compartment_ocid fails ==="

  local root_dir module_dir
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_filesystem"

  workdir="$(_tf_workdir)"
  echo "INFO: workdir=${workdir}"
  skip_teardown="${SKIP_TEARDOWN:-false}"
  _tf_cleanup_trap "$workdir" "$skip_teardown"

  (
    cd "$workdir"

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
    terraform validate
    rc=$?
    set -e

    if [[ "$rc" -eq 0 ]]; then
      echo "FAIL: terraform validate unexpectedly succeeded without compartment_ocid" >&2
      exit 1
    fi

    echo "PASS: IT-1"
  )
}

test_IT3_defaults_path_ad_behavior_sequence_plan_replace() {
  echo "=== IT-3: Defaults path — AD behavior sequence (apply default, no-change, plan replace) ==="

  local root_dir module_dir compartment_path
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_filesystem"
  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  workdir="$(_tf_workdir)"
  echo "INFO: workdir=${workdir}"
  skip_teardown="${SKIP_TEARDOWN:-false}"
  _tf_cleanup_trap "$workdir" "$skip_teardown"

  (
    cd "$workdir"
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
    terraform apply -auto-approve -input=false

    # Capture the AD actually used from state JSON (terraform state show text format is not reliable across versions).
    local used_ad
    used_ad="$(_tf_filesystem_used_ad_from_state)"
    if [[ -z "$used_ad" || "$used_ad" == "null" ]]; then
      echo "FAIL: could not determine used availability_domain from terraform state pull (module.fs oci_file_storage_file_system.this)" >&2
      exit 1
    fi
    echo "INFO: used_ad=${used_ad}"

    # 2) Execute TF again — expected no further changes (module ignores Oracle-managed tag drift).
    set +e
    terraform plan -detailed-exitcode -input=false
    rc=$?
    set -e
    if [[ "$rc" -ne 0 ]]; then
      echo "FAIL: expected no-change plan (exit 0), got exit ${rc}" >&2
      exit 1
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
    terraform plan -detailed-exitcode -input=false -out tfplan
    rc=$?
    set -e
    if [[ "$rc" -ne 2 ]]; then
      echo "FAIL: expected plan with changes (exit 2), got exit ${rc}" >&2
      exit 1
    fi

    plan_text="$(terraform show -no-color tfplan)"
    if [[ "$plan_text" != *"module.fs.oci_file_storage_file_system.this"* ]]; then
      echo "FAIL: plan does not mention filesystem resource" >&2
      exit 1
    fi
    if [[ "$plan_text" != *"destroy"* || "$plan_text" != *"create"* ]]; then
      echo "FAIL: expected plan to indicate destroy/create replacement" >&2
      exit 1
    fi

    echo "PASS: IT-3"
  )
}

test_IT5_defaults_path_tags_create_then_update_same_tags() {
  echo "=== IT-5: Defaults path — tags behavior (create then update with same tags) ==="

  local root_dir module_dir compartment_path
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_filesystem"
  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  workdir="$(_tf_workdir)"
  echo "INFO: workdir=${workdir}"
  skip_teardown="${SKIP_TEARDOWN:-false}"
  _tf_cleanup_trap "$workdir" "$skip_teardown"

  (
    cd "$workdir"
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
    terraform apply -auto-approve -input=false

    # (2) Update (same tags): refresh + plan must be no-change
    set +e
    terraform plan -detailed-exitcode -input=false
    rc=$?
    set -e
    if [[ "$rc" -ne 0 ]]; then
      echo "FAIL: expected no-change plan after create when using same tags (exit 0), got exit ${rc}" >&2
      exit 1
    fi

    echo "PASS: IT-5"
  )
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

