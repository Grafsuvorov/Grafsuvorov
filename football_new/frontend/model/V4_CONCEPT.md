# Model V4

`v4` starts from a clean-slate premise:

1. One honest prematch snapshot per fixture.
2. Separate probability engines before any betting logic.
3. Calibration before value detection.
4. Portfolio logic only after probability quality is proven.

## Phase 1

- `market baseline`
- `simple rolling-goals poisson`
- `blend market + poisson`
- time-based validation

This is intentionally narrow. If this baseline cannot beat or at least approach market `logloss`, adding more layers is premature.

## Phase 2

- stronger prematch team-strength features
- ML outcome model
- ML totals model
- proper blend search and calibration

## Phase 3

- value layer
- auto/watch separation
- portfolio caps
- production logging and CLV monitoring
