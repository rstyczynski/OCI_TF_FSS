#!/usr/bin/env bash
set -euo pipefail

_root_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

test_SM_bug12_logging_reuse_static_validation() {
  echo "=== SM-BUG-12: logging reuse static validation ==="

  local root_dir module_dir
  root_dir="$(_root_dir)"
  module_dir="${root_dir}/terraform/modules/fss_stack_sprint17"

  terraform -chdir="$module_dir" fmt -check
  terraform -chdir="$module_dir" validate

  rg -q 'data "oci_logging_log_groups" "mount_target"' "${module_dir}/main.tf"
  rg -q 'data "oci_logging_logs" "mount_target"' "${module_dir}/main.tf"
  rg -q 'local\\.resolved_mount_target_logging' "${module_dir}/outputs.tf"

  echo "PASS: SM-BUG-12"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_SM_bug12_logging_reuse_static_validation
fi
