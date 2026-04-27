#!/usr/bin/env bash
set -euo pipefail

test_IT1_terraform_apply_creates_filesystem() {
  echo "=== IT-1: Terraform apply creates filesystem and returns OCID ==="

  local root_dir workdir module_dir compartment_path
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  module_dir="${root_dir}/terraform/modules/fss_filesystem"

  if [[ ! -d "$module_dir" ]]; then
    echo "FAIL: missing module dir: ${module_dir}" >&2
    return 1
  fi

  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  workdir="$(mktemp -d "/tmp/oci_tf_fss_tf_fs_XXXXXX")"
  echo "INFO: workdir=${workdir}"

  skip_teardown="${SKIP_TEARDOWN:-false}"
  _cleanup() {
    local ec=$?
    if [[ "${skip_teardown:-false}" != "true" ]]; then
      (
        cd "$workdir"
        terraform destroy -auto-approve || true
      )
      rm -rf "$workdir"
    else
      echo "INFO: SKIP_TEARDOWN=true — terraform state preserved at: ${workdir}"
    fi
    return "$ec"
  }
  trap _cleanup EXIT

  (
    cd "$workdir"

    local compartment_ocid="${COMPARTMENT_OCID:-}"
    if [[ -z "$compartment_ocid" ]]; then
      # Resolve via oci_scaffold helper (walks full compartment path).
      local scaffold_dir="${root_dir}/oci_scaffold"
      if [[ ! -d "$scaffold_dir" ]]; then
        echo "FAIL: COMPARTMENT_OCID not set and oci_scaffold missing at ${scaffold_dir}" >&2
        exit 1
      fi
      export NAME_PREFIX="tf_fs_lookup"
      # shellcheck source=/dev/null
      source "${scaffold_dir}/do/oci_scaffold.sh"
      compartment_ocid="$(_oci_compartment_ocid_by_path "$compartment_path")"
    fi

    if [[ -z "$compartment_ocid" || "$compartment_ocid" == "null" ]]; then
      echo "FAIL: could not resolve compartment OCID for ${compartment_path}" >&2
      exit 1
    fi

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

    echo "PASS: IT-1 (filesystem_ocid=${fs_ocid})"
  )
}

main() {
  test_IT1_terraform_apply_creates_filesystem
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

