# Examples

Use these Terraform roots as executable documentation for the FSS stack package.

- `basic_fss/`: one mount target, one filesystem, one export, only `compartment_ocid` and `subnet_ocid` required.
- `multi_fss_with_logging/`: multiple mount targets, multiple filesystems, multiple exports, and mount target logging.

Run an example from its directory:

```bash
terraform init
terraform apply \
  -var="compartment_ocid=${COMPARTMENT_OCID}" \
  -var="subnet_ocid=${SUBNET_OCID}"
```
