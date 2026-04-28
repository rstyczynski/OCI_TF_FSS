# Sprint 8 - Design

Status: Accepted

## PBI-016. Add logging to mount targets

Status: Accepted

### Requirement

Enable optional OCI Logging for FSS mount targets in a new stack module version. Operators must be able to enable logging per mount target, discover the created log resources from outputs, and use OCI Logging CLI to inspect logs.

### Product location

Create a new stack module:

```text
terraform/modules/fss_sprint8_stack/
  versions.tf
  variables.tf
  main.tf
  outputs.tf
```

Base it on `terraform/modules/fss_sprint7_stack` and preserve the Sprint 7 interface. Do not modify the Sprint 7 stack as part of this sprint.

### OCI Logging Model

OCI CLI discovery for public logging reports:

- service id: `filestorage`
- service name: `File Storage`
- resource type: `mounttarget`
- category name: `nfslogs`
- category display name: `NFS Logs`

Terraform resources:

- `oci_logging_log_group`
- `oci_logging_log`

The service log source configuration uses:

```hcl
configuration {
  source {
    source_type = "OCISERVICE"
    service     = "filestorage"
    resource    = module.mount_target[each.key].mount_target_ocid
    category    = "nfslogs"
  }
}
```

### Variables

Retain the Sprint 7 shared and topology variables. Extend each `mount_targets` entry with an optional `logging` object:

```hcl
logging = optional(object({
  enabled            = optional(bool, false)
  log_group_id       = optional(string)
  log_group_name     = optional(string)
  log_display_name   = optional(string)
  retention_duration = optional(number, 30)
  freeform_tags      = optional(map(string), {})
  defined_tags       = optional(map(string), {})
}))
```

Behavior:

- When `logging` is omitted or `enabled = false`, no logging resources are created.
- When `logging.enabled = true` and `log_group_id` is set, create only the service log in that group.
- When `logging.enabled = true` and `log_group_id` is not set, create one log group for that mount target.
- Default log group name: `fss-${mount_target_key}-logs`.
- Default log display name: `fss-${mount_target_key}-nfs`.
- Default retention: 30 days.

### Outputs

Add logging details to the composite `mount_targets` output. Each mount target object includes a `logging` attribute:

- `null` when logging is not enabled for that mount target
- an object with log group, log, source, category, enabled flag, and retention when logging is enabled

Shape:

```hcl
{
  <mount_target_key> = {
    log_group_ocid     = string
    log_ocid           = string
    log_display_name   = string
    service            = "filestorage"
    resource           = mount_target_ocid
    category           = "nfslogs"
    is_enabled         = bool
    retention_duration = number
  }
}
```

Also expose atomic outputs:

- `mount_target_log_group_ocids`
- `mount_target_log_ocids`

### Operator Manual

Create `progress/sprint_8/sprint_8_operator_manual.md` with copy/paste snippets for:

- provisioning the stack with logging enabled for one mount target
- retrieving log IDs from Terraform outputs
- mounting and writing to the FSS export from foundation compute
- using `oci logging log get`
- using `oci logging-search search-logs`
- teardown

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — logging requires OCI service resources and CLI verification.
- **Regression:** none — Sprint 8 creates a new stack module and does not mutate prior stack modules.

#### Unit Test Targets

None. The behavior is Terraform resource composition and OCI integration.

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|----------|-----------------------------|------------------|--------------|
| Logging-enabled mount target | Sprint 1 foundation, Sprint 5 MEK, OCI Logging service | Terraform apply creates mount target, log group, and service log; OCI CLI can get the log; log search command records evidence | 5-10 min |

#### Smoke Test Candidates

None. Terraform validate is included inside the integration test.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Logging-enabled mount target is discoverable

- **Preconditions:** Sprint 1 foundation state exists, Sprint 5 MEK state exists, OCI CLI can manage Logging.
- **Steps:** Generate Terraform root under `progress/sprint_8/generated_tf/it1_logging_enabled/`; apply `fss_sprint8_stack` with one logging-enabled mount target and one filesystem/export; capture outputs; run `oci logging log get`; run `oci logging-search search-logs` after generating an NFS operation.
- **Expected Outcome:** Terraform outputs include a log group OCID and log OCID; OCI CLI returns the created log as active or available; search command output is saved for operator review.
- **Verification:** Test asserts non-empty log OCIDs and successful `oci logging log get`; log search JSON is written under test artifacts.
- **Target file:** `tests/integration/test_fss_sprint8_logging.sh`

### Traceability

| Backlog Item | Integration Tests |
|--------------|-------------------|
| PBI-016 | IT-1 |
