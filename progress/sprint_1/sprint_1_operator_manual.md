# Sprint 1 — Operator Manual (Foundation Test Client)

This manual describes how to provision the Sprint 1 foundation (OCI compartment path, Vault/KMS/secret, network, compute), where **sprint-level state** lives (**Terraform vs oci_scaffold**), how to **SSH** (including **`tools/go_remote.sh`**), and how to tear down.

## Prerequisites

- OCI CLI configured and authenticated (`oci`).
- Tools installed: `jq`, `ssh`, `ssh-keygen`.
- Permissions to create resources under compartment path **`/oci_tf_fss`** (or your `COMPARTMENT_PATH`).

## State directories (mandatory policy)

Per **`RUP_patch.md` § P7**, sprint tests keep **two different kinds of state under `progress/sprint_1/`** — do not mix them in one folder:

| Kind | Directory | Contents |
|------|-----------|----------|
| **Terraform** | **`progress/sprint_1/tf_state/<test_id>/`** | `.terraform/`, `terraform.tfstate`, module dirs for Terraform integration tests |
| **oci_scaffold (foundation)** | **`progress/sprint_1/scaffold/<NAME_PREFIX>/`** | **`state-{NAME_PREFIX}.json`**, **`state-{NAME_PREFIX}-key.pub`**; private key **not** kept on disk when **`FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT=true`** (default) — only in Vault |

- **`WORKDIR`** for **`sprint1_foundation_infra_setup`** / **`teardown.sh`** is the **scaffold** directory above (your shell’s cwd when running oci_scaffold).
- End of **`tools/infra_setup.sh`** prints **`STATE_FILE`**, the **public** key path, Vault secret name for the private key, and reminds you that Terraform belongs under **`tf_state/`** separately.

Both trees are gitignored (`progress/**/tf_state/`, `progress/**/scaffold/`). Do not commit private keys.

## Shared provisioning script

The **`ensure-*`** sequence (compartment → Vault → KMS key → optional Vault secret for the SSH private key → VCN/subnet → compute) is implemented once in **`tools/infra_setup.sh`** as **`sprint1_foundation_infra_setup`**. New keypairs use **`ssh-keygen -m PEM -t rsa -b 4096`**. The SSH **public** key on disk is **`state-{NAME_PREFIX}-key.pub`**. By default (**`FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT=true`**) the **private** key is uploaded with **`ensure-secret.sh`** and **removed** from the scaffold directory; SSH clients must **retrieve the private key from Vault** (see below). Set **`FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT=false`** to keep **`state-{NAME_PREFIX}-key`** locally (**`cycle-compute`** style).

Environment variables:

- **`SPRINT1_NAME_PREFIX`** — optional; default **`infra`**. This is the only variable the Sprint 1 IT uses for the stack prefix (workdir **`progress/sprint_1/scaffold/<prefix>/`**). A generic **`NAME_PREFIX`** in the shell is **ignored** so CI/agents do not accidentally pick up another job’s value. To use **`NAME_PREFIX`** from the environment: set **`SPRINT1_USE_ENV_NAME_PREFIX=true`**, or set **`SPRINT1_NAME_PREFIX`** explicitly.
- **`COMPARTMENT_PATH`** — default `/oci_tf_fss`
- **`FOUNDATION_SSH_SECRET_NAME`** — optional; default `${NAME_PREFIX}-foundation-ssh-private-key`
- **`FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT`** — default **`true`**. Upload private key to Vault then **delete** **`state-{NAME_PREFIX}-key`** from the scaffold dir (only **`.pub`** remains). **`secret_value`** is cleared from **`state-*.json`** after **`ensure-secret`**. Set **`false`** to keep **`state-{NAME_PREFIX}-key`** on disk and skip Vault upload (local-only private key).
- **`FOUNDATION_IMPORT_SSH_PRIVATE_KEY_FILE`** — absolute path to an existing private key file (**same keypair** as Vault / instance). Skips **`secret-bundle`** fetch/decode; does **not** generate a new key.
- **`ROTATE_SSH_KEY`** — **`true`** removes local **`state-*-key`** / **`.pub`**, skips bundle fetch, generates a **new** RSA PEM keypair, and **`ensure-secret`** updates the Vault secret. Ignores **`FOUNDATION_IMPORT_*`** for that run.
- **`SPRINT1_SKIP_COMPUTE_SECRET_MISMATCH_CHECK`** — internal (e.g. destroy rehydrate flows)
- **`SPRINT1_LENIENT_VAULT_PEM`** — emergency only: if Vault decode fails, generates a **temporary** RSA PEM keypair for **`ensure-compute`** metadata; does **not** fix Vault and may not match an existing instance’s **`authorized_keys`**.
- **`SPRINT1_SKIP_SSH_WAIT`** — **`true`** skips the post-compute **`ssh opc@public_ip`** readiness loop (**default** waits up to **`SPRINT1_SSH_WAIT_TIMEOUT_SEC`**, default **600** seconds).

