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

### PBI-019. Refactor stack filesystem variable

Mount target services one or more filesystems via one or more exports. Refactor `fss_stack` filesystems variable to reflect this, and remove optional arguments, that will be added in nex iterations. PBI-019 supersedes PBI-015.

Exemplary definition:

```hcl
variable "mount_targets" {
  description = "Map of mount targets keyed by stable operator names. Exports reference these keys via exports[*].mount_target_key."
  type = map(object({
    display_name   = optional(string)
    hostname_label = optional(string)
    nsg_ids        = optional(list(string))

    freeform_tags = optional(map(string), {})
    defined_tags  = optional(map(string), {})

  }))
  default = {}
}

variable "filesystems" {
  description = "Map of filesystem entries keyed by stable operator names. Each filesystem may have multiple exports; each export can target any mount target (by key)."
  type = map(object({
    display_name = string
    freeform_tags                 = optional(map(string), {})
    defined_tags                  = optional(map(string), {})

    exports = optional(map(object({
      mount_target_key = string
      path             = string

      source                         = optional(string, null)
      access                         = optional(string, "READ_WRITE")
      allowed_auth                   = optional(list(string), ["SYS"])
      identity_squash                = optional(string, "ROOT")
      anonymous_uid                  = optional(number, 65534)
      anonymous_gid                  = optional(number, 65534)
      is_anonymous_access_allowed    = optional(bool, false)
      require_privileged_source_port = optional(bool, false)
    })), {})
  }))

  default = {}
}
```

The stack must retain the `default_source_cidr` module-level variable so that exports with `source = null` inherit a meaningful CIDR rather than failing at plan time.

Test: `terraform validate` accepts a configuration with two `mount_targets` entries and two `filesystems` entries where one filesystem has exports pointing to different mount targets via `mount_target_key`; `terraform apply` provisions all resources, and outputs correctly associate each export with its referenced mount target; a second apply with one filesystem entry removed destroys only the targeted resources without affecting the remaining stack.

### PBI-020. Rebase v1 stack on latest Sprint 8 stack interface

Repeat the v1 packaging work for the latest approved stack interface from Sprint 8. Sprint 9 produced v1 module paths and documentation, but it used the older Sprint 5 stack shape. The corrected v1 stack must use the Sprint 8 interface with independent `mount_targets` and `filesystems` maps, nested filesystem exports that reference mount targets by key, and optional mount target logging surfaced through `mount_targets[*].logging`.

This item is complete when `terraform/modules/fss_v1_stack` accepts the Sprint 8 stack input shape, uses v1 lower-level modules internally, documents the current interface, and passes integration validation that proves nested exports and mount target logging work through the v1 path.

Test: integration apply using `fss_v1_stack` provisions two mount targets, two filesystems, three exports, one logging-enabled mount target, and verifies the current composite outputs including `mount_targets[*].logging` and `nfs_mount_sources`.

### PBI-021. Create v2 stack with optimized mandatory parameters

Create `terraform/modules/fss_v2_stack` from the latest v1 stack behavior and reduce the number of mandatory operator inputs while preserving deterministic behavior. The stack should derive the effective availability domain from the subnet when the subnet is AD-specific. If the subnet is regional and no explicit availability domain is provided, the stack should use the Sprint 2 randomization pattern from `terraform/modules/fss_sprint2/ad.tf`: build a stable sorted AD list and select one AD with `random_shuffle`.

`kms_key_id` should become optional. When it is omitted, the stack should pass no customer-managed key to the filesystem resource so OCI File Storage uses the Oracle-managed encryption key. `default_source_cidr` should also become optional and default to `0.0.0.0/0`. This is acceptable for this module because FSS exports are reachable only through private VCN networking, not directly from the public internet.

This item is complete when the v2 stack can be consumed with only compartment, subnet, mount target, and filesystem/export intent supplied by the operator; the effective AD, encryption key mode, and default export source are visible in outputs or documentation; and explicit overrides for AD, KMS key, and export source continue to work.

Test: `terraform validate` accepts a minimal v2 stack configuration without `availability_domain`, `kms_key_id`, or `default_source_cidr`; integration apply proves filesystem creation succeeds with OCI-managed encryption, exports inherit `0.0.0.0/0` when no source is set, and regional-subnet AD selection follows the Sprint 2 randomization pattern.

### PBI-022. Complete v2 stack package and README

Package the v2 stack created by PBI-021 as the operator-facing successor to the v1 stack. The v2 package should preserve the latest approved stack capabilities from v1, including independent `mount_targets` and `filesystems` maps, nested filesystem exports that reference mount targets by key, optional mount target logging surfaced through `mount_targets[*].logging`, and the optimized mandatory parameter behavior introduced by PBI-021.

This item is complete when `terraform/modules/fss_v2_stack` has a complete README, executable examples, clear mandatory and optional variable sections, output documentation, migration notes from v1, and integration evidence that proves the documented examples match the implemented interface.

Test: integration validation uses the README-shaped v2 examples under the sprint generated Terraform directory, verifies the minimal v2 configuration without `availability_domain`, `kms_key_id`, or `default_source_cidr`, and verifies a full v2 configuration with two mount targets, two filesystems, three exports, and one logging-enabled mount target.

