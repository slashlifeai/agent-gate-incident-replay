# Docs And Specs Cycle Runbook

Use this runbook when a change updates repository contracts, incident module behavior, release expectations, or public documentation authority.

## Classification Rule

Use `specs/` for current contract authority.

Use `docs/plans/` for lifecycle artifacts:

- design;
- implementation plan;
- planner handoff;
- implementer handoff;
- review;
- verification;
- historical design references.

If a document describes a past migration or obsolete command surface, it belongs in `docs/plans/`, not `specs/`.

## Current Spec Authority

The current authority set is:

```text
specs/domain.md
specs/decisions.md
specs/incident-module.md
```

Add a new spec only when the repository gains a stable contract that should outlive an implementation plan.

## Required Lifecycle Artifacts

For a new docs/spec cycle, create a topic prefix:

```text
docs/plans/YYYY-MM-DD-<topic>
```

Create at minimum:

```text
docs/plans/YYYY-MM-DD-<topic>-design.md
docs/plans/YYYY-MM-DD-<topic>-implementation-plan.md
docs/plans/YYYY-MM-DD-<topic>-verification.md
```

For larger work, also create planner-to-implementer, implementer-to-reviewer, and review artifacts.

## Validation

Run before proposing completion:

```bash
git diff --check
test -f specs/domain.md
test -f specs/decisions.md
test -f specs/incident-module.md
```

If runtime files changed, also run a local browser/runtime smoke test or document why it was not possible.