If a Vault secret with **`FOUNDATION_SSH_SECRET_NAME`** already exists, **`sprint1__raw_key_from_secret_bundle`** decodes the bundle (**`base64 -d`** of API **`content`**), validates with **`ssh-keygen -y`**, writes **`state-{NAME_PREFIX}-key.pub`**, then **discards** the private key bytes from disk when **`FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT=true`**. **`ensure-compute.sh`** uses only the **`.pub`** file. The secret **must** match the instance; if decode fails, use **`FOUNDATION_IMPORT_SSH_PRIVATE_KEY_FILE`**, **`oci vault secret update-base64`**, **`ROTATE_SSH_KEY=true`**, or a new **`NAME_PREFIX`** after aligning compute.

## Provision foundation and keep resources for debugging

From the **repository root**, you can provision the same stack **without prompts** by running **`./tools/infra_setup.sh`**. It uses Sprint 1 defaults: workdir **`progress/sprint_1/scaffold/${SPRINT1_NAME_PREFIX:-infra}`**, **`COMPARTMENT_PATH=/oci_tf_fss`**, and **`OCI_REGION`** from the tenancy home region when unset. Override **`WORKDIR`**, **`SPRINT1_NAME_PREFIX`**, **`COMPARTMENT_PATH`**, or **`OCI_REGION`** if needed.

To provision via the integration test (optional **`SKIP_TEARDOWN=true`** for debugging):

From the **repository root** (`ROOT`):

```bash
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

export COMPARTMENT_PATH=/oci_tf_fss
export SPRINT1_NAME_PREFIX=infra
# Optional: pin oci_scaffold workdir (otherwise the test defaults to progress/sprint_1/scaffold/${SPRINT1_NAME_PREFIX})
export WORKDIR="${ROOT}/progress/sprint_1/scaffold/${SPRINT1_NAME_PREFIX}"

SKIP_TEARDOWN=true tests/run.sh --integration --new-only progress/sprint_1/new_tests.manifest
```

Expected output includes **`INFO: workdir=...`**, **`STATE_FILE`**, **`SSH public key file`**, and (when Vault-backed) a line that the **private key is only in Vault**.

## SSH to the instance

### Recommended: `tools/go_remote.sh`

From the **repository root**, open a shell on the foundation compute (uses **`state-{NAME_PREFIX}.json`** under **`progress/sprint_1/scaffold/<NAME_PREFIX>/`**). The script materializes the private key from Vault when **`.secret.ocid`** is set (same decode path as **`infra_setup.sh`**), otherwise uses **`state-{NAME_PREFIX}-key`** when **`FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT=false`**.

```bash
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
./tools/go_remote.sh
```

Run a one-shot remote command (arguments are passed to **`ssh`**):

```bash
./tools/go_remote.sh sudo cloud-init status
./tools/go_remote.sh hostname
```

Environment variables:

