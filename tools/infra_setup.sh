#!/usr/bin/env bash
# Shared Sprint 1 oci_scaffold foundation stack (Vault → secret → network → compute).
#
# Sprint directory layout (tests/operators): Terraform state lives under
#   progress/sprint_1/tf_state/<test_id>/ ; oci_scaffold foundation state lives under
#   progress/sprint_1/scaffold/<NAME_PREFIX>/ (cwd for this stack). Do not mix both in one directory.
# On completion, sprint1_foundation_infra_setup prints the oci_scaffold paths for this run.
#
# Run directly (no prompts): ./tools/infra_setup.sh — uses Sprint 1 defaults (see bottom).
# When sourced, you must call sprint1_foundation_infra_setup yourself.
#
# Prerequisites before calling sprint1_foundation_infra_setup (library / sourced path):
#   - cwd is the oci_scaffold workdir (STATE_FILE = ./state-${NAME_PREFIX}.json)
#   - PATH includes oci_scaffold/do and oci_scaffold/resource
#   - NAME_PREFIX is exported
#   - source …/oci_scaffold/do/oci_scaffold.sh has been executed
#   - OCI_REGION is exported (or home region will not apply — caller should set it)
#
# Environment:
#   COMPARTMENT_PATH           default /oci_tf_fss
#   FOUNDATION_SSH_SECRET_NAME optional override for Vault secret display name
#   FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT  default true — upload private key to Vault; do not keep
#     ./state-${NAME_PREFIX}-key on disk (only .pub locally). Set false to keep private key file locally.
#   SPRINT1_SKIP_COMPUTE_SECRET_MISMATCH_CHECK  set true for destroy/rehydrate flows
#   SPRINT1_LENIENT_VAULT_PEM               emergency only: fake local key for pubkey (does not fix Vault)
#   FOUNDATION_IMPORT_SSH_PRIVATE_KEY_FILE  path to private key file for one-shot import/upload
#   ROTATE_SSH_KEY              true — rotate RSA PEM + Vault update (oci_bv4db_arch setup_infra pattern)
#   SPRINT1_SKIP_SSH_WAIT       true — do not wait for SSH after compute (default false)
#   SPRINT1_SSH_WAIT_TIMEOUT_SEC  max seconds for SSH probe (default 600)
set -euo pipefail

# Writes validated private key bytes to dest (temp file). Caller removes dest when done if Vault-backed.
sprint1__raw_key_from_secret_bundle() {
  local secret_ocid="$1"
  local dest="$2"
  local bundle_json b64_field

  bundle_json="$(mktemp)"
  b64_field="$(mktemp)"
  if ! oci secrets secret-bundle get \
    --secret-id "$secret_ocid" \
    --output json >"$bundle_json" 2>/dev/null; then
    rm -f "$bundle_json" "$b64_field"
    echo "FAIL: oci secrets secret-bundle get failed for ${secret_ocid}" >&2
    return 1
  fi

  jq -r '.data."secret-bundle-content".content // empty' "$bundle_json" >"$b64_field"
  rm -f "$bundle_json"

  if [[ ! -s "$b64_field" ]] || [[ "$(head -c 4 "$b64_field")" == "null" ]]; then
    rm -f "$b64_field"
    echo "FAIL: secret bundle has empty content for ${secret_ocid}" >&2
    return 1
  fi

  rm -f "$dest"
  tr -d '\n\r\t ' <"$b64_field" | base64 -d >"$dest" 2>/dev/null || true
  rm -f "$b64_field"

  chmod 600 "$dest" 2>/dev/null || true
  if [[ ! -s "$dest" ]] || ! ssh-keygen -y -f "$dest" >/dev/null 2>&1; then
    rm -f "$dest"
    echo "FAIL: Vault secret ${secret_ocid} is not valid private key material after one base64 decode (must match ensure-secret upload). Use FOUNDATION_IMPORT_SSH_PRIVATE_KEY_FILE or fix the secret payload." >&2
    return 1
  fi
  chmod 600 "$dest"
  if [[ "${SPRINT1_RAW_KEY_QUIET:-false}" != "true" ]]; then
    echo "INFO: Vault secret validated (bundle decoded)."
  fi
  return 0
}

