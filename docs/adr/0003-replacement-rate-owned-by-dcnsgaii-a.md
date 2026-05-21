# ADR-0003: DNSGA-II-A's replacementRate is owned by its driver, not in config

- **Status:** Accepted
- **Date:** 2026-05-21

## Context

`config.algo.replacementRate = 0.2` was declared in `createConfig` and listed in the README as a framework configuration knob. Only one consumer read it: `baselines/DCNSGAII_A/respondToChange.m`. No other baseline referenced it.

This is the same "false seam" pattern as [ADR-0002](0002-operator-params-owned-per-baseline.md): a baseline-defining hyperparameter sitting in the framework config, presenting as user-tunable when in fact it is a fact about the algorithm.

The value `0.2` comes from Deb, Rao N, & Karthik (2007) — the paper that introduced DNSGA-II-A. Changing it does not "tune the framework"; it changes what DNSGA-II-A *is*, in a way that breaks comparison with the published baseline.

## Decision

Apply ADR-0002's pattern. Delete `config.algo.replacementRate`. `DcnsgaiiADriver` owns the value as a private property, set inline in `initialize()` with a comment attributing it to Deb et al. 2007. The baseline's `respondToChange.m` takes `replacementRate` as an explicit argument, supplied by the driver — parallel to how the shared `evolve.m` takes `operatorParams`.

## Consequence: why future architecture reviews should not re-suggest centralizing replacementRate

`replacementRate` is baseline-defining. It is not a user-facing tuning knob. Centralizing it into config:

- creates the false expectation that users can tune it across baselines (no other baseline uses it);
- conflates "framework knobs" (popSize, maxGenPerEnv, numRuns) with "baseline characteristics" (DNSGA-II-A's published replacement fraction).

The accepted cost: one literal `0.2` lives in `DcnsgaiiADriver.initialize()` instead of `createConfig`. That is the correct location, because the value is part of what defines DNSGA-II-A.

## When to revisit

Reopen this decision if:
- A second baseline adopts the same random-replacement strategy with a *configurable* replacement fraction, and a research need emerges to vary the fraction across both baselines simultaneously. At that point an explicit per-baseline override is a different design from a framework knob.
