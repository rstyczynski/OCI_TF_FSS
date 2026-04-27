# Sprint 2 — Operator Manual (FSS Filesystem Module)

This manual provides copy/paste commands to run the Sprint 2 integration test that applies the Terraform filesystem module in compartment `/oci_tf_fss`.

## Prerequisites

- Terraform installed (`terraform` on PATH).
- OCI credentials configured for Terraform provider (same environment you use for `terraform apply`).
- Tools installed: `jq`, `oci` CLI.
- Permissions to create resources in compartment path `/oci_tf_fss`.

## Run the Sprint 2 integration test (recommended)

Run from the repository root:

```bash
tests/run.sh --integration --new-only progress/sprint_2/new_tests.manifest
```

Expected output includes:

- `PASS: IT-1 (filesystem_ocid=...)`

## Optional: preserve state for inspection

```bash
SKIP_TEARDOWN=true tests/run.sh --integration --new-only progress/sprint_2/new_tests.manifest
```

The test prints `INFO: workdir=...` which contains the generated Terraform working directory and state.

## Teardown / cleanup

If you used `SKIP_TEARDOWN=true`, destroy manually:

```bash
WORKDIR="<copy from test output>"
cd "$WORKDIR"
terraform destroy -auto-approve
rm -rf "$WORKDIR"
```

