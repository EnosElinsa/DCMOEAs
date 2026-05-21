# DCMOEAs — Domain Context

This file names the load-bearing concepts in the codebase. Use these terms when discussing architecture; don't drift into synonyms.

## Domain glossary

- **Trial** — One independent execution of a baseline algorithm on a dynamic constrained multi-objective problem, from initial population to terminal environment. A benchmark consists of N trials per baseline.
- **Environment** — A single static snapshot of a dynamic problem. The problem advances through `tMax` environments over the course of a trial; each environment lasts `maxGenPerEnv` generations.
- **Environment change** — The transition between two consecutive environments. Triggers a change response. Detected by the controller, not by the algorithm.
- **Change response** — Per-baseline strategy for refreshing the population after an environment change. Examples: random replacement (DCNSGAII_A), polynomial mutation (DCNSGAII_B), TDC centroid shift (TDCEA, CRDCMO), tribe-based regeneration (mEDCMOA), CGLP prediction (HATC).
- **Evolution step** — One generation of variation + selection. The unit of work between change checks.
- **Population** — A `[1×N]` Solution object array. Multiple populations may exist within a single baseline (CRDCMO, TDCEA, HATC each maintain a primary and an auxiliary population).
- **Decision** — A `[1×D]` row vector in decision space. A population's decisions are accessed as a `[N×D]` matrix via `pop.decs()`.
- **Solution** — One individual: decision vector, objective vector, constraint vector, scalar CV. Implemented as `Solution.m`.
- **Constraint violation (CV)** — Scalar `sum(max(0, con))`. CV == 0 means feasible.
- **Feasible / infeasible** — Solution-level: CV == 0. Trial-level: at least one feasible solution exists in the final population at every change point.
- **Reference point** — Per-dimension max of all feasible objectives across all algorithms' results, scaled by 1.1. Used for HV computation.

## Architectural concepts

- **Problem factory** — A function `@(config) -> DynamicProblem` that constructs and initializes one problem instance. Passed to `runBenchmark` as the first argument.
- **DynamicProblem** — Abstract base class for benchmark problems. Subclasses implement `calObj`, `getDomain`, `updateEnvironment`, `tMax`, etc. The override point for problem-specific best-selection is `selectBest` (see [ADR-0001](docs/adr/0001-selectbest-stays-on-problem.md)).
- **TrialController** — Owns per-trial decision-execution, environment advancement, and snapshot recording. Single boolean output (`done`) covers both terminal-environment and no-feasible termination. Delegates recording to `TrialLogger` (private).
- **TrialLogger** — Pure recorder. No control flow. Builds the `outputInfo` struct that ends up in `result.outputInfo`.
- **TrialDriver** — Abstract handle base class owning the trial loop. Concrete subclass per baseline holds algorithm-private state and implements four methods: `initialize`, `evolveStep`, `respondToChange`, `currentPop`. The driver, not the baseline, advances `state.gen` and calls the controller. Introduced in spec `architecture-deepening-round-2`.
- **Variation primitives** — Pure mathematical operators: `sbxCrossover`, `deCrossover`, `polynomialMutation`. No algorithm policy.
- **Variation bundles** — Named compositions of primitives: `sbxPm` (SBX → PM), `dePm` (DE-crossover → PM). Each bundle is one module; baselines call bundles, not primitives, when they want a complete variation step.
- **Selection bundles** — `nsgaiiSelection`, `spea2Selection`. Compose `ndSort` + `crowdingDistance` (or `calFitness`) + truncation.
- **Evolution step bundle** — `evolve.m`: a complete NSGA-II generation (mating selection + SBX-PM + environmental selection). Used by DCNSGAII_A and DCNSGAII_B.
- **operatorParams** — A struct `{proC, disC, proM, disM}` of SBX/PM hyperparameters. **Owned per baseline**, not in config (see [ADR-0002](docs/adr/0002-operator-params-owned-per-baseline.md)).

## Architectural seams

| Seam | Where | Adapters |
|---|---|---|
| `DynamicProblem` | Problem subclasses implement abstract methods | DCDTLZ1, DCDTLZ2 (extensible) |
| `TrialDriver` | Per-baseline subclasses implement four abstract methods | DCNSGAII_A/B, CRDCMO, TDCEA, HATC, mEDCMOA |
| Variation bundle | `sbxPm`, `dePm` in `common/operators/` | Two: real |
| Variation primitive | `sbxCrossover`, `deCrossover`, `polynomialMutation` | Composed inside bundles + a few direct callers |
| Selection bundle | `nsgaiiSelection`, `spea2Selection` | Two: real |
