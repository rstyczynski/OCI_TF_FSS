# Sprint 1 — Test Execution Results

## Summary (latest)

| Gate | Result | Date (UTC) | Notes |
|------|--------|------------|--------|
| A3 Integration (new-only manifest) | **FAIL** | 2026-04-27 | Vault secret bytes are not a valid SSH private key after all decode paths; see log and **Remediation** below. |

Earlier recorded runs (same gate, different environments):

| Gate | Result | Retries | Pass Rate |
|------|--------|---------|-----------|
| A3 Integration | PASS | 1 | 100% |
| B3 Integration | PASS | 0 | 100% |

## Artifacts

Manual SSH to the provisioned foundation instance (Vault or local key via scaffold state): **`tools/go_remote.sh`** — see **`progress/sprint_1/sprint_1_operator_manual.md`**.

| Gate | Log File |
|------|----------|
| A3 Integration (latest) | `progress/sprint_1/test_run_A3_integration_20260427_215514.log` |
| A3 Integration (prior PASS evidence) | `progress/sprint_1/test_run_A3_integration_20260427_143430.log` |
| B3 Integration | `progress/sprint_1/test_run_B3_integration_20260427_143814.log` |

## Failures

### IT-1 — Vault secret not a usable SSH private key (2026-04-27)

- **Test:** `integration:test_foundation.sh:test_IT1_provision_foundation_baseline`
- **Symptom:** `FAIL: Vault secret … is not valid private key material after one base64 decode` (or earlier variants mentioning decode attempts).
- **Cause:** The OCI Vault secret **`${NAME_PREFIX}-foundation-ssh-private-key`** does not round-trip to bytes **`ssh-keygen -y`** accepts (corrupt upload, truncated payload, or legacy OpenSSH-format secret vs current **RSA PEM** uploads). Not an oci_scaffold compute wiring bug.
- **Remediation (pick one):**
  1. **`ROTATE_SSH_KEY=true ./tools/infra_setup.sh`** (from repo root / correct **`WORKDIR`**) — new **RSA PEM** keypair and **`ensure-secret`** updates Vault; **recreate or re-key compute** so **`authorized_keys`** matches the new pubkey if an instance already existed.
  2. **`FOUNDATION_IMPORT_SSH_PRIVATE_KEY_FILE=/path/to/private-key`** — materialize from a known-good key file on disk (same pattern as **`oci_bv4db_arch`** manual recovery).
  3. **`oci vault secret update-base64`** with **`base64`** of the correct full private key file (**`ensure-secret`** stores **`base64(file_bytes)`**).
  4. Use a new **`SPRINT1_NAME_PREFIX`** so a **new** secret name is used and bootstrap creates a new keypair under that prefix.
  5. **`SPRINT1_LENIENT_VAULT_PEM=true`** — emergency/teardown-style only; may desync instance **`authorized_keys`** unless compute is recreated.

### Retry 1 — A3 Integration (historical)

- **Test:** `integration:test_foundation.sh:test_IT1_provision_foundation_baseline`
- **Error:** Missing `OCI_REGION` state/env and cleanup trap strictness caused a non-actionable failure.
- **Fix:** Set and persist `OCI_REGION` for `oci_scaffold` ensure scripts; harden cleanup trap.
- **Result:** Pass on re-run.
