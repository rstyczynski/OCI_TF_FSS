#!/usr/bin/env bash
# PBI-035: OCI FSS export path scoping experiment.
# Determines whether two exports from the same filesystem expose the same root
# or scope each client to a distinct subtree.
set -euo pipefail

_root_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

_foundation_scaffold_state_file() {
  local root_dir="$1"
  local prefix="${SPRINT1_NAME_PREFIX:-infra}"
  if [[ -n "${SPRINT1_FOUNDATION_STATE_FILE:-}" ]]; then
    echo "${SPRINT1_FOUNDATION_STATE_FILE}"; return 0
  fi
  if [[ -n "${WORKDIR:-}" ]]; then
    echo "${WORKDIR}/state-${prefix}.json"
  else
    echo "${root_dir}/progress/sprint_1/scaffold/${prefix}/state-${prefix}.json"
  fi
}

_foundation_value() {
  local jq_expr="$1"
  local root_dir state_file value
  root_dir="$(_root_dir)"
  state_file="$(_foundation_scaffold_state_file "$root_dir")"
  [[ -f "$state_file" ]] || { echo "FAIL: missing foundation state: ${state_file}" >&2; return 1; }
  value="$(jq -r "${jq_expr} // empty" "$state_file")"
  [[ -n "$value" && "$value" != "null" ]] || { echo "FAIL: missing ${jq_expr} in foundation state" >&2; return 1; }
  echo "$value"
}

_tf_workdir() {
  local test_id="$1" root_dir base dir
  root_dir="$(_root_dir)"
  base="${TF_GENERATED_ROOT:-${root_dir}/progress/sprint_19/generated_tf}"
  dir="${base}/${test_id}"
  [[ "${TF_RESET_TF_STATE:-true}" != "true" ]] || rm -rf "$dir"
  mkdir -p "${dir}/tf_test_artifacts"
  echo "$dir"
}

_materialize_ssh_key() {
  local root_dir="$1" dest="$2" foundation_state secret_ocid
  foundation_state="$(_foundation_scaffold_state_file "$root_dir")"
  secret_ocid="$(jq -r '.secret.ocid // empty' "$foundation_state")"
  [[ -n "$secret_ocid" && "$secret_ocid" != "null" ]] || { echo "FAIL: no .secret.ocid in foundation state" >&2; return 1; }
  # shellcheck source=/dev/null
  source "${root_dir}/tools/infra_setup.sh"
  sprint1__raw_key_from_secret_bundle "$secret_ocid" "$dest"
}

_first_availability_domain() {
  oci iam availability-domain list \
    --compartment-id "$1" --query 'data[0].name' --raw-output
}

_ssh() {
  local ip="$1" key="$2"; shift 2
  ssh -i "$key" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=15 \
    "opc@${ip}" "$@"
}

