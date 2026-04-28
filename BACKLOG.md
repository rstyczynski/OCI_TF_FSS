# Backlog

### PBI-001. Terraform module for FSS filesystem

Create a Terraform module that provisions an OCI File Storage Service (FSS) filesystem suitable for reuse across environments. The module must expose the key outputs needed by downstream configuration and keep its surface area minimal. This item is complete when the module can be applied successfully in a target compartment.

Test: apply succeeds and outputs include the created filesystem identifier.

### PBI-002. Terraform module for FSS mount target

Create a Terraform module that provisions an OCI FSS mount target that can be attached to a subnet and used by clients to access a filesystem. The module must be reusable and expose outputs needed to connect it with a filesystem and export configuration. This item is complete when the mount target is created successfully and its key identifiers are available as outputs.

Test: apply succeeds and outputs include the created mount target identifier.

### PBI-003. Terraform module for FSS export

Create a Terraform module that provisions an OCI FSS export that connects a filesystem to a mount target and makes it accessible via an export path. The module must support configuring access such that clients in the intended network can mount it. This item is complete when an export exists and clients have the information needed to mount it.

Test: apply succeeds and outputs include the export identifier and export path.

### PBI-004. Network Path Analyzer test for FSS availability

Add a validation step that uses OCI Network Path Analyzer to verify network reachability between the intended client network and the FSS mount target. This provides early detection of network/security-list/NSG/route issues that would prevent mounting. This item is complete when the analysis can be executed and its result can be used to decide whether the environment is ready for FSS access. Use oci_scaffold NPA resource of Terraform is not available.

Test: a path analysis run completes and reports reachability (or a clear non-reachability reason) for the FSS mount target from the chosen source.

### PBI-005. Foundation infrastructure for system-level FSS tests

Provide a reusable foundation environment for system-level testing of the FSS modules using oci_scaffold. This ensures tests have a consistent network and compute baseline to validate end-to-end accessibility rather than only Terraform plan/apply success. This item is complete when the foundation can be created predictably and exposes the identifiers needed by system-level tests.

Test: foundation environment provisioning completes and outputs include the network and test client identifiers required to run FSS availability checks.

### PBI-006. Terraform architecture rules for agentic development

Establish a set of Terraform architecture rules that will be used as the standard for all further work in this repository when building modules and tests with agentic help. These rules must be added to the upstream RUPStrikesBack rules/skills so they can be applied consistently in future sprints. This item is complete when the rules exist in RUPStrikesBack and are usable as an explicit reference during design and implementation.

Test: RUPStrikesBack contains the Terraform rules/skill and a sprint design can reference them as the governing standard.

### PBI-007. FSS module - expose kms_key_id argument at mandatory variables

Extend the FSS filesystem module so callers can explicitly provide the OCI KMS key OCID used to encrypt the filesystem. Treat the key as a mandatory input for the sprint product variant so production-like deployments cannot silently fall back to provider defaults. This item is complete when the module validates the required key input and passes it to the OCI filesystem resource.

Test: Terraform plan/apply fails when `kms_key_id` is omitted and succeeds when a valid KMS key OCID is provided.

### PBI-008. FSS module - expose rest of all available arguments at with default values

Expose the remaining supported OCI FSS filesystem resource arguments through module variables while preserving sensible defaults. Mandatory inputs must stay clearly separated from optional inputs in `variables.tf`, and optional arguments must default to values that preserve the current behavior unless the caller overrides them. This item is complete when the module interface covers the provider resource arguments needed for full filesystem configuration without forcing callers to set low-value options.

As some of arguments - especially in inner block requires special techniques to make them optional - describe this in TF rules. Take TF rules from previous sprint and extend.

Test: Terraform validate succeeds, default apply behavior remains compatible with the previous sprint module, and an integration case proves at least one newly exposed optional argument is applied.

### PBI-009. Create higher level module that accepts map of arguments to support multiple FSS with all mount points and exports

Create a higher-level composition module that accepts a map of filesystem definitions and provisions the complete FSS topology for each entry: filesystem, mount target linkage, and export configuration. The module must support multiple independent filesystems and exports using stable map keys so Terraform plans are predictable when entries are added or removed. This item is complete when one root module can create more than one FSS setup from a single structured input map.

Test: integration apply creates at least two filesystem/export entries from a map input and outputs per-entry identifiers needed by operators.

### PBI-010. Mount FSS file system(s) on a compute instance

Automate mounting one or more provisioned FSS exports on the foundation compute instance. The implementation must install required NFS client packages when needed, create mount directories, apply mount options, and verify the mounted filesystem is usable from the client host. This item is complete when the test compute instance can mount the generated FSS export paths without manual shell steps.

Test: integration test connects to the compute instance, mounts the FSS export, verifies it appears in `mount`/`df`, and writes and reads a small test file.

### PBI-011. Perform administrator tasks for FSS mount(s)

