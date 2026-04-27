# RUP Patch — Local Repository Policy

This repository adopts RUP rules from `RUPStrikesBack/rules/`. The sections below are **local clarifications** to prevent ambiguity and ensure test/quality gate reporting is verifiable.

## P1. Test execution claims must be evidence-backed

Any statement that a test or quality gate was run (or passed/failed) **must be backed by an artifact** in the repository.

- A gate is only considered **executed** if there is a corresponding timestamped log file committed under `progress/sprint_N/` (see RUP `test_procedures.md`).
- When writing `progress/sprint_N/sprint_N_tests.md`, every gate row (PASS/FAIL/PARTIAL) must reference the **exact log file path** produced by that run.
- Never infer or assume a gate outcome. If you did not run it and cannot produce the log, the status must be recorded as **NOT RUN** (with reason).

## P2. When tests cannot be executed, record it explicitly

If tests/quality gates cannot be executed due to missing credentials, unavailable OCI capacity, environment constraints, or runtime limitations:

- Record the situation in `progress/sprint_N/sprint_N_tests.md` as **NOT RUN** with a short reason.
- Create/append an entry in `progress/sprint_N/sprint_N_openquestions.md` or `progress/sprint_N/sprint_N_proposedchanges.md` (whichever fits) describing what is required to enable execution.
- Do not “paper over” missing execution with narrative summaries.

## P3. No “synthetic passing” without an explicit policy decision

If a sprint requires gates that are expensive or long-running (for example OCI integration runs) and a reduced gate is desired (smoke-only, shortened runtime, or partial coverage), this must be treated as a **plan change**:

- Propose it in `progress/sprint_N/sprint_N_proposedchanges.md` and wait for Product Owner acceptance.
- Until accepted, execute the gates as specified by `PLAN.md` and RUP procedures, or mark them **NOT RUN**.

## P4. Documentation snippets must be executed and validated

Any command sequence published in sprint documentation (especially sprint manuals and user-facing runbooks) **must be executed by the agent** before the documentation is considered release-ready.

- Each documented snippet must have a corresponding execution artifact (for example a captured stdout/stderr log) stored under `progress/sprint_N/` and referenced from `progress/sprint_N/sprint_N_tests.md`.
- If a snippet cannot be executed (missing credentials, no OCI access, destructive side effects, or cost/capacity constraints), it must be explicitly marked **NOT RUN** with a short reason and an alternative verification plan, and treated as an open issue until resolved or accepted as a plan change.

## P5. Operator manual is mandatory for runnable access to sprint products

Each sprint that produces runnable infrastructure or operator-facing behavior MUST include a copy/paste operator manual that shows how to access and use the sprint’s products.

Requirements:

- The manual lives in `progress/sprint_N/sprint_N_operator_manual.md`.
- It MUST contain runnable snippets (copy/paste) for:
  - provisioning or bringing the sprint product to a usable state
  - connecting (for example SSH to a test instance), including how to obtain or preserve required keys
  - teardown / cleanup (when applicable)
- Any claim that a manual snippet was executed MUST be backed by an artifact per P4 (log file under `progress/sprint_N/` and referenced from `sprint_N_tests.md`).

## P6. Managed-mode approval checkpoint before quality gates

In `Mode: managed`, after Phase 3 (Construction) is implemented and committed, the workflow MUST pause for explicit Product Owner approval **before** executing Phase 4 (Quality Gates).

Requirements:

- Record the approval request in `progress/sprint_N/sprint_N_openquestions.md` (or `sprint_N_proposedchanges.md` if more appropriate).
- Product Owner signals approval by marking the entry `Status: Accepted`.
- Only then run the gate commands and create `progress/sprint_N/test_run_*.log` artifacts.

## P7. oci_scaffold state MUST live under the sprint directory

`oci_scaffold` resolves **`STATE_FILE`** as `./state-{NAME_PREFIX}.json` (and PEM paths like `./state-{NAME_PREFIX}-key`) relative to the **process working directory** (`do/oci_scaffold.sh`). Using an ephemeral **`mktemp`** workdir without copying the resulting state elsewhere **loses** teardown, recovery, and SSH key continuity after the directory is removed.

Requirements for **sprint-scoped** oci_scaffold runs (foundation stacks, Sprint 1 integration harness, operators following `sprint_N_operator_manual.md`):

1. **`WORKDIR` (cwd for oci_scaffold) MUST be under** `progress/sprint_N/` — use **`progress/sprint_N/scaffold/<stable_name>/`** for oci_scaffold foundation state (`state-{NAME_PREFIX}.json`, SSH keys). Keep **Terraform** working directories under **`progress/sprint_N/tf_state/`** (separate from oci_scaffold) so sprint tests do not mix the two kinds of state in one folder.
2. Integration tests or scripts MUST NOT rely on **`/tmp` / mktemp-only** locations as the sole home for oci_scaffold state unless the sprint explicitly documents a copy/archive step (not the default).
3. **`WORKDIR`** MUST be deterministic when the operator needs repeatable destroy/recreate — use a stable subdirectory name (often tied to `NAME_PREFIX`), not only random `XXXXXX`.
4. Secrets on disk remain sensitive: keep sprint state directories under patterns already excluded from version control if they contain PEMs (see repository `.gitignore`; do not commit raw keys).

This applies in addition to P1 evidence rules: logs under `progress/sprint_N/` do not substitute for **preserved** oci_scaffold state when teardown or reproducibility depends on `STATE_FILE`.
