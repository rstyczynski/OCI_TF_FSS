# Sprint 19 — Operator Manual

## Validated behavior: OCI FSS export path scoping

OCI FSS exports do **not** scope clients to subtrees. When the same filesystem has two exports at different paths, both NFS clients see the **same filesystem root**.

Verified by Sprint 19 integration experiment — see `sprint_19_tests.md`.

## Using the multi_exports_one_fs example

Prerequisites: Terraform >= 1.5, OCI credentials configured, `compartment_ocid` and `subnet_ocid`.

```bash
cd terraform/packages/fss_stack/examples/multi_exports_one_fs
terraform init
terraform apply -var compartment_ocid=$COMPARTMENT_OCID -var subnet_ocid=$SUBNET_OCID
```

Expected outputs:

```
nfs_mount_sources = {
  "shared__vol1" = "<mt_ip>:/vol1"
  "shared__vol2" = "<mt_ip>:/vol2"
}
```

Both mount sources expose the same OCI filesystem. Writing data via `/vol1` is immediately visible via `/vol2`.

Teardown:

```bash
terraform destroy -var compartment_ocid=$COMPARTMENT_OCID -var subnet_ocid=$SUBNET_OCID
```

Evidence: `progress/sprint_19/operator_manual_validate_<TS>.log`
