# Sprint 17 - Documentation

## Summary

Sprint 17 extends the FSS stack module with two capabilities: support for externally managed mount targets (referenced by OCID rather than created by the stack), and per-mount-target placement overrides (subnet and availability domain). The sprint product lives in `terraform/modules/fss_stack_sprint17/` and is fully backward-compatible with all Sprint 12 examples.

## What was delivered

**New module:** `terraform/modules/fss_stack_sprint17/`

New optional attributes on `mount_targets` entries:

| Attribute | Description |
|---|---|
| `external_ocid` | When set, the stack does not create this mount target; it resolves the existing mount target via data sources and uses its export set for exports |
| `subnet_ocid` | Per-entry subnet override (defaults to stack-level `var.subnet_ocid`) |
| `availability_domain` | Per-entry AD override (defaults to stack-level effective AD) |

All existing attributes (`display_name`, `hostname_label`, `nsg_ids`, tags, logging) remain valid for managed mount targets. External mount targets do not have logging managed by this stack.

**Validations added:**

- `external_ocid` format: must match `^ocid1\.fsmounttarget\..+` when provided
- External mount target must be in the effective subnet and availability domain for its entry

**New example:** `terraform/modules/fss_stack_sprint17/examples/external_mount_target_validate_only/` — validation-only example demonstrating an export that references an external mount target OCID.

**BUG-12 fix:** updated the module to reuse an existing OCI Logging log group by display name instead of attempting to create a duplicate (409-Conflict prevention). The same fix was mirrored into the Sprint 16 vendored copies.

**Terraform rules:** `progress/sprint_17/sprint_17_tf_rules.md` — extended guidance for OCI resources whose display names must be unique within a compartment scope.

## Key interface extension (usage example)

```hcl
module "fss" {
  source           = "./terraform/modules/fss_stack_sprint17"
  compartment_ocid = var.compartment_ocid
  subnet_ocid      = var.subnet_ocid

  mount_targets = {
    # Managed mount target (created by the stack)
    internal = {
      display_name = "fss-mt-internal"
    }

    # Externally managed mount target (referenced by OCID, not created)
    external = {
      external_ocid = "ocid1.fsmounttarget.oc1.eu-frankfurt-1.aaa..."
    }
  }

  filesystems = {
    data = {
      display_name = "fss-data"
      exports = {
        via_internal = {
          mount_target_key = "internal"
          path             = "/data"
        }
        via_external = {
          mount_target_key = "external"
          path             = "/data"
        }
      }
    }
  }
}
```

## Quality gates

| Gate | Result | Evidence |
|---|---|---|
| A1 Smoke | PASS | `progress/sprint_17/test_run_A1_smoke_20260430_151303.log` |
| A3 Integration | PASS | `progress/sprint_17/test_run_A3_integration_20260430_152421.log` |
| D1 Operator Manual | PASS | `progress/sprint_17/operator_manual_validate_20260430_151136.log` |
| BUG-12 Validation | PASS | `progress/sprint_17/bug12_validate_20260502_195501.log` |
| BUG-12 A1 Smoke | PASS | `progress/sprint_17/test_run_A1_smoke_bug12_20260502_200524.log` |
| BUG-12 A3 Integration | PASS | `progress/sprint_17/test_run_A3_integration_bug12_20260502_200530.log` |

## Operator manual

Full copy/paste operator manual: `progress/sprint_17/sprint_17_operator_manual.md`

## Sprint documents

- Setup: `progress/sprint_17/sprint_17_setup.md`
- Design: `progress/sprint_17/sprint_17_design.md`
- Implementation: `progress/sprint_17/sprint_17_implementation.md`
- Tests: `progress/sprint_17/sprint_17_tests.md`
- Bugs: `progress/sprint_17/sprint_17_bugs.md`
- Terraform rules: `progress/sprint_17/sprint_17_tf_rules.md`
- Operator manual: `progress/sprint_17/sprint_17_operator_manual.md`

## Backlog traceability

- PBI-031: `progress/backlog/PBI-031/`
- PBI-032: `progress/backlog/PBI-032/`
