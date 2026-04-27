#!/usr/bin/env bash
set -euo pipefail

test_IT1_provision_foundation_baseline() {
  echo "=== IT-1: Provision foundation baseline (network + optional compute) ==="

  # TODO: implement
  # - Provision baseline resources using oci_scaffold with:
  #   COMPARTMENT_PATH=/oci_tf_fss
  #   NAME_PREFIX=fss_foundation
  # - Assert required identifiers exist:
  #   - subnet OCID (and VCN OCID if needed)
  #   - compute OCID + public IP
  # - Generate/locate SSH keypair (mirrors oci_scaffold/cycle-compute.sh):
  #   - state-fss_foundation-key and state-fss_foundation-key.pub in working directory
  # - SSH readiness check (operator acceptance signal):
  #   ssh -i state-fss_foundation-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
  #     "opc@${COMPUTE_PUBLIC_IP}" true
  #   ssh -i state-fss_foundation-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
  #     "opc@${COMPUTE_PUBLIC_IP}" hostname

  echo "FAIL: IT-1 — not implemented"
  return 1
}

main() {
  test_IT1_provision_foundation_baseline
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

