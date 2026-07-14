# Outcome V3 Plan

## Goal
Build a cleaner research stack for `1X2`:

1. Market baseline
2. Poisson goal model
3. CatBoost multiclass
4. Draw-risk model
5. Side model (`Home vs Away`, conditional on not-draw)
6. Blend + calibration
7. Compare against market and current outcome stack

## Philosophy
The model should not just "predict the winner".
It should estimate probabilities better than market in selected segments.

## Research v1 scope
First prototype includes:
- market implied probabilities
- CatBoost multiclass
- Poisson outcome probabilities
- separate draw model
- separate side model
- simple blend search on CAL
- multinomial logistic calibration

It does **not yet** include:
- line movement
- CLV
- segment-based activation
- final value layer

Those come after probability quality is proven.

## Targets
- multiclass target: `0 Away`, `1 Draw`, `2 Home`
- draw target: `1 if draw else 0`
- side target: `1 if Home else 0`, trained only on non-draw matches

## Success criteria
For research to be worth continuing:
- weighted `val_logloss` should improve over current outcome stack
- ideally approach or beat `market-only`
- draw calibration should improve in leagues where current stack underperforms

## Next steps after v1
If v1 helps:
1. add better draw-risk features
2. add opening/current/closing line features
3. add value layer on OOF predictions
4. add walk-forward segment stability
