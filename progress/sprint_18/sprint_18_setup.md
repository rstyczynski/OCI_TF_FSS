# Sprint 18 - Setup

## Contract Review

Rules reviewed: `RUPStrikesBack/rules/generic/`, `RUP_patch.md`, `PROJECT_RULES.md`.

Sprint 18 is YOLO mode. All decisions are logged in phase documents.

## Analysis

### PBI-033. Stable release pointers for terraform/packages

**Pre-design reference:** `predesigns/stable_module_release_pointers.md`

**Problem:** Sprint products accumulate in `terraform/modules/` under sprint-suffixed names (e.g. `fss_stack_sprint17`). Operators and regression tests must reference the stable product concept, not the internal sprint number.

**Scope:** Create `terraform/packages/` as the operator-facing release directory. Add symlinks pointing from stable names into the versioned sprint directories in `terraform/modules/`. Encode the rule in `PROJECT_RULES.md` so all future sprints follow it automatically.

**Compatibility:** Pure additive change. No existing `.tf` source paths are touched. Existing tests referencing sprint-suffixed paths remain valid.

**Readiness:** Pre-design complete. Implementation straightforward (symlinks + rules text).

YOLO decision: proceed directly to design without clarification.
