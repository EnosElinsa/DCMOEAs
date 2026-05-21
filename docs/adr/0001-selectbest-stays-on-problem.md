# ADR-0001: `DynamicProblem.selectBest` is the problem-specific override point

- **Status:** Accepted
- **Date:** 2026-05-21

## Context

Architecture review surfaced `DynamicProblem.selectBest` as a candidate for relocation to `TrialController`. The rationale: best-selection (min-max-normalize feasible objectives → weighted sum → argmin) is trial-level decision policy that depends on `weights` (already owned by the controller) and operates on a feasibility-filtered subset (also already produced by the controller). No concrete `DynamicProblem` subclass overrides `selectBest`.

By the deletion test, moving `selectBest` would concentrate best-selection logic next to weights and feasibility filtering — a real locality benefit on paper.

## Decision

`selectBest` stays on `DynamicProblem` as a default method (current structure preserved). `TrialController` continues to invoke `problem.selectBest(feasiblePop, weights)`.

## Consequence: why future architecture reviews should not re-suggest moving it

Some future problems may need problem-specific best-selection logic — examples include:
- A problem-private feasibility refinement (e.g., a UAVHAP variant where "best" requires checking that an additional, problem-internal constraint is satisfied with a margin).
- A problem-specific tie-breaker (e.g., preferring solutions with bounded resource usage in a specific decision dimension).
- A problem with non-uniform objective normalization needs (e.g., logarithmic scaling on one objective).

These overrides cannot live on `TrialController` because the controller is intentionally problem-agnostic. Keeping the default on `DynamicProblem` makes the override point discoverable to problem authors: subclass, override, done.

The accepted cost: trial-level policy (weighted-sum-of-normalized-objectives) lives on the problem class today, with zero concrete overrides. This looks like a hypothetical seam by the standard heuristic. It is — deliberately — preserved as a documented extension point.

## When to revisit

Reopen this decision if:
- After 12+ months, no problem subclass has overridden `selectBest`. The hypothetical seam stayed hypothetical and can probably be removed.
- A second problem-agnostic policy emerges (e.g., trial-level objective scaling) that would also benefit from co-location with weights. Then move `selectBest` and the new policy together.
- The `weights` ownership moves off `TrialController` for an unrelated reason. The locality argument shifts.