### PBI-023. Package current FSS stack package for OCI Resource Manager

Add Resource Manager packaging for the current FSS stack package at `terraform/modules/fss_stack_sprint12/` so operators can deploy it directly from the OCI Console via Resource Manager without writing Terraform by hand. The package must include `schema.yaml`, declare UI metadata for all mandatory variables (`compartment_ocid`, `subnet_ocid`), group and label optional variables clearly, and handle the complex map variables (`mount_targets`, `filesystems`) in a way Resource Manager can accept — either by exposing them as freeform JSON string inputs or by providing a simplified fixed-topology variant alongside the full map-based interface.

The schema must be validated against the OCI Resource Manager schema specification and must produce a deployable stack when uploaded to OCI Resource Manager or referenced via a Git-based configuration source. The schema must also declare at least the key outputs (`nfs_mount_sources`, `mount_targets`) so operators can read mount information directly from the Resource Manager job page.

Test: `oci resource-manager stack create` (or equivalent Resource Manager CLI/console upload) succeeds with the packaged stack zip; the Resource Manager job completes without schema validation errors; outputs including `nfs_mount_sources` are visible in the job result; a destroy job cleans up all created resources.

### PBI-024. Repackage FSS stack with examples and modules layout

Repackage the current stack baseline from `terraform/modules/fss_v2_stack` into a clearer repository layout for operators. The sprint-produced stack package should live at `terraform/modules/fss_stack_sprint12/`, with usable example Terraform roots under its `examples/` directory and reusable lower-level Terraform modules under its `modules/` directory. The package name keeps the sprint traceability while making the product root obvious.

This item is complete when README documentation points operators to the package examples first, the example code can be used directly with minimal variables, lower-level modules are grouped under the package module directory, and the packaged stack behavior remains equivalent to the current `fss_v2_stack` baseline.

Test: `terraform validate` passes for every example under `terraform/modules/fss_stack_sprint12/examples/`; integration apply of the basic example provisions an FSS stack using the repackaged module path and confirms the same key outputs as the `fss_v2_stack` baseline.

### PBI-025. Verify identity_squash = "NONE" behavior at NFS level (promoted from BUG-1 Sprint 12)

The `multi_fss_with_logging` example sets `identity_squash = "NONE"` on the `data/primary` export and `identity_squash = "ROOT"` (default) on `data/secondary`. Quality gates in Sprint 12 only validated the example schema and applied the `basic_fss` example; the multi-filesystem example was never applied and its NFS squash behavior was never verified at the mount level.

This item is complete when an integration test applies `multi_fss_with_logging`, mounts both the NONE-squash and ROOT-squash exports on the foundation compute instance, verifies that `sudo mkdir` succeeds on the NONE-squash mount, and verifies that root operations are squashed on the ROOT-squash mount.

Test: integration apply of `multi_fss_with_logging` creates 2 mount targets, 2 filesystems, and 3 exports; foundation compute mounts `data__primary` (NONE squash) and confirms `sudo mkdir` succeeds; foundation compute mounts `data__secondary` (ROOT squash) and confirms root write is denied or mapped to anonymous UID; teardown removes all created resources.

### PBI-026. Add Resource Manager mount target stack

Create a focused OCI Resource Manager package that lets an operator create one FSS mount target from the console without editing Terraform maps. The stack should expose friendly placement, network, logging, and tag controls, and should output the mount target OCID, export set OCID, mount address, IP address, and logging details.

This item is complete when Resource Manager can upload and run the mount target stack independently, and operators can copy the resulting mount target details into later FSS workflows.

Test: Resource Manager stack upload validates the schema; integration apply creates one mount target, outputs expose mount target details and export set OCID, and a destroy job removes the created resource.

### PBI-027. Add legacy PV report to FSS stack variables converter

Create a conversion tool that reads legacy Kubernetes/NFS PV report files and generates Terraform variable files compatible with the current FSS stack package.

Template files used by real reports are at `etc/pv-template1-details`, `etc/pv-template2-details`, and `etc/pv-template3-details`. These templates cover a multi-PV single-server case, a single static PV case, and a larger multi-PV case. The converter must parse node sections and PV blocks from reports containing node tables, repeated `##########` separators, and PV fields such as `PV Name`, `path`, `server`, and `storageclass`. It must generate an `.auto.tfvars` file with `mount_targets` and `filesystems` maps matching `terraform/modules/fss_stack_sprint12` input shape. Legacy source metadata such as NFS server, PV name, storage class, and original export path should be preserved as freeform tags where useful.

The converter should group PVs by legacy NFS server so each distinct server becomes one generated mount target key, and each PV becomes one filesystem with one `primary` export. The legacy `path` value is the generated export path, preserving the old NFS mount contract. Generated keys must be Terraform-safe and stable. The tool should validate required fields, report malformed blocks clearly, and avoid silently dropping PVs. The tool goes to `./tools`. The project README must include a chapter explaining how to use the tool with example usage of the template files.

