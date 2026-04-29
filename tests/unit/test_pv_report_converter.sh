#!/usr/bin/env bash
set -euo pipefail

_root_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

test_UT1_templates_convert_to_fss_stack_tfvars() {
  echo "=== UT-1: templates convert to FSS stack tfvars ==="

  local root_dir out_dir
  root_dir="$(_root_dir)"
  out_dir="${root_dir}/progress/sprint_14/unit_expected"
  mkdir -p "$out_dir"

  for template in pv-template1-details pv-template2-details pv-template3-details; do
    local input="${root_dir}/etc/${template}"
    local output="${out_dir}/${template}.auto.tfvars"

    "${root_dir}/tools/convert_pv_report_to_fss_tfvars.py" "$input" -o "$output"

    if ! grep -q '^mount_targets = {' "$output"; then
      echo "FAIL: ${output} missing mount_targets" >&2
      return 1
    fi
    if ! grep -q '^filesystems = {' "$output"; then
      echo "FAIL: ${output} missing filesystems" >&2
      return 1
    fi
    if ! grep -q 'legacy_path' "$output"; then
      echo "FAIL: ${output} missing legacy_path tag" >&2
      return 1
    fi
    if ! grep -q 'mount_target_key' "$output"; then
      echo "FAIL: ${output} missing export mount_target_key" >&2
      return 1
    fi
  done

  local template1_pv_count template2_pv_count template3_pv_count
  template1_pv_count="$(grep -c '^  "pvc_' "${out_dir}/pv-template1-details.auto.tfvars")"
  template2_pv_count="$(grep -c '^  "pv_static_' "${out_dir}/pv-template2-details.auto.tfvars")"
  template3_pv_count="$(grep -c '^  "pvc_' "${out_dir}/pv-template3-details.auto.tfvars")"

  [[ "$template1_pv_count" -eq 6 ]] || { echo "FAIL: template1 expected 6 filesystems, got ${template1_pv_count}" >&2; return 1; }
  [[ "$template2_pv_count" -eq 1 ]] || { echo "FAIL: template2 expected 1 filesystem, got ${template2_pv_count}" >&2; return 1; }
  [[ "$template3_pv_count" -eq 14 ]] || { echo "FAIL: template3 expected 14 filesystems, got ${template3_pv_count}" >&2; return 1; }

  echo "PASS: UT-1"
}

test_UT2_malformed_report_fails() {
  echo "=== UT-2: malformed report fails clearly ==="

  local root_dir fixture output err
  root_dir="$(_root_dir)"
  fixture="${root_dir}/progress/sprint_14/test_fixtures/malformed_missing_storageclass.details"
  output="${root_dir}/progress/sprint_14/unit_expected/malformed.auto.tfvars"
  err="${root_dir}/progress/sprint_14/unit_expected/malformed.stderr.log"
  mkdir -p "$(dirname "$fixture")" "$(dirname "$output")"

  cat >"$fixture" <<'EOF'
NAME                   STATUS   ROLES    AGE      VERSION            ZONE
node-test-001.example  Ready    worker   1d       v1.27.11+example   test
##########
PV Name: pvc-bad
path: /legacy/bad/pvc-bad
server: 10.0.9.10
##########
EOF

  if "${root_dir}/tools/convert_pv_report_to_fss_tfvars.py" "$fixture" -o "$output" 2>"$err"; then
    echo "FAIL: malformed report unexpectedly succeeded" >&2
    return 1
  fi
  if ! grep -q 'missing storageclass' "$err"; then
    echo "FAIL: malformed error did not mention missing storageclass" >&2
    cat "$err" >&2
    return 1
  fi

  echo "PASS: UT-2"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_UT1_templates_convert_to_fss_stack_tfvars
  test_UT2_malformed_report_fails
fi
