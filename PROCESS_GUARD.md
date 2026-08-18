# Symulacja Kaskady Sieciowej — Process Guard

This repository is maintained as a falsifiable **system-dynamics and probabilistic simulation model**. Its main risk is false confidence caused by clean plots, large Monte Carlo counts or unexamined assumptions.

## Core chain

```text
assumptions
→ parameters
→ equations / state transitions
→ deterministic scenario
→ Monte Carlo / sensitivity
→ outputs
→ interpretation
```

## Invariants

- simulation output is not empirical frequency;
- random seed, parameters and configuration must be reconstructable;
- changing equations or parameter ranges requires a regression comparison;
- Morris / Sobol results are sensitivity of the model, not direct causal coefficients of reality;
- generated outputs must not silently become input assumptions;
- scenario labels must remain distinguishable from forecasts.

## `_neuro` / EEG-style process model

```text
baseline = calibrated reference scenario
burst    = sudden nonlinear excursion / shock
coupling = cross-variable feedback amplification
 drift   = outputs increasingly driven by hidden assumptions
recovery = stable, reproducible state after perturbation
```

## Review loop

```text
baseline config
→ model delta
→ deterministic smoke run
→ Monte Carlo convergence check
→ sensitivity / tail check
→ adversarial parameter probe
→ interpretation review
→ merge
```

Every published conclusion should name whether it is `OBSERVED`, `DERIVED`, `CALIBRATED`, `ASSUMED`, `HYPOTHESIS` or `STRESS PARAMETER`.