# After compute: wait until ssh opc@public_ip succeeds (same probe as integration test).
sprint1__wait_for_ssh_ready() {
  local public_ip="$1"
  local store_vault="$2"
  local ssh_key_legacy="$3"
  local secret_name="$4"

  if [[ -z "$public_ip" || "$public_ip" == "null" ]]; then
    echo "INFO: no compute public IP — skipping SSH readiness wait"
    return 0
  fi
  if [[ "${SPRINT1_SKIP_SSH_WAIT:-false}" == "true" ]]; then
    echo "INFO: SPRINT1_SKIP_SSH_WAIT=true — skipping SSH readiness wait"
    return 0
  fi

  local wait_key sec_ocid elapsed=0 timeout_sec
  wait_key="$(mktemp)"
  timeout_sec="${SPRINT1_SSH_WAIT_TIMEOUT_SEC:-600}"

  if [[ "$store_vault" == "true" ]]; then
    sec_ocid="$(_state_get '.secret.ocid')"
    if [[ -z "$sec_ocid" || "$sec_ocid" == "null" ]]; then
      echo "WARN: no .secret.ocid — cannot materialize private key for SSH wait; skipping" >&2
      rm -f "$wait_key"
      return 0
    fi
    SPRINT1_RAW_KEY_QUIET=true sprint1__raw_key_from_secret_bundle "$sec_ocid" "$wait_key" || {
      echo "WARN: could not decode Vault secret for SSH wait; skipping" >&2
      rm -f "$wait_key"
      return 0
    }
  elif [[ -f "$ssh_key_legacy" ]]; then
    cp "$ssh_key_legacy" "$wait_key"
    chmod 600 "$wait_key"
  else
    echo "WARN: no local ${ssh_key_legacy} for SSH wait; skipping" >&2
    rm -f "$wait_key"
    return 0
  fi

  ssh-keygen -R "$public_ip" >/dev/null 2>&1 || true
  echo "INFO: waiting for SSH (opc@${public_ip}), timeout ${timeout_sec}s …"
  while true; do
    if ssh -i "$wait_key" \
      -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
      "opc@${public_ip}" true 2>/dev/null; then
      echo "INFO: SSH ready — opc@${public_ip} (secret '${secret_name}' when Vault-backed)"
      rm -f "$wait_key"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    if [[ "$elapsed" -ge "$timeout_sec" ]]; then
      rm -f "$wait_key"
      echo "" >&2
      echo "FAIL: SSH did not become ready within ${timeout_sec}s (opc@${public_ip})" >&2
      return 1
    fi
    printf '\r  [WAIT] SSH opc@%s … %ds / %ds' "$public_ip" "$elapsed" "$timeout_sec"
  done
}

sprint1__secret_ocid_by_name() {
  local compartment_ocid="$1"
  local vault_ocid="$2"
  local secret_name="$3"
  oci vault secret list \
    --compartment-id "$compartment_ocid" \
    --vault-id "$vault_ocid" \
    --lifecycle-state ACTIVE \
    --all \
    --query "data[?\"secret-name\"==\`${secret_name}\`].id | [0]" \
    --raw-output 2>/dev/null || true
}

