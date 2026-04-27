#!/usr/bin/env bash
set -euo pipefail

test_IT1_provision_foundation_baseline() {
  echo "=== IT-1: Provision foundation baseline (network + optional compute) ==="

  local root_dir scaffold_dir workdir name_prefix compartment_path
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  scaffold_dir="${root_dir}/oci_scaffold"

  name_prefix="${NAME_PREFIX:-fss_foundation}"
  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  if [[ ! -d "$scaffold_dir" ]]; then
    echo "FAIL: missing oci_scaffold submodule at ${scaffold_dir}" >&2
    return 1
  fi

  workdir="$(mktemp -d "/tmp/oci_tf_fss_${name_prefix}_XXXXXX")"
  echo "INFO: workdir=${workdir}"

  # Ensure teardown is attempted unless explicitly disabled.
  local skip_teardown="${SKIP_TEARDOWN:-false}"

  # Always try to teardown on exit unless user explicitly wants to keep resources.
  _cleanup() {
    local ec=$?
    if [[ "$skip_teardown" != "true" ]]; then
      (
        cd "$workdir"
        export PATH="$scaffold_dir/do:$scaffold_dir/resource:$PATH"
        export NAME_PREFIX="$name_prefix"
        bash "$scaffold_dir/do/teardown.sh" || true
      )
    fi
    rm -rf "$workdir"
    return "$ec"
  }
  trap _cleanup EXIT

  (
    cd "$workdir"
    export PATH="$scaffold_dir/do:$scaffold_dir/resource:$PATH"
    export NAME_PREFIX="$name_prefix"

    # shellcheck source=/dev/null
    source "$scaffold_dir/do/oci_scaffold.sh"

    # Compartment: ensure full path exists and capture OCID.
    _state_set '.inputs.compartment_path' "$compartment_path"
    ensure-compartment.sh
    local compartment_ocid
    compartment_ocid="$(_state_get '.compartment.ocid')"
    if [[ -z "$compartment_ocid" || "$compartment_ocid" == "null" ]]; then
      echo "FAIL: could not resolve compartment OCID for ${compartment_path}" >&2
      exit 1
    fi

    # Seed inputs (mirrors cycle-compute.sh defaults).
    _state_set '.inputs.oci_compartment' "$compartment_ocid"
    _state_set '.inputs.name_prefix' "$name_prefix"

    # Public subnet + SSH from anywhere (operator requirement).
    _state_set '.inputs.subnet_prohibit_public_ip' 'false'
    _state_set '.inputs.sl_ingress_cidr' '0.0.0.0/0'

    # SSH keypair — mirrors cycle-compute.sh behavior.
    local ssh_key="${PWD}/state-${name_prefix}-key"
    if [[ ! -f "$ssh_key" ]]; then
      ssh-keygen -t rsa -b 4096 -N "" -f "$ssh_key" -C "${name_prefix}-compute" >/dev/null
      echo "INFO: SSH key generated: ${ssh_key}"
    fi
    _state_set '.inputs.compute_ssh_authorized_keys_file' "${ssh_key}.pub"

    # Provision network + compute (subset of cycle-compute.sh; non-interactive).
    ensure-vcn.sh
    ensure-sl.sh
    ensure-igw.sh
    ensure-rt.sh
    ensure-subnet.sh
    ensure-compute.sh

    local compute_ocid compute_public_ip
    compute_ocid="$(_state_get '.compute.ocid')"
    compute_public_ip="$(_state_get '.compute.public_ip')"

    if [[ -z "$compute_ocid" || "$compute_ocid" == "null" ]]; then
      echo "FAIL: compute OCID missing in state" >&2
      exit 1
    fi
    if [[ -z "$compute_public_ip" || "$compute_public_ip" == "null" ]]; then
      echo "FAIL: compute public IP missing in state (public SSH required)" >&2
      exit 1
    fi

    echo "INFO: compute_ocid=${compute_ocid}"
    echo "INFO: compute_public_ip=${compute_public_ip}"

    # SSH readiness check (operator acceptance signal).
    ssh-keygen -R "$compute_public_ip" >/dev/null 2>&1 || true

    local elapsed=0
    while true; do
      printf "\033[2K\r  [WAIT] Waiting for SSH %s … %ds" "$compute_public_ip" "$elapsed"
      ssh -i "$ssh_key" \
        -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
        "opc@${compute_public_ip}" true 2>/dev/null && { echo; break; }
      sleep 5
      elapsed=$((elapsed + 5))
      if [[ "$elapsed" -ge 600 ]]; then
        echo ""
        echo "FAIL: SSH did not become ready within 600s" >&2
        exit 1
      fi
    done

    # Wait for cloud-init to finish (same signal as cycle-compute.sh).
    echo "INFO: waiting for cloud-init to complete"
    elapsed=0
    while true; do
      local ci_status=""
      ci_status=$(ssh -i "$ssh_key" \
        -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
        "opc@${compute_public_ip}" "sudo cloud-init status 2>/dev/null" 2>/dev/null) || true
      printf "\033[2K\r  [WAIT] cloud-init … %ds (status: %s)" "$elapsed" "$ci_status"
      [[ "$ci_status" == *"done"* ]] && { echo; break; }
      [[ "$ci_status" == *"error"* ]] && { echo; echo "FAIL: cloud-init failed: ${ci_status}" >&2; exit 1; }
      sleep 10
      elapsed=$((elapsed + 10))
      if [[ "$elapsed" -ge 1200 ]]; then
        echo ""
        echo "FAIL: cloud-init did not complete within 1200s" >&2
        exit 1
      fi
    done

    echo "INFO: ssh command: ssh -i ${ssh_key} opc@${compute_public_ip}"
    echo "PASS: IT-1"
  )
}

main() {
  test_IT1_provision_foundation_baseline
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

