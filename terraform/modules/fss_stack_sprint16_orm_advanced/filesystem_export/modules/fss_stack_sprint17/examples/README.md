# Examples

Use these Terraform roots as executable documentation for the FSS stack package.

- `basic_fss/`: one mount target, one filesystem, one export, only `compartment_ocid` and `subnet_ocid` required.
- `mount_target_only/`: creates only mount target(s) (no filesystems/exports). Intended as a pre-step for later examples/tests that reference external mount targets.
- `multi_fss_with_logging/`: multiple mount targets, multiple filesystems, multiple exports, and mount target logging.
- `external_mount_target/`: validation-only example showing `mount_targets[*].external_ocid` and per-mount-target placement overrides.

Run an example from its directory:

```bash
terraform init
terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```