Validate common administrator operations on mounted FSS exports, such as directory creation, ownership/permission changes, file creation/removal, remount behavior, and cleanup. The tasks should prove the mounted filesystem is operational for day-2 usage, not only reachable at the network layer. This item is complete when the admin workflow can be executed repeatably against the mounted FSS path and leaves the system clean.

Test: integration test performs the selected admin operations on the mounted export, verifies expected permissions and file state, then removes test artifacts.

### PBI-012. Perform FIO tests for FSS mount(s)

Add repeatable FIO performance smoke tests for mounted FSS exports. The tests should run a bounded workload suitable for CI/manual sprint validation, capture read/write throughput and latency output, and store the report under the sprint progress directory. This item is complete when an operator can compare FIO results across runs without rerunning ad hoc commands. Take FIO approach from [oci_bv4db_arch](https://github.com/rstyczynski/oci_bv4db_arch/tree/main/progress/sprint_22) incl. OCI Metrics [reporting script](https://github.com/rstyczynski/oci_bv4db_arch/blob/main/tests/integration/test_oci_metrics_report_html.sh).

Test: integration test runs FIO against the mounted FSS path, exits successfully, and saves a timestamped FIO report artifact.

### PBI-013. Pack sprint 5 terraform stack and lower level modules into v1 module

Package the Sprint 5 stack behavior and the supporting lower-level FSS modules into a stable v1 module set for operator use. The v1 packaging should expose the same proven capabilities through a coherent, versioned interface while preserving the tested Sprint 5 behavior as the baseline. This item is complete when operators can consume the v1 module set without depending on sprint-numbered module names.

Test: integration apply using the v1 module interface creates the same multi-filesystem, mount target, export, and KMS-backed behavior proven in Sprint 5.

### PBI-014. Prepare comprehensive user documentation for v1 modules

Create comprehensive but practical user documentation for the v1 modules in module README form. The documentation must explain required inputs, optional inputs, outputs, prerequisites, example usage, generated resources, and teardown expectations clearly enough for an operator to run the module without reading sprint implementation notes. This item is complete when the v1 module documentation is executable, reviewable, and aligned with the tested module behavior.

Test: documented examples validate successfully and at least one copy/paste example is executed or explicitly recorded as not run with a reason.

### PBI-015. FSS Stack module – per-filesystem parameter overrides

The stack module currently applies a single shared `compartment_ocid`,
`availability_domain`, `subnet_ocid`, and `kms_key_id` to every filesystem in
the map. Treat those four variables as defaults and allow each filesystem entry
to supply its own value for any of them. When a per-entry value is present it
takes precedence; when absent the shared default is used. Module outputs must
reflect the effective per-filesystem values rather than the shared defaults.

Test: `terraform validate` accepts a filesystem entry that overrides
`kms_key_id`; `terraform apply` provisions two filesystem entries where one
inherits the shared default and the other uses an explicit per-entry
`kms_key_id`, and the outputs reflect each entry's effective key.

### PBI-016. Add logging to mount targets

Enable OCI logging for FSS mount targets so operators can inspect access and operational events after provisioning. The stack should make logging configurable without forcing every consumer to enable it, and outputs or documentation should expose enough information to find the created log resources. This item is complete when a mount target can be provisioned with logging enabled and the generated logs are discoverable from the sprint artifacts or OCI logging service.

Test: integration apply enables logging for a mount target, verifies the log resource is active or discoverable, and records evidence that the mount target logging configuration is connected to the created infrastructure.

### PBI-017. Expose full mount target configuration surface

Extend the FSS mount target module or v1 mount target module so operators can configure the provider-supported mount target arguments that are currently hidden by the Sprint 4 interface. The implementation must preserve the existing minimal defaults while exposing optional arguments such as `idmap_type`, `requested_throughput`, `is_lock_override`, `security_attributes`, `kerberos`, `ldap_idmap`, `locks`, and operation `timeouts` where supported by the OCI provider. The stack module must be able to pass these settings through per filesystem entry without forcing callers to configure advanced options for simple deployments.

Test: `terraform validate` accepts a mount target configuration that sets at least one newly exposed scalar argument and one nested block; an integration apply provisions a mount target with one advanced option enabled and records the generated Terraform under the sprint progress directory for operator review.

### PBI-018. Expose full export configuration surface

Extend the FSS export module or v1 export module so it supports the full provider configuration surface, not only one fixed `export_options` entry. The module must accept a list of export option objects so operators can define multiple ordered client policies with different sources and access rules. It must also expose relevant optional provider arguments such as `is_idmap_groups_for_sys_auth`, `locks`, and operation `timeouts` while preserving the current simple single-CIDR behavior as a compatibility path where appropriate.

Test: `terraform validate` accepts multiple `export_options` entries with distinct `source` and `access` values; an integration apply provisions an export with at least two ordered client policies and verifies the generated Terraform keeps both policies visible for operator review.
