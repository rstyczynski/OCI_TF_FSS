# Sprint 1 — Operator Manual (Foundation Test Client)

This manual provides copy/paste commands to provision the Sprint 1 foundation environment and connect to the test client via SSH.

## Prerequisites

- OCI CLI configured and authenticated (`oci`).
- Tools installed: `jq`, `ssh`, `ssh-keygen`.
- Permissions to create resources in compartment path `/oci_tf_fss`.

## Provision foundation and keep it for operator use

Run from the repository root:

```bash
SKIP_TEARDOWN=true COMPARTMENT_PATH=/oci_tf_fss NAME_PREFIX=fss_operator \
  tests/run.sh --integration --new-only progress/sprint_1/new_tests.manifest
```

Expected output includes:

- `INFO: workdir=...`
- `INFO: compute_public_ip=...`
- `INFO: ssh command: ssh -i <workdir>/state-<NAME_PREFIX>-key opc@<public-ip>`

## SSH to the instance

Copy/paste the SSH command printed by the provisioning run.

If you need to reconstruct it:

```bash
WORKDIR="<paste workdir printed by the test>"
PUBLIC_IP="<paste compute_public_ip printed by the test>"
ssh -i "${WORKDIR}/state-fss_operator-key" -o StrictHostKeyChecking=no "opc@${PUBLIC_IP}"
```

## Basic instance verification (after SSH)

```bash
hostname
uptime
sudo cloud-init status
```

## Teardown / cleanup

If you kept resources (`SKIP_TEARDOWN=true`), teardown must be executed manually from the same workdir:

```bash
WORKDIR="<paste workdir printed by the test>"
cd "$WORKDIR"

export NAME_PREFIX=fss_operator
export PATH="/Users/rstyczynski/projects/OCI_TF_FSS/oci_scaffold/do:/Users/rstyczynski/projects/OCI_TF_FSS/oci_scaffold/resource:$PATH"

bash "/Users/rstyczynski/projects/OCI_TF_FSS/oci_scaffold/do/teardown.sh"
```

After teardown you can remove the workdir (contains the generated SSH key):

```bash
rm -rf "$WORKDIR"
```

