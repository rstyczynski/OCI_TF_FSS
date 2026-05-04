#!/usr/bin/env bash
set -euo pipefail

_root_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

test_SM1_example_validates() {
  echo "=== SM-1: multi_exports_one_fs example passes terraform validate ==="

  local root_dir example_dir
  root_dir="$(_root_dir)"
  example_dir="${root_dir}/terraform/modules/fss_stack_sprint17/examples/multi_exports_one_fs"

  terraform -chdir="$example_dir" fmt -check
  terraform -chdir="$example_dir" validate

  echo "PASS: SM-1"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_SM1_example_validates
fi
