## Contract

### Sprint context

- Sprint: 1 — Initial setup
- Status: Progress
- Mode: managed
- Test: integration
- Regression: integration
- Backlog Items:
  - PBI-005. Foundation infrastructure for system-level FSS tests

### Rules and procedures acknowledged (source: `RUPStrikesBack/`)

- Foundation docs read: `AGENTS.md`, `HUMANS.md`, `RUP_patch.md`, `BACKLOG.md`, `PLAN.md`
- Cooperation rules: `RUPStrikesBack/rules/generic/GENERAL_RULES.md`
- Product Owner workflow: `RUPStrikesBack/rules/generic/PRODUCT_OWNER_GUIDE.md`
- Git rules: `RUPStrikesBack/rules/generic/GIT_RULES.md`
- Backlog item format: `RUPStrikesBack/rules/generic/backlog_item_definition.md`
- Sprint format: `RUPStrikesBack/rules/generic/sprint_definition.md`
- Test evidence policy: `RUP_patch.md` (test claims must be backed by committed artifacts; missing runs must be recorded as NOT RUN)

### Implementor responsibilities (as executed in this repo)

- Use `@RUPStrikesBack/.claude/commands/rup-manager.md` as the orchestration entrypoint.
- Treat `PLAN.md` and `BACKLOG.md` as Product Owner-owned; do not change them during sprint execution (except initial bootstrap created here to enable the process).
- Keep all sprint artifacts under `progress/sprint_N/` following naming conventions.
- Use semantic commits per `RUPStrikesBack/rules/generic/GIT_RULES.md` and push after each commit.
- Do not claim tests were executed unless log artifacts are committed under `progress/sprint_N/`.

### Constraints / local policy notes

- `PROGRESS_BOARD.md` is maintained as the live status tracker for sprint and backlog item states.
- Sprint-level state layout per **`RUP_patch.md` § P7**: **`progress/sprint_1/scaffold/<NAME_PREFIX>/`** for oci_scaffold foundation (`state-*.json`, keys); **`progress/sprint_1/tf_state/<test_id>/`** for Terraform runs — do not combine in one directory.

### Open questions

- None.

### LLM tokens

- Not available from runtime in this environment.

## Analysis

### Backlog Items analyzed

#### PBI-005. Foundation infrastructure for system-level FSS tests

- **Requirement summary**: Provide a reusable foundation environment (network + test client baseline) for system-level tests of the FSS modules using `oci_scaffold`.
- **Feasibility**: Medium. Requires selecting a minimal foundation shape from `oci_scaffold` and confirming it can be provisioned in the target compartment (`/oci_tf_fss`).
- **Dependencies**: `oci_scaffold` submodule must be usable as a baseline.
- **Compatibility**: Must align with later sprints that create filesystem/mount target/export modules and the NPA validation.
- **Testing**: Integration-level validation should prove the foundation exists and exposes identifiers required by later tests.
- **Risks/concerns**:
  - Environment constraints (credentials/OCI access) may prevent executing integration tests; per `RUP_patch.md`, results must be recorded as NOT RUN with reasons and artifacts.

### Overall sprint assessment

- Feasibility: Medium
- Estimated complexity: Moderate
- Prerequisites met: Yes (repo initialized, RUPStrikesBack submodule present, initial PLAN/BACKLOG exist)
- Readiness for design phase: Confirmed Ready

