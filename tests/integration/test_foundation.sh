#!/usr/bin/env bash
set -euo pipefail

# Sprint 1 foundation integration test. Infra ensure chain lives in ../../tools/infra_setup.sh.

test_IT1_provision_foundation_baseline() {
  echo "=== IT-1: Provision foundation baseline (network + optional compute) ==="

  local root_dir scaffold_dir workdir name_prefix compartment_path
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  scaffold_dir="${root_dir}/oci_scaffold"

  # Default stack prefix is always **infra** unless SPRINT1_NAME_PREFIX is set. We do *not* use a
  # generic NAME_PREFIX from the process environment (CI/agents often export e.g. tf_fs_lookup).
  # To use the environment’s NAME_PREFIX anyway: SPRINT1_USE_ENV_NAME_PREFIX=true
  if [[ "${SPRINT1_USE_ENV_NAME_PREFIX:-false}" == "true" ]] && [[ -n "${NAME_PREFIX:-}" ]]; then
    name_prefix="$NAME_PREFIX"
  else
    name_prefix="${SPRINT1_NAME_PREFIX:-infra}"
  fi
  compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"
  echo "INFO: IT-1 name_prefix=${name_prefix} (set SPRINT1_NAME_PREFIX to override; set SPRINT1_USE_ENV_NAME_PREFIX=true to honor NAME_PREFIX from env)"

  if [[ ! -d "$scaffold_dir" ]]; then
    echo "FAIL: missing oci_scaffold submodule at ${scaffold_dir}" >&2
    return 1
  fi

  # RUP_patch P7: oci_scaffold state under progress/sprint_1/scaffold/ (not tf_state; not /tmp-only).
  if [[ -n "${WORKDIR:-}" ]]; then
    workdir="$WORKDIR"
    mkdir -p "$workdir"
  else
    workdir="${root_dir}/progress/sprint_1/scaffold/${name_prefix}"
    mkdir -p "$workdir"
  fi
  echo "INFO: workdir=${workdir} (oci_scaffold; Terraform uses progress/sprint_1/tf_state/ separately)"

  skip_teardown="${SKIP_TEARDOWN:-false}"

  _cleanup() {
    local ec=$?
    if [[ -n "${workdir:-}" && "${skip_teardown:-false}" != "true" ]]; then
      (
        cd "$workdir"
        export PATH="$scaffold_dir/do:$scaffold_dir/resource:$PATH"
        export NAME_PREFIX="$name_prefix"
        bash "$scaffold_dir/do/teardown.sh" || true
      )
    fi
    if [[ -n "${workdir:-}" && "${skip_teardown:-false}" != "true" ]]; then
      rm -rf "$workdir"
    elif [[ -n "${workdir:-}" ]]; then
      echo "INFO: SKIP_TEARDOWN=true — resources kept; workdir preserved at: ${workdir}"
    fi
    return "$ec"
  }
  trap _cleanup EXIT

  (
    cd "$workdir"
    export PATH="$scaffold_dir/do:$scaffold_dir/resource:$PATH"
    export NAME_PREFIX="$name_prefix"

    # shellcheck source=/dev/null
    source "$scaffold_dir/do/oci_scaffold.sh"

    if [[ -z "${OCI_REGION:-}" ]]; then
      OCI_REGION="$(_oci_home_region)"
    fi
    export OCI_REGION

    # shellcheck source=/dev/null
    source "${root_dir}/tools/infra_setup.sh"

    export COMPARTMENT_PATH="$compartment_path"
    sprint1_foundation_infra_setup

    # Private key is not kept under ./state-<prefix>-key when Vault-backed; materialize from bundle for SSH checks.
    local ssh_identity sec_ocid
    ssh_identity="$(mktemp)"
    trap 'rm -f "$ssh_identity"' EXIT
    sec_ocid="$(_state_get '.secret.ocid')"
    if [[ -n "$sec_ocid" && "$sec_ocid" != "null" ]]; then
      sprint1__raw_key_from_secret_bundle "$sec_ocid" "$ssh_identity" || {
        echo "FAIL: could not materialize private key from Vault for SSH test" >&2
        exit 1
      }
    elif [[ -f "${PWD}/state-${name_prefix}-key" ]]; then
      cp "${PWD}/state-${name_prefix}-key" "$ssh_identity"
      chmod 600 "$ssh_identity"
    else
      echo "FAIL: no Vault secret OCID and no local state-${name_prefix}-key for SSH" >&2
      exit 1
    fi

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

    ssh-keygen -R "$compute_public_ip" >/dev/null 2>&1 || true

    local elapsed=0
    while true; do
      printf "\033[2K\r  [WAIT] Waiting for SSH %s … %ds" "$compute_public_ip" "$elapsed"
      ssh -i "$ssh_identity" \
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

    echo "INFO: waiting for cloud-init to complete"
    elapsed=0
    while true; do
      local ci_status=""
      ci_status=$(ssh -i "$ssh_identity" \
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

    echo "INFO: ssh uses a key materialized from Vault (secret OCID in state); example: oci secrets secret-bundle get --secret-id \"\$SECRET_OCID\" | jq -r '.data.\"secret-bundle-content\".content' | base64 -d > key.pem && chmod 600 key.pem && ssh -i key.pem opc@${compute_public_ip}"
    echo "PASS: IT-1"
  )
}

main() {
  test_IT1_provision_foundation_baseline
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
