# Sprint 2 — Operator Manual (FSS Filesystem Module)

This manual provides copy/paste commands to run the Sprint 2 integration test that applies the Terraform filesystem module in compartment `/oci_tf_fss`.

## Prerequisites

- Terraform installed (`terraform` on PATH).
- OCI credentials configured for Terraform provider (same environment you use for `terraform apply`).
- Tools installed: `jq`, `oci` CLI.
- Permissions to create resources in compartment path `/oci_tf_fss`.

### Foundation stack (recommended)

Sprint 2 integration tests resolve the **compartment OCID** from **`tools/infra_setup.sh`** scaffold state when present:

- Default state file: **`progress/sprint_1/scaffold/<SPRINT1_NAME_PREFIX>/state-<SPRINT1_NAME_PREFIX>.json`** (default prefix **`infra`**), reading **`.compartment.ocid`** — the same compartment **`ensure-compartment`** created for the foundation stack.
- Run **`./tools/infra_setup.sh`** from the repo root once (or whenever you need a fresh foundation), then run the Sprint 2 tests.

Overrides:

| Variable | Purpose |
|----------|---------|
| **`COMPARTMENT_OCID`** | Use this OCID directly (skips scaffold state). |
| **`WORKDIR`** | oci_scaffold directory if not the default **`progress/sprint_1/scaffold/<SPRINT1_NAME_PREFIX>`** (must contain **`state-<prefix>.json`**). |
| **`SPRINT1_NAME_PREFIX`** | Stack prefix (default **`infra`**); **`NAME_PREFIX`** is ignored unless **`SPRINT1_USE_ENV_NAME_PREFIX=true`**. |
| **`SPRINT1_FOUNDATION_STATE_FILE`** | Explicit path to **`state-*.json`** from **`infra_setup`**. |
| **`TF_REQUIRE_FOUNDATION_SCAFFOLD_STATE=true`** | Fail if compartment cannot be read from foundation state (no fallback to **`oci`** path lookup). |

## Run the Sprint 2 integration test (recommended)

Run from the repository root:

```bash
tests/run.sh --integration --new-only progress/sprint_2/new_tests.manifest
```

## Run only one test category (optional)

To run only specific categories (faster feedback), use `--group`:

```bash
tests/run.sh --integration --group error_path
tests/run.sh --integration --group defaults_path
tests/run.sh --integration --group tag_path   # IT-5 Oracle tag merge only (includes ~10s delay)
tests/run.sh --integration --group happy_path
```

Expected output includes:

- `PASS: IT-1 (filesystem_ocid=...)`

## Optional: preserve state for inspection

```bash
SKIP_TEARDOWN=true tests/run.sh --integration --new-only progress/sprint_2/new_tests.manifest
```

The test prints `INFO: workdir=...` which contains the generated Terraform working directory and state.

## Teardown / cleanup

By default, **each** integration test case runs **`terraform destroy`** in its Terraform working directory when the test body completes, so filesystems and other resources created during the test are removed from OCI. Logs are written to **`tf_test_artifacts/destroy.stdout.log`** under that workdir. Unless you use ephemeral temp dirs, the **`progress/sprint_2/tf_state/<test_id>/`** folder may remain on disk for faster re-runs.

If you used `SKIP_TEARDOWN=true`, destroy manually:

```bash
WORKDIR="<copy from test output>"
cd "$WORKDIR"
terraform destroy -auto-approve
rm -rf "$WORKDIR"
```

