# ADR-0004: `problem.getDomain()` is the single source of truth for decision-space bounds

- **Status:** Accepted
- **Date:** 2026-05-21

## Context

Decision-space bounds (the `[D×2]` matrix of per-variable lower/upper limits) lived in three places:

1. **`DynamicProblem`** — abstract `lower` and `upper` `[1×D]` row-vector properties, plus `getDomain()` returning `[D×2]`. Two redundant representations of the same data on the same object.
2. **`config.domain`** — a cached snapshot taken once in `initTrial.m`: `config.domain = problem.getDomain()`. Set once, never invalidated.
3. **Driver-private properties** — three of six baselines copied the data again:
   - `TdceaDriver.domain` (used transposed as `this.domain'`)
   - `CrdcmoDriver.domain`
   - `HatcDriver.boundary.lower` / `.upper` (bypassed `config.domain` entirely; synthesized `[D×2]` mid-evolve as `[bnd.lower', bnd.upper']`)

The other three baselines (mEDCMOA, DCNSGAII_A, DCNSGAII_B) read `config.domain` directly without caching. So the codebase had three baselines caching, two not caching, and one bypassing the cache and synthesizing the canonical shape on the fly.

This forced two pieces of compensating complexity:

- **`polynomialMutation`** carried a runtime shape-detection branch (`if size(domain, 1) == 2 && size(domain, 2) == D`) purely to absorb TDCEA's `domain'` transpose habit. The "shape autodetect" was a workaround for one baseline's convention, not a feature.
- **Six different call-site grammars** for the same thing: `config.domain`, `this.domain`, `this.domain'`, `[bnd.lower', bnd.upper']`, `this.config.domain`, `this.problem.lower`/`upper`.

The cache existed because operators take `domain` as data rather than holding a `problem` handle (a real architectural good — keeps `common/operators/` problem-agnostic). But the cost — a fragmented, ambiguous representation — outweighed the benefit, especially since `getDomain()` is a stored-property accessor whose dispatch is invisible against `calObj` cost.

## Decision

Three rules, applied uniformly:

### 1. One canonical shape: `[D×2]`

Column 1 is lower, column 2 is upper. This is what `getDomain()` already returns. Operators document and assume `[D×2]`. The `[2×D]` shape branch in `polynomialMutation` is removed; callers passing `domain'` are fixed at the call site.

### 2. One canonical source: `problem.getDomain()`

Drivers call `this.problem.getDomain()` at the call site and forward the resulting `[D×2]` matrix to operators. **`config.domain` is removed.** **`config.decisionDims` is removed** (same reasoning: cached snapshot of `problem.getDecisionDims()`). **Driver-private `domain` / `boundary` properties are removed.** Operators continue to take `domain` as a `[D×2]` data argument (preserving the operators-are-problem-agnostic property).

### 3. Decision-space bounds are static across a trial

`DynamicProblem` subclasses set `lower` / `upper` in `initialize()` and never mutate them in `updateEnvironment()`. This is already true of every problem in the suite (DCDTLZ1, DCDTLZ2) and matches the canonical DCMOP formulation, where the dynamism lives in objectives and constraints, not in box constraints.

This makes the "`getDomain()` returns the same value across the entire trial" assumption explicit, so the loss of caching is provably safe.

## Consequences

**Removed:**
- `config.domain` (set in `initTrial.m`, removed)
- `config.decisionDims` (also derivable from `problem.getDecisionDims()`)
- `TdceaDriver.domain`, `CrdcmoDriver.domain` private properties
- `HatcDriver.boundary` private property (with `cglpPre`'s `boundary` parameter replaced by `domain`)
- `polynomialMutation`'s `[2×D]` shape-detection branch (~5 lines of defensive branching)
- All `this.domain'` transposes in `TdceaDriver`

**Updated:**
- All variation call sites converge on the single grammar `sbxPm(parents, this.problem.getDomain(), op, mode)` and equivalents for `dePm`, `polynomialMutation`
- `respondToChange` / `tdcResponse` functions read `problem.getDomain()` instead of `config.domain`
- `cglpPre` parameter changed from `boundary` (struct with `.lower`/`.upper`) to `domain` (`[D×2]`); internally slices into row vectors

**Documented:**
- `CONTEXT.md` adds an entry under "Architectural concepts" naming `problem.getDomain()` as the canonical bounds source and stating that decision-space bounds are static across a trial

## Why future architecture reviews should not re-suggest re-introducing `config.domain`

A cache is justified when the cached value is expensive to compute and the compute happens on a hot path. `getDomain()` is a transpose-and-concat over stored `lower`/`upper` properties — not a computation. The trial hot path is offspring evaluation, dominated by `calObj`. Method dispatch on `getDomain()` is invisible against that cost.

The cache also created a correctness footgun: if a future problem ever mutated bounds mid-trial (the abstract class permits it today, even if no current problem does it), the cache silently went stale. Rule 3 closes that footgun by stating bounds are static — but with bounds static, the cache offers nothing the live call doesn't.

## When to revisit

Reopen this decision if:

- A research need emerges for problems with mutating decision-space bounds (e.g., a "shrinking feasible box" benchmark). At that point the static-bounds rule (Rule 3) is the constraint to relax, and a cache becomes outright wrong rather than just redundant — a different design from the current one. Treat that as ADR-0004's repeal, not its amendment.
- Profiling shows `getDomain()` dispatch is measurable in the trial loop. Unlikely (it would require operator iteration to dwarf `calObj`), but if it happens, the right fix is operator-local caching inside the variation step, not a config-global cache.