| Variable | Purpose |
|----------|---------|
| **`SPRINT1_NAME_PREFIX`** | Stack prefix (default **`infra`**); **`NAME_PREFIX`** is ignored unless **`SPRINT1_USE_ENV_NAME_PREFIX=true`**. |
| **`WORKDIR`** | oci_scaffold directory (default **`progress/sprint_1/scaffold/<SPRINT1_NAME_PREFIX>`**). |
| **`GO_REMOTE_USER`** | SSH login (default **`opc`**). |
| **`GO_REMOTE_HOST`** / **`GO_REMOTE_IP`** | Override target host or IP (default **`.compute.public_ip`** from state). |
| **`GO_REMOTE_IDENTITY`** | Path to a private key file; skips Vault bundle and local **`state-<prefix>-key`**. |
| **`GO_REMOTE_CONNECT_TIMEOUT`** | **`ssh`** **`ConnectTimeout`** in seconds (default **15**). |

### Manual: materialize key from Vault

If you prefer not to use **`go_remote.sh`**, materialize the **private** key from Vault (same bytes **`ensure-secret`** stored), then SSH:

```bash
ROOT="$(git rev-parse --show-toplevel)"
PREFIX="${SPRINT1_NAME_PREFIX:-infra}"
WORKDIR="${WORKDIR:-${ROOT}/progress/sprint_1/scaffold/${PREFIX}}"
STATE_FILE="${WORKDIR}/state-${PREFIX}.json"

SECRET_OCID="$(jq -r '.secret.ocid // empty' "$STATE_FILE")"
PUBLIC_IP="$(jq -r '.compute.public_ip' "$STATE_FILE")"
TMPKEY="$(mktemp)"
oci secrets secret-bundle get --secret-id "$SECRET_OCID" --output json \
  | jq -r '.data."secret-bundle-content".content' \
  | tr -d '\n\r\t ' | base64 -d >"$TMPKEY"
chmod 600 "$TMPKEY"
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no "opc@${PUBLIC_IP}"
rm -f "$TMPKEY"
```

If **`FOUNDATION_STORE_SSH_PRIVATE_KEY_IN_VAULT=false`**, use **`${WORKDIR}/state-${PREFIX}-key`** as **`-i`** instead of fetching the bundle.

## Basic verification (after SSH)

```bash
hostname
uptime
sudo cloud-init status
```

## Teardown / cleanup

**oci_scaffold** destroys resources in **reverse `creation_order`** using the **same state files** as provision. You must run teardown from the **scaffold** directory that holds **`state-${NAME_PREFIX}.json`** (not from a Terraform `tf_state` directory).

```bash
ROOT="$(git rev-parse --show-toplevel)"
export SPRINT1_NAME_PREFIX=infra
PREFIX="${SPRINT1_NAME_PREFIX:-infra}"
WORKDIR="${WORKDIR:-${ROOT}/progress/sprint_1/scaffold/${PREFIX}}"

cd "$WORKDIR"
export NAME_PREFIX="$PREFIX"
export PATH="${ROOT}/oci_scaffold/do:${ROOT}/oci_scaffold/resource:${PATH}"

bash "${ROOT}/oci_scaffold/do/teardown.sh"
```

Vault/key/secret teardown may **schedule** deletion (OCI retention); compute termination is synchronous when applicable.

Optional: **`FORCE_DELETE=true`** forces teardown helpers to act even when **`*.created`** is false (advanced; see **`oci_scaffold`** teardown scripts).

## Destroy and recreate (full cycle)

**`progress/sprint_1/cycle_foundation_destroy_and_recreate.sh`** uses a temporary scaffold workdir under **`progress/sprint_1/scaffold/`**, runs **`sprint1_foundation_infra_setup`** then teardown with **`FORCE_DELETE=true`**, then runs the Sprint 1 integration test again. Requires **`NAME_PREFIX`**:

```bash
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
NAME_PREFIX=<your_stack_prefix> COMPARTMENT_PATH=/oci_tf_fss \
  bash progress/sprint_1/cycle_foundation_destroy_and_recreate.sh
```

After teardown you may remove an abandoned **scaffold** or **tf_state** workdir under **`progress/sprint_1/`** if no longer needed (ensure no required state for audits before deleting).
