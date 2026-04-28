# Sprint 3 - Operator Manual

## Purpose

Sprint 3 provides `terraform/modules/fss_sprint3`, a simplified OCI File Storage filesystem module. Callers provide explicit resource identity inputs instead of relying on availability-domain randomization, dynamic tag recognition, or derived `name_prefix` display names.

## Prerequisites

- Terraform is installed and available on `PATH`.
- OCI Terraform provider credentials are configured.
- The operator has permission to create and destroy FSS filesystems in the target compartment.
- For repository integration tests, Sprint 1 foundation state must be available so tests can resolve `/oci_tf_fss`.

## Use the Module

Create a Terraform root module that resolves or receives a compartment OCID and availability domain, then call the Sprint 3 module:

```hcl
module "fs" {
  source              = "./terraform/modules/fss_sprint3"
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "example-fss"

  defined_tags  = {}
  freeform_tags = {}
}
```

Provision with:

```bash
terraform init
terraform apply
```

The module returns:

- `filesystem_ocid`
- `filesystem_display_name`
- `availability_domain`

## Validate the Sprint Product

Run the Sprint 3 new-code integration gate:

```bash
tests/run.sh --integration --new-only progress/sprint_3/new_tests.manifest
```

Run the full integration regression gate:

```bash
tests/run.sh --integration
```

The validated Sprint 3 executions are recorded in:

- `progress/sprint_3/test_run_A3_integration_20260428_071724.log`
- `progress/sprint_3/test_run_B3_integration_20260428_071819.log`

## Teardown

For module roots created by operators, destroy the filesystem with:

```bash
terraform destroy
```

The Sprint 3 integration tests also run Terraform destroy during test cleanup.
