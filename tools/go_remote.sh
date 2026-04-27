#!/usr/bin/env bash
# Open an SSH session (or run a remote command) on the Sprint 1 foundation compute.
#
# Uses oci_scaffold state in progress/sprint_1/scaffold/<NAME_PREFIX>/ (same layout as
# tools/infra_setup.sh). Private key: Vault bundle via .secret.ocid when present, else
# ./state-<prefix>-key when FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT=false.
#
# Environment:
#   SPRINT1_NAME_PREFIX          stack prefix (default: infra)
#   SPRINT1_USE_ENV_NAME_PREFIX  true — use NAME_PREFIX from environment
#   WORKDIR                      oci_scaffold directory (default: progress/sprint_1/scaffold/<prefix>)
#   GO_REMOTE_USER               SSH user (default: opc)
#   GO_REMOTE_HOST / GO_REMOTE_IP  override target (default: .compute.public_ip from state)
#   GO_REMOTE_IDENTITY           explicit private key path (skips Vault/local state key)
#   GO_REMOTE_CONNECT_TIMEOUT    ssh ConnectTimeout seconds (default: 15)

set -euo pipefail

_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_scaffold_dir="${_repo_root}/oci_scaffold"

if [[ "${SPRINT1_USE_ENV_NAME_PREFIX:-false}" == "true" ]] && [[ -n "${NAME_PREFIX:-}" ]]; then
  _name_prefix="$NAME_PREFIX"
else
  _name_prefix="${SPRINT1_NAME_PREFIX:-infra}"
fi

if [[ -n "${WORKDIR:-}" ]]; then
  _wd="$WORKDIR"
else
  _wd="${_repo_root}/progress/sprint_1/scaffold/${_name_prefix}"
fi

if [[ ! -d "$_wd" ]]; then
  echo "FAIL: workdir missing: ${_wd}" >&2
  exit 1
fi

cd "$_wd" || exit 1

export PATH="${_scaffold_dir}/do:${_scaffold_dir}/resource:${PATH}"
export NAME_PREFIX="$_name_prefix"

# shellcheck source=/dev/null
source "${_scaffold_dir}/do/oci_scaffold.sh"
# sprint1__raw_key_from_secret_bundle (Vault decode)
# shellcheck source=/dev/null
source "${_repo_root}/tools/infra_setup.sh"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "FAIL: no oci_scaffold state (${STATE_FILE}). Run: ${_repo_root}/tools/infra_setup.sh" >&2
  exit 1
fi

_ssh_key="$(mktemp)"
cleanup() {
  rm -f "$_ssh_key"
}
trap cleanup EXIT

_sec_ocid="$(_state_get '.secret.ocid')"
_local_key="${PWD}/state-${_name_prefix}-key"

if [[ -n "${GO_REMOTE_IDENTITY:-}" ]]; then
  if [[ ! -r "$GO_REMOTE_IDENTITY" ]]; then
    echo "FAIL: GO_REMOTE_IDENTITY not readable: ${GO_REMOTE_IDENTITY}" >&2
    exit 1
  fi
  cp "$GO_REMOTE_IDENTITY" "$_ssh_key"
  chmod 600 "$_ssh_key"
elif [[ -n "$_sec_ocid" && "$_sec_ocid" != "null" ]]; then
  if ! SPRINT1_RAW_KEY_QUIET=true sprint1__raw_key_from_secret_bundle "$_sec_ocid" "$_ssh_key"; then
    exit 1
  fi
elif [[ -f "$_local_key" ]]; then
  cp "$_local_key" "$_ssh_key"
  chmod 600 "$_ssh_key"
else
  echo "FAIL: no SSH private key — set GO_REMOTE_IDENTITY, or ensure Vault (.secret.ocid in state) or local ${_local_key}" >&2
  exit 1
fi

_host="${GO_REMOTE_HOST:-${GO_REMOTE_IP:-}}"
if [[ -z "$_host" ]]; then
  _host="$(_state_get '.compute.public_ip')"
fi
if [[ -z "$_host" || "$_host" == "null" ]]; then
  echo "FAIL: no SSH target — set GO_REMOTE_HOST or provision compute (.compute.public_ip)" >&2
  exit 1
fi

_user="${GO_REMOTE_USER:-opc}"
_cto="${GO_REMOTE_CONNECT_TIMEOUT:-15}"

ssh-keygen -R "$_host" >/dev/null 2>&1 || true

ssh -i "$_ssh_key" \
  -o StrictHostKeyChecking=no \
  -o "ConnectTimeout=${_cto}" \
  "${_user}@${_host}" "$@"
