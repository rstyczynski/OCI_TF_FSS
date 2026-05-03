#!/usr/bin/env bash
set -euo pipefail

_root_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

test_SM_bug13_log_id_static_validation() {
  echo "=== SM-BUG-13: logging.log_id bypass static validation ==="

  local root_dir module_dir
  root_dir="$(_root_dir)"
  module_dir="${root_dir}/terraform/modules/fss_stack_sprint17"

  # Verify log_id field is present in variables.tf
  rg -q 'log_id\s*=\s*optional\(string\)' "${module_dir}/variables.tf"

  # Verify logging_lookup_logs excludes entries with log_id set
  rg -q 'try\(mt\.logging\.log_id, null\) == null' "${module_dir}/main.tf"

  # Verify logging_created_logs excludes entries with log_id set
  rg -q 'try\(mt\.logging\.log_id, null\) == null' "${module_dir}/main.tf"

  # Verify resolved_mount_target_logging picks up log_id first in coalesce
  rg -q 'try\(mt\.logging\.log_id, null\)' "${module_dir}/main.tf"

  # Verify module passes terraform validate
  terraform -chdir="${module_dir}" fmt -check
  terraform -chdir="${module_dir}" validate

  # Verify same fix is mirrored in sprint16 orm_advanced vendored copies
  local s16_mt="${root_dir}/terraform/modules/fss_stack_sprint16_orm_advanced/mount_target/modules/fss_stack_sprint17"
  local s16_fe="${root_dir}/terraform/modules/fss_stack_sprint16_orm_advanced/filesystem_export/modules/fss_stack_sprint17"

  rg -q 'log_id\s*=\s*optional\(string\)' "${s16_mt}/variables.tf"
  rg -q 'log_id\s*=\s*optional\(string\)' "${s16_fe}/variables.tf"
  rg -q 'try\(mt\.logging\.log_id, null\) == null' "${s16_mt}/main.tf"
  rg -q 'try\(mt\.logging\.log_id, null\) == null' "${s16_fe}/main.tf"

  terraform -chdir="${s16_mt}/.." fmt -check
  terraform -chdir="${s16_mt}/.." validate
  terraform -chdir="${s16_fe}/.." fmt -check
  terraform -chdir="${s16_fe}/.." validate

  echo "PASS: SM-BUG-13"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_SM_bug13_log_id_static_validation
fi
