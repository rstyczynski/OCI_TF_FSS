#!/usr/bin/env bash
set -euo pipefail

test_IT1_terraform_apply_creates_filesystem() {
  echo "=== IT-1: Terraform apply creates filesystem and returns OCID ==="

  # TODO: implement
  # - Create a temp working directory
  # - Render a minimal terraform root config that calls the filesystem module
  # - Resolve compartment OCID for /oci_tf_fss (via OCI CLI) or accept COMPARTMENT_OCID env
  # - terraform init
  # - terraform apply -auto-approve
  # - terraform output -json and assert filesystem_ocid is non-empty

  echo "FAIL: IT-1 — not implemented"
  return 1
}

main() {
  test_IT1_terraform_apply_creates_filesystem
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

