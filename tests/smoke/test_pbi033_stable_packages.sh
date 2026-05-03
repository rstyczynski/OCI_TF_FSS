#!/usr/bin/env bash
set -euo pipefail

_root_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

test_SM1_symlink_targets() {
  echo "=== SM-1: stable package symlinks resolve to correct sprint directories ==="

  local root_dir packages_dir
  root_dir="$(_root_dir)"
  packages_dir="${root_dir}/terraform/packages"

  local target
  target="$(readlink "${packages_dir}/fss_stack")"
  [[ "$target" == "../modules/fss_stack_sprint17" ]] || { echo "FAIL: fss_stack -> ${target}"; return 1; }

  target="$(readlink "${packages_dir}/fss_stack_orm")"
  [[ "$target" == "../modules/fss_stack_sprint13_orm" ]] || { echo "FAIL: fss_stack_orm -> ${target}"; return 1; }

  target="$(readlink "${packages_dir}/fss_stack_orm_advanced")"
  [[ "$target" == "../modules/fss_stack_sprint16_orm_advanced" ]] || { echo "FAIL: fss_stack_orm_advanced -> ${target}"; return 1; }

  echo "PASS: SM-1"
}

test_SM2_terraform_validate() {
  echo "=== SM-2: terraform validate passes through all stable package names ==="

  local root_dir
  root_dir="$(_root_dir)"

  terraform -chdir="${root_dir}/terraform/packages/fss_stack" validate
  terraform -chdir="${root_dir}/terraform/packages/fss_stack_orm" validate
  terraform -chdir="${root_dir}/terraform/packages/fss_stack_orm_advanced" validate

  echo "PASS: SM-2"
}

test_SM3_project_rules_contain_r1_r2() {
  echo "=== SM-3: PROJECT_RULES.md contains R1 and R2 ==="

  local root_dir
  root_dir="$(_root_dir)"

  rg -q 'R1 — Module Release Rule' "${root_dir}/PROJECT_RULES.md"
  rg -q 'R2 — Stable Release Name field' "${root_dir}/PROJECT_RULES.md"
  rg -q 'terraform/packages' "${root_dir}/PROJECT_RULES.md"

  echo "PASS: SM-3"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_SM1_symlink_targets
  test_SM2_terraform_validate
  test_SM3_project_rules_contain_r1_r2
fi
