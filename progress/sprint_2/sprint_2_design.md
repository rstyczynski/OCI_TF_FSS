# Sprint 2 - Design

## PBI-001. Terraform module for FSS filesystem

Status: Proposed

### Requirement Summary

Provide a Terraform module that provisions an OCI File Storage Service (FSS) filesystem with a minimal, reusable interface and outputs needed by downstream modules (mount target, export).

### Feasibility Analysis

**API Availability:**

- OCI Terraform provider supports FSS filesystem resources; creation is feasible given correct compartment OCID and availability domain selection if needed.

**Technical Constraints:**

- All resources must be created in `/oci_tf_fss` scope per `PLAN.md`.
- Sprint test configuration requires integration gates; tests must be runnable and produce log artifacts.

**Risk Assessment:**

- Provider authentication/region selection must be consistent with integration tests and operator environment.
- AD selection can be a source of drift; design should minimize required parameters.

### Design Overview

**Architecture:**

- Introduce a Terraform module that creates exactly one filesystem.
- Module takes compartment OCID (resolved from `/oci_tf_fss`) and a display name/prefix.
- Module outputs filesystem OCID for later sprints.

**Key Components:**

1. `terraform/modules/fss_filesystem/` — module code
2. A minimal example root module for integration testing (kept small; used by tests)

### Technical Specification

**Terraform module design (`terraform/modules/fss_filesystem/`)**

- **Resources:**
  - One OCI FSS filesystem resource.
- **Naming:**
  - Filesystem display name derived from a provided name input (no hidden randomness).
- **Outputs:**
  - Expose the filesystem OCID for downstream modules (mount target, export).

**Inputs (module) — required arguments:**

- `compartment_ocid` — OCI compartment OCID for `/oci_tf_fss`.

**Inputs (module) — optional arguments (with defaults):**

- `display_name` — filesystem display name (default: derived from `name_prefix`).
- `name_prefix` — name prefix used when `display_name` is not set (default: `fss`).
- `availability_domain` — AD name (optional; if omitted, module selects the first AD in the region).
- `freeform_tags` — map (default: `{}`).
- `defined_tags` — map (default: `{}`).

**Availability Domain resolution (when not provided):**

- Use an OCI identity data lookup to select the first availability domain for the tenancy/region and use it for filesystem creation. This keeps the required interface minimal while still producing a valid filesystem.

**Outputs (module):**

- `filesystem_ocid` — Filesystem OCID.
- `filesystem_display_name` — Display name used.

**Error Handling:**

- Fail fast on missing required variables and provider auth errors (Terraform defaults).

**Integration test root config design (used by `tests/integration/test_fss_filesystem_tf.sh`):**

- A minimal Terraform root configuration that:
  - configures the provider (via environment / standard Terraform provider auth)
  - calls `terraform/modules/fss_filesystem/`
  - outputs `filesystem_ocid`

**Integration test required inputs (test runner environment):**

- Terraform available on PATH (`terraform`).
- OCI credentials/provider auth available to Terraform.
- Ability to resolve target compartment:
  - `COMPARTMENT_OCID` environment variable preferred, or
  - resolve from compartment path `/oci_tf_fss` using OCI CLI before running Terraform.

### Implementation Approach

1. Define Terraform architecture rules (PBI-006) and apply them to the module shape.
2. Implement the module and a minimal integration test root configuration.
3. Integration test runs `terraform init` + `terraform apply` and validates the filesystem OCID output is present.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — module must be verified in a real OCI environment.
- **Regression:** integration — integration suite is the current safety net.
- **Regression scope:** omit (full suite)

#### Unit Test Targets

None (Terraform module; unit tests not defined yet in this repo).

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|----------|----------------------------|------------------|--------------|
| Apply module in `/oci_tf_fss` | OCI creds + Terraform + permissions | Filesystem created, OCID output present | 1-5 min |

#### Smoke Test Candidates

None.

**Success Criteria:**

- Terraform apply succeeds and outputs include the created filesystem identifier.

### Open Design Questions

- None.

---

## PBI-006. Terraform architecture rules for agentic development

Status: Proposed

### Requirement Summary

Establish a set of Terraform architecture rules to be used as the standard for all further work in this repository, and upstream them into RUPStrikesBack rules/skills.

### Terraform Module Interface — Rules of Thumb (optional arguments)

- Prefer **required inputs** only for values that cannot be derived safely (for example `compartment_ocid`).
- If there is a safe, stable default, make the argument optional with `default = <value>`.
- If “unset” should change behavior (for example “auto-pick AD”), use `default = null` and conditional selection.
- For optional nested blocks, use `dynamic` blocks with `for_each`:
  - optional single block: `for_each = var.block == null ? [] : [var.block]`
  - optional repeated blocks: `for_each = var.blocks` with `default = []`
- For optional maps (for example tags), use `default = {}`.
- Do not create “*_type” scalar variables for blocks (for example `locks.type`). Prefer structured variables (`object` / `list(object)`) so required fields are enforced by the type system.

### Feasibility Analysis

**API Availability:**

- N/A (rules/process).

**Technical Constraints:**

- Rules must be concrete enough that Sprint designs can reference them as a governing standard.

**Risk Assessment:**

- If rules are too vague, they won’t prevent drift; if too strict, they will slow iteration.

### Design Overview

- Define the local rule set first (as sprint artifact), then upstream to RUPStrikesBack in a follow-up change set.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — kept for the sprint due to PBI-001.
- **Regression:** integration

**Success Criteria:**

- RUPStrikesBack contains the Terraform rules/skill and Sprint designs can reference them.

### Open Design Questions

- None.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Terraform apply creates filesystem and returns OCID

- **Preconditions:** Terraform installed; OCI creds configured; permissions for `/oci_tf_fss`.
- **Steps:** run `terraform init` and `terraform apply` against a minimal root config using the module.
- **Expected Outcome:** apply succeeds and filesystem OCID output is non-empty.
- **Verification:** parse outputs and assert filesystem OCID is present.
- **Target file:** `tests/integration/test_fss_filesystem_tf.sh`

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
|--------------|-------|------------|-------------------|
| PBI-001 | — | — | IT-1 |
| PBI-006 | — | — | (process) |