This item is complete when operators can run one command against a report file and receive a reviewed `.auto.tfvars` file ready to use with the FSS stack module.

Test: unit tests cover all three templates, parsing of node sections, multiple PV blocks, multiple legacy servers, malformed or incomplete PV blocks, key sanitization, and generated HCL formatting. Integration testing applies the produced `.auto.tfvars` with the current `terraform/modules/fss_stack_sprint12` stack, verifies the created mount target, filesystem, export, and NFS mount source outputs, and destroys the created resources.

### PBI-028. Add Resource Manager filesystem stack with chained exports

Create a focused OCI Resource Manager package that lets an operator create one FSS filesystem and one or more exports against an existing mount target. The stack should use a mount target dropdown where Resource Manager supports it, make the first export mandatory, and expose additional export groups through chained "add another export" checkboxes so the UI feels dynamic without requiring raw JSON or map editing.

This item is complete when the filesystem stack can create one filesystem with a bounded set of enabled exports, validates enabled export data, outputs the filesystem OCID, export OCIDs, export paths, and ready-to-use NFS mount sources, and destroys cleanly.

Test: Resource Manager stack upload validates the schema; integration apply selects an existing mount target, creates one filesystem with at least two enabled exports, outputs all NFS mount sources, and a destroy job removes the created filesystem and exports.

### PBI-029. Add Resource Manager export-only stack

Create a focused OCI Resource Manager package that lets an operator add exports later to an existing filesystem and existing mount target. This is a future workflow for day-2 expansion after the filesystem has already been created; it should avoid raw map editing and should use existing-resource selectors where Resource Manager supports them.

This item is complete when operators can run a dedicated export-only stack to add an export to an existing filesystem and mount target, see the resulting export OCID and NFS mount source, and destroy only that additional export without affecting the filesystem or mount target.

Test: Resource Manager stack upload validates the schema; integration apply creates an additional export for existing FSS resources, verifies the NFS mount source output, and a destroy job removes only the created export.

### PBI-030. Replace sprint-15-specific intermediate modules with fss_stack_sprint12 (BUG-11 implementation)

Sprint 15 ORM stacks currently embed custom intermediate modules (`fss_stack_sprint15_mount_target`, `fss_stack_sprint15_filesystem_export`). BUG-11 (sprint_15_bugs.md) identifies this as a critical defect: the intermediate module layer must be `fss_stack_sprint12` — the existing, externally-managed, unmodifiable canonical stack module — embedded as-is, exactly as Sprint 13 does.

This item implements the BUG-11 fix:

- Replace `mount_target/modules/fss_stack_sprint15_mount_target/` with a verbatim copy of `fss_stack_sprint12/`.
- Replace `filesystem_export/modules/fss_stack_sprint15_filesystem_export/` with a verbatim copy of `fss_stack_sprint12/`.
- Update both ORM roots to call `fss_stack_sprint12` or its sub-modules appropriately.

This item is complete when both stack zips contain `modules/fss_stack_sprint12/` (byte-for-byte identical to `terraform/modules/fss_stack_sprint12/`), both stacks pass `terraform validate`, and all quality gates pass.

Test: `terraform validate` on both stack roots; A1 smoke and A3 integration gates pass; embedded `fss_stack_sprint12/` content matches the canonical source.

### PBI-031. fss_stack_sprint12 - support externally managed mount targets in exports

Extend `terraform/modules/fss_stack_sprint12` so filesystem exports can target an externally managed mount target, not only mount targets created by the stack. The export field `mount_target_key` must accept either (a) a key that resolves into the `mount_targets` map (current behavior) or (b) a literal mount target OCID (`ocid1.fsmounttarget...`). This must support multiple external mount targets within the same apply (different exports may point to different mount target OCIDs).

This item is complete when the stack can create filesystems and exports against a provided mount target OCID without requiring any `mount_targets` entries, while preserving full backward compatibility for existing configurations that use `mount_targets` keys.

Test: `terraform validate` passes for all existing Sprint 12 examples unchanged, and a new example validates where an export uses a literal mount target OCID and `mount_targets = {}`.

### PBI-032. fss stack - allow per-mount-target placement overrides (subnet / availability domain)

The stack currently assumes a single shared `subnet_ocid` and a single effective availability domain for all mount targets (and for filesystems). This is too restrictive when operators need to reference or create mount targets in different subnets (and therefore potentially different availability domains) within one stack configuration, especially when mixing stack-managed and externally managed mount targets.

Extend the stack interface so each `mount_targets[*]` entry can optionally override placement:

- `subnet_ocid` (optional): when set, this mount target uses the provided subnet instead of the stack default `var.subnet_ocid`
- `availability_domain` (optional): when set, this mount target uses the provided AD instead of the stack’s effective AD

When omitted, each override defaults to the current stack behavior (use the shared default), preserving backward compatibility. The stack must validate that externally managed mount targets referenced by `external_ocid` are actually in the effective subnet/AD for that entry (using the overrides when present).

Test: `terraform validate` passes for existing examples unchanged, and a new example validates with two mount target entries that set different `subnet_ocid` values (and corresponding availability domain overrides when required).
