#!/usr/bin/env bash
set -euo pipefail

_root_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

test_SM1_sprint16_advanced_orm_package_static_validation() {
  echo "=== SM-1: advanced ORM package static validation ==="

  local root_dir package_dir generated_dir
  root_dir="$(_root_dir)"
  package_dir="${root_dir}/terraform/modules/fss_stack_sprint16_orm_advanced"
  generated_dir="${root_dir}/progress/sprint_16/generated_tf/static_validate"
  rm -rf "$generated_dir"
  mkdir -p "$generated_dir"

  for stack in mount_target filesystem_export; do
    for file in main.tf variables.tf outputs.tf versions.tf schema.yaml; do
      if [[ ! -f "${package_dir}/${stack}/${file}" ]]; then
        echo "FAIL: missing ${package_dir}/${stack}/${file}" >&2
        return 1
      fi
    done
  done

  python3 - "$package_dir" <<'PY'
import sys
from pathlib import Path
import yaml

package_dir = Path(sys.argv[1])
for stack in ("mount_target", "filesystem_export"):
    schema_path = package_dir / stack / "schema.yaml"
    schema = yaml.safe_load(schema_path.read_text(encoding="utf-8"))
    for key in ("schemaVersion", "variableGroups", "variables", "outputGroups", "outputs"):
        if key not in schema:
            raise SystemExit(f"{schema_path} missing {key}")
    if stack == "mount_target":
        expected_outputs = {"mount_target_ocid", "export_set_ocid", "mount_address", "ip_address", "mount_target_summary"}
    else:
        expected_outputs = {"filesystem_ocid", "export_ocids", "export_paths", "nfs_mount_sources", "filesystem_export_summary"}
        variables = schema["variables"]
        if variables["existing_mount_target_ocid"].get("type") != "oci:mount:target:id":
            raise SystemExit("filesystem_export must use oci:mount:target:id for mount target selection")
        if variables["export_1_path"].get("default") is not None:
            raise SystemExit("export_1_path must be explicitly supplied by the operator")
        for idx in range(2, 7):
            if f"add_export_{idx}" not in variables:
                raise SystemExit(f"missing chained checkbox add_export_{idx}")
            if variables[f"export_{idx}_path"].get("visible") != f"${{add_export_{idx}}}":
                raise SystemExit(f"export_{idx}_path visibility must depend on add_export_{idx}")
            if variables[f"export_{idx}_path"].get("default") != "":
                raise SystemExit(f"export_{idx}_path must not hide a usable default path")
    variables = schema["variables"]
    if "freeform_tags" in variables:
        raise SystemExit(f"{schema_path} must expose tag pairs instead of raw freeform_tags map")
    for idx in range(1, 11):
        if f"tag_{idx}_key" not in variables or f"tag_{idx}_value" not in variables:
            raise SystemExit(f"{schema_path} missing tag pair {idx}")
    for idx in range(2, 11):
        if f"add_tag_{idx}" not in variables:
            raise SystemExit(f"{schema_path} missing chained checkbox add_tag_{idx}")
        if variables[f"tag_{idx}_key"].get("visible") != f"${{add_tag_{idx}}}":
            raise SystemExit(f"tag_{idx}_key visibility must depend on add_tag_{idx}")
        if variables[f"tag_{idx}_value"].get("visible") != f"${{add_tag_{idx}}}":
            raise SystemExit(f"tag_{idx}_value visibility must depend on add_tag_{idx}")
    missing = expected_outputs - set(schema["outputs"])
    if missing:
        raise SystemExit(f"{schema_path} missing outputs {sorted(missing)}")
print("PASS: schemas parse and expose required controls")
PY

  terraform fmt -check -recursive "$package_dir"

  for stack in mount_target filesystem_export; do
    (
      cd "${package_dir}/${stack}"
      terraform init -backend=false -input=false
      terraform validate
    )
  done

  echo "PASS: SM-1"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_SM1_sprint16_advanced_orm_package_static_validation
fi