test_IT_export_subdir_scoping() {
  echo "=== IT-PBI035: OCI FSS export path scoping ==="
  echo "    1 filesystem, 2 exports (/vol1 and /vol2)"
  echo "    Write via /vol1 — check if visible via /vol2"

  local root_dir compartment_ocid subnet_ocid availability_domain
  local compute_ip workdir artifacts_dir ssh_key suffix ec=0

  root_dir="$(_root_dir)"
  compartment_ocid="$(_foundation_value '.compartment.ocid')"
  subnet_ocid="$(_foundation_value '.subnet.ocid')"
  compute_ip="$(_foundation_value '.compute.public_ip')"
  availability_domain="$(_first_availability_domain "$compartment_ocid")"
  suffix="$(date -u '+%Y%m%d%H%M%S')"
  workdir="$(_tf_workdir fss_subdir_experiment)"
  artifacts_dir="${workdir}/tf_test_artifacts"

  ssh_key="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f ${ssh_key}" EXIT
  _materialize_ssh_key "$root_dir" "$ssh_key"
  chmod 600 "$ssh_key"

  # Phase A: provision
  cat >"${workdir}/main.tf" <<EOF
terraform {
  required_providers { oci = { source = "oracle/oci" } }
}

module "stack" {
  source = "${root_dir}/terraform/packages/fss_stack"

  compartment_ocid    = "${compartment_ocid}"
  subnet_ocid         = "${subnet_ocid}"
  availability_domain = "${availability_domain}"

  mount_targets = {
    primary = { display_name = "fss-exp-mt-${suffix}" }
  }

  filesystems = {
    shared = {
      display_name = "fss-exp-fs-${suffix}"
      exports = {
        vol1 = { mount_target_key = "primary", path = "/vol1", identity_squash = "NONE" }
        vol2 = { mount_target_key = "primary", path = "/vol2", identity_squash = "NONE" }
      }
    }
  }
}

output "nfs_mount_sources" { value = module.stack.nfs_mount_sources }
EOF

  (
    set -euo pipefail
    cd "$workdir"
    terraform init -input=false
    terraform apply -auto-approve -input=false 2>&1 | tee "${artifacts_dir}/apply.log"
    terraform output -json >"${artifacts_dir}/outputs.json"

    local src_vol1 src_vol2
    src_vol1="$(jq -r '.nfs_mount_sources.value["shared__vol1"] // empty' "${artifacts_dir}/outputs.json")"
    src_vol2="$(jq -r '.nfs_mount_sources.value["shared__vol2"] // empty' "${artifacts_dir}/outputs.json")"
    echo "INFO: vol1=${src_vol1}  vol2=${src_vol2}"
    [[ -n "$src_vol1" && -n "$src_vol2" ]] || { echo "FAIL: NFS sources missing" >&2; exit 1; }

    # Phase B+C+D: single SSH session — install, mount, write, check, unmount
    # All in one session to guarantee mounts are active for write and check.
    local sentinel="sentinel_${suffix}.txt"
    _ssh "$compute_ip" "$ssh_key" "bash -s" <<REMOTE 2>&1 | tee "${artifacts_dir}/experiment.log"
set -euo pipefail

echo "=== STEP 1: install nfs-utils ==="
sudo yum install -y nfs-utils 2>/dev/null || true

echo "=== STEP 2: clean up any leftover mounts ==="
sudo umount /mnt/vol1 2>/dev/null && echo "unmounted previous /mnt/vol1" || true
sudo umount /mnt/vol2 2>/dev/null && echo "unmounted previous /mnt/vol2" || true
sudo mkdir -p /mnt/vol1 /mnt/vol2

echo "=== STEP 3: mount vol1 => ${src_vol1} ==="
sudo mount -t nfs -o vers=3,noacl ${src_vol1} /mnt/vol1
echo "=== STEP 4: mount vol2 => ${src_vol2} ==="
sudo mount -t nfs -o vers=3,noacl ${src_vol2} /mnt/vol2

echo "=== STEP 5: verify active NFS mounts ==="
mount | grep nfs
echo "--- df output ---"
df -hT /mnt/vol1 /mnt/vol2

echo "=== STEP 6: list both mount points before write ==="
echo "-- /mnt/vol1 before write:" && sudo ls -la /mnt/vol1/
echo "-- /mnt/vol2 before write:" && sudo ls -la /mnt/vol2/

echo "=== STEP 7: write sentinel via /vol1 ==="
echo 'written_via_vol1' | sudo tee /mnt/vol1/${sentinel}
sync

echo "=== STEP 8: list both mount points after write ==="
echo "-- /mnt/vol1 after write:" && sudo ls -la /mnt/vol1/
echo "-- /mnt/vol2 after write (should be empty if SCOPED):" && sudo ls -la /mnt/vol2/

echo "=== STEP 9: check sentinel via /vol2 ==="
if sudo test -f /mnt/vol2/${sentinel}; then
  echo "FOUND_VIA_VOL2=YES"
else
  echo "FOUND_VIA_VOL2=NO"
fi

echo "=== STEP 10: unmount ==="
sudo umount /mnt/vol1 /mnt/vol2
echo "UNMOUNTED"
REMOTE

    local found
    found="$(grep 'FOUND_VIA_VOL2=' "${artifacts_dir}/experiment.log" | cut -d= -f2)"
    echo "INFO: sentinel visible via /vol2: ${found}"
    echo "$found" >"${artifacts_dir}/result.txt"

    # Phase E: assert and report
    echo ""
    if [[ "$found" == "YES" ]]; then
      echo "RESULT: SAME-ROOT"
      echo "  OCI FSS exposes the same filesystem root at both /vol1 and /vol2."
      echo "  The export path is an NFS alias — there is NO subdirectory scoping."
      echo "  1-MT/1-FS/N-exports topology shares data across all export paths."
      echo "PASS: IT-PBI035"
    else
      echo "RESULT: SCOPED"
      echo "  OCI FSS scopes each export to a distinct subtree."
      echo "  /vol1 and /vol2 expose independent data views."
      echo "  1-MT/1-FS/N-exports topology CAN be used for independent path sets."
      echo "PASS: IT-PBI035"
    fi
  ) || ec=$?

  if [[ "${SKIP_TEARDOWN:-false}" != "true" ]]; then
    if [[ -f "${workdir}/terraform.tfstate" ]]; then
      (cd "$workdir" && terraform destroy -auto-approve -input=false \
        2>&1 | tee "${artifacts_dir}/destroy.log") || true
    fi
  fi

  return "$ec"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_IT_export_subdir_scoping
fi
