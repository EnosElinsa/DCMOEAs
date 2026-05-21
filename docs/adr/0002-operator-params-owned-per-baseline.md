# ADR-0002: SBX/PM operator parameters are owned per-baseline, not in config

- **Status:** Accepted
- **Date:** 2026-05-21

## Context

`config.algo.operatorParams = struct('proC',1,'disC',20,'proM',1,'disM',20)` was declared in `createConfig`. Five places (the shared `evolve.m` and four baselines) referenced operator parameters; only `evolve.m` actually read them from config — CRDCMO, TDCEA, HATC, and DCNSGAII_B redeclared the same literal struct locally.

The "one adapter, four bypassers" pattern signaled a hypothetical seam. Two interpretations:

1. **The seam is real, the bypassers are bugs.** Fix: have all five consumers read from config. Tuning experiments work uniformly.
2. **The seam is a false promise.** Each baseline owns its operator parameters as a fact about the algorithm — published in the original paper, part of what defines the baseline. There is no legitimate user-tuning use case across baselines.

## Decision

Interpretation 2. Delete `config.algo.operatorParams`. Each baseline owns its operator-params struct inline in its driver, with a comment attributing the values to the source paper (or the framework default convention).

The shared `evolve.m` takes operator-params as an explicit argument, supplied by the caller (currently DCNSGAII_A's and DCNSGAII_B's drivers).

mEDCMOA's `(0.8, 5, 0.05, 40)` — already different from the defaults — is treated identically: inline in mEDCMOA's driver, no special handling.

## Consequence: why future architecture reviews should not re-suggest centralizing operator params

Operator params are baseline-defining. They are not user-facing tuning knobs. Centralizing them into config:

- creates the false expectation that users can tune them and get sensible behavior across baselines (they cannot — each baseline is calibrated against its paper's defaults);
- conflates "framework knobs" (popSize, maxGenPerEnv, numRuns) with "baseline characteristics" (operator params).

The accepted cost: five baselines each declare their own operator-params struct. Four of them carry the same numeric values today. That is a real (but small) numeric duplication, deliberately accepted in exchange for keeping the config seam free of false promises.

## When to revisit

Reopen this decision if:
- A research need emerges to systematically vary operator parameters across all baselines simultaneously (e.g., a paper studying SBX `disC` sensitivity). At that point, an explicit `--operatorParams` CLI override that all baselines opt into is a different design.