# Post: state contains .compute.* ; public key at ./state-${NAME_PREFIX}-key.pub .
# When FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT=true (default), private key is not kept under ./state-${NAME_PREFIX}-key.
sprint1_foundation_infra_setup() {
  local compartment_path="${COMPARTMENT_PATH:-/oci_tf_fss}"

  _state_set '.inputs.compartment_path' "$compartment_path"
  ensure-compartment.sh
  local compartment_ocid
  compartment_ocid="$(_state_get '.compartment.ocid')"
  if [[ -z "$compartment_ocid" || "$compartment_ocid" == "null" ]]; then
    echo "FAIL: could not resolve compartment OCID for ${compartment_path}" >&2
    return 1
  fi

  _state_set '.inputs.oci_compartment' "$compartment_ocid"
  _state_set '.inputs.oci_region' "$OCI_REGION"
  _state_set '.inputs.name_prefix' "$NAME_PREFIX"

  _state_set '.inputs.subnet_prohibit_public_ip' 'false'
  _state_set '.inputs.sl_ingress_cidr' '0.0.0.0/0'

  ensure-vault.sh
  ensure-key.sh

  local ssh_pub="${PWD}/state-${NAME_PREFIX}-key.pub"
  local ssh_key_legacy="${PWD}/state-${NAME_PREFIX}-key"
  local ssh_priv
  ssh_priv="$(mktemp)"
  trap '[[ -n "${ssh_priv:-}" && -f "$ssh_priv" ]] && rm -f "$ssh_priv"' RETURN

  local secret_name
  secret_name="${FOUNDATION_SSH_SECRET_NAME:-${NAME_PREFIX}-foundation-ssh-private-key}"
  _state_set '.inputs.secret_name' "$secret_name"

  local vault_ocid existing_secret_ocid
  vault_ocid="$(_state_get '.vault.ocid')"
  existing_secret_ocid="$(sprint1__secret_ocid_by_name "$compartment_ocid" "$vault_ocid" "$secret_name")"

  local _import_key="${FOUNDATION_IMPORT_SSH_PRIVATE_KEY_FILE:-}"
  if [[ "${ROTATE_SSH_KEY:-false}" == "true" ]]; then
    echo "INFO: ROTATE_SSH_KEY=true — generating new RSA PEM keypair; Vault secret will be updated if FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT is true"
    rm -f "$ssh_key_legacy" "$ssh_pub"
    existing_secret_ocid=""
    _import_key=""
  fi

  local store_vault="${FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT:-true}"

  if [[ -n "$_import_key" ]]; then
    if [[ ! -r "$_import_key" ]]; then
      echo "FAIL: FOUNDATION_IMPORT_SSH_PRIVATE_KEY_FILE not readable: ${_import_key}" >&2
      return 1
    fi
    cp "$_import_key" "$ssh_priv"
    chmod 600 "$ssh_priv"
    if ! ssh-keygen -y -f "$ssh_priv" >/dev/null 2>&1; then
      echo "FAIL: FOUNDATION_IMPORT_SSH_PRIVATE_KEY_FILE is not a usable SSH private key (ssh-keygen -y)" >&2
      return 1
    fi
    echo "INFO: SSH private key from FOUNDATION_IMPORT_SSH_PRIVATE_KEY_FILE (bundle fetch skipped)"
    if [[ -n "$existing_secret_ocid" && "$existing_secret_ocid" != "null" ]]; then
      _state_set '.secret.ocid' "$existing_secret_ocid"
      _state_set '.secret.name' "$secret_name"
      _state_set '.secret.created' false
    elif [[ "$store_vault" == "true" ]]; then
      echo "INFO: storing imported key in Vault via ensure-secret.sh"
      _state_set '.inputs.secret_value' "$(cat "$ssh_priv")"
      ensure-secret.sh
      _state_set '.inputs.secret_value' ''
      echo "INFO: cleared secret_value from state after Vault upload"
    fi
  elif [[ -n "$existing_secret_ocid" && "$existing_secret_ocid" != "null" ]]; then
    echo "INFO: SSH private key material from existing Vault secret '${secret_name}'"
    if ! sprint1__raw_key_from_secret_bundle "$existing_secret_ocid" "$ssh_priv"; then
      if [[ "${SPRINT1_LENIENT_VAULT_PEM:-false}" == "true" ]]; then
        echo "WARN: could not decode secret bundle; ephemeral key for pubkey only (e.g. teardown rehydrate)" >&2
        rm -f "$ssh_priv"
        ssh-keygen -m PEM -t rsa -b 4096 -N "" -f "$ssh_priv" -C "${NAME_PREFIX}-compute" -q
      else
        return 1
      fi
    fi
    _state_set '.secret.ocid' "$existing_secret_ocid"
    _state_set '.secret.name' "$secret_name"
    _state_set '.secret.created' false
  else
    ssh-keygen -m PEM -t rsa -b 4096 -N "" -f "$ssh_priv" -C "${NAME_PREFIX}-compute" -q
    echo "INFO: generated RSA PEM key (ssh-keygen -m PEM); uploading to Vault if enabled"
    if [[ "$store_vault" == "true" ]]; then
      ssh-keygen -y -f "$ssh_priv" >/dev/null || {
        echo "FAIL: generated key is not valid; refusing Vault upload" >&2
        return 1
      }
      echo "INFO: storing private key in Vault secret '${secret_name}' (ensure-secret.sh)"
      _state_set '.inputs.secret_value' "$(cat "$ssh_priv")"
      ensure-secret.sh
      _state_set '.inputs.secret_value' ''
      echo "INFO: cleared secret_value from state after Vault upload (secret remains in OCI)"
    else
      echo "INFO: FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT=false — private key will remain at ${ssh_key_legacy}"
    fi
  fi

  if ! ssh-keygen -y -f "$ssh_priv" >"$ssh_pub" 2>/dev/null; then
    if [[ "${SPRINT1_LENIENT_VAULT_PEM:-false}" == "true" ]]; then
      echo "WARN: could not derive public key; generating ephemeral RSA PEM for .pub only" >&2
      rm -f "$ssh_priv" "$ssh_pub"
      ssh_priv="$(mktemp)"
      ssh-keygen -m PEM -t rsa -b 4096 -N "" -f "$ssh_priv" -C "${NAME_PREFIX}-compute" -q
      ssh-keygen -y -f "$ssh_priv" >"$ssh_pub"
    else
      echo "FAIL: private key material is unusable after Vault/disk load. Repair Vault secret '${secret_name}' or use SPRINT1_LENIENT_VAULT_PEM=true for emergency only." >&2
      return 1
    fi
  fi

  if [[ "$store_vault" == "true" ]]; then
    rm -f "$ssh_priv"
    rm -f "$ssh_key_legacy"
  else
    mv -f "$ssh_priv" "$ssh_key_legacy"
    chmod 600 "$ssh_key_legacy"
    ssh_priv=""
  fi

  _state_set '.inputs.compute_ssh_authorized_keys_file' "$ssh_pub"

  ensure-vcn.sh
  ensure-sl.sh
  ensure-igw.sh
  ensure-rt.sh
  ensure-subnet.sh
  ensure-compute.sh

  local compute_created secret_created
  compute_created="$(_state_get '.compute.created')"
  secret_created="$(_state_get '.secret.created')"
  if [[ "${SPRINT1_SKIP_COMPUTE_SECRET_MISMATCH_CHECK:-false}" != "true" ]]; then
    if [[ "$compute_created" == "false" && "$secret_created" == "true" ]]; then
      echo "FAIL: Compute was adopted (already existed) but a new Vault secret was created this run. Either pre-populate the foundation secret '${secret_name}' with the key that matches the instance, or recreate compute after the secret exists. See sprint_1_design.md (foundation SSH + Vault)." >&2
      return 1
    fi
  fi

  local compute_public_ip
  compute_public_ip="$(_state_get '.compute.public_ip')"
  sprint1__wait_for_ssh_ready "$compute_public_ip" "$store_vault" "$ssh_key_legacy" "$secret_name" || return 1

  echo "INFO: Sprint 1 oci_scaffold state (this run) — cwd: ${PWD}"
  echo "INFO: STATE_FILE=${STATE_FILE}"
  echo "INFO: SSH public key file: ${ssh_pub}"
  if [[ "$store_vault" == "true" ]]; then
    echo "INFO: Private key is not stored in this directory — use Vault secret '${secret_name}' (e.g. oci secrets secret-bundle get)."
  else
    echo "INFO: Private key file (local only): ${ssh_key_legacy}"
  fi
  echo "INFO: Terraform for this sprint belongs under progress/sprint_1/tf_state/ (separate from this directory)."
}

# Direct execution: full Sprint 1 foundation (non-interactive; Sprint 1 defaults only).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  _infra_setup_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  export PATH="${_infra_setup_repo}/oci_scaffold/do:${_infra_setup_repo}/oci_scaffold/resource:${PATH}"
  _pfx="${SPRINT1_NAME_PREFIX:-infra}"
  export NAME_PREFIX="$_pfx"
  _wd="${WORKDIR:-${_infra_setup_repo}/progress/sprint_1/scaffold/${_pfx}}"
  mkdir -p "$_wd" || exit 1
  cd "$_wd" || exit 1
  # shellcheck source=/dev/null
  source "${_infra_setup_repo}/oci_scaffold/do/oci_scaffold.sh"
  if [[ -z "${OCI_REGION:-}" ]]; then
    OCI_REGION="$(_oci_home_region)"
    export OCI_REGION
  fi
  export COMPARTMENT_PATH="${COMPARTMENT_PATH:-/oci_tf_fss}"
  echo "INFO: infra_setup.sh — cwd=${PWD} NAME_PREFIX=${NAME_PREFIX} COMPARTMENT_PATH=${COMPARTMENT_PATH} OCI_REGION=${OCI_REGION}"
  sprint1_foundation_infra_setup
  exit $?
fi
