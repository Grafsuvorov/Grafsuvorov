# Model V2 Plan

## Why V2

Current `xgb + poisson + calibration + policy` stack still produces useful totals signals, but the audits show 3 structural issues:

1. `1X2` quality is league-fragile.
2. `TOTAL` probabilities are overconfident in several confidence bins.
3. Policy changes can widen coverage, but they cannot fully repair model ranking / calibration weaknesses.

V2 should therefore be treated as a research track, not as another small policy patch.

## Design Principles

1. Keep `Outcome` and `Totals` as separate problems.
2. Treat market as a prior, not as truth.
3. Build reusable pre-match context features once and share them across models.
4. Validate in walk-forward windows by league and by market type.
5. Optimize for:
   - calibration
   - segment stability
   - realized ROI after policy
   - coverage discipline

## Proposed Architecture

### 1. Outcome stack

Use a decomposed architecture instead of one monolithic `1X2` belief:

- `draw likelihood` model
- `home vs away` conditional model
- optional league correction layer
- final recomposition into `[away, draw, home]`

Expected gains:

- better draw handling
- clearer league corrections
- easier calibration diagnostics

### 2. Totals stack

Move totals closer to a goal-distribution framework:

- team expected goals home
- team expected goals away
- poisson / corrected-goal distribution
- binary `over2.5` only as derived output

Expected gains:

- less unstable binary overfitting
- better extension path to `BTTS`, scorelines, alt totals

### 3. Shared context layer

Shared features should include:

- team strength
  - elo
  - rolling xG / xGA
  - season points proxy
- squad availability
  - injuries
  - player contribution dependency
- match context
  - rest days
  - congestion
  - recent home/away load
  - recent H2H balance
- league environment
  - pace
  - draw rate
  - over rate
- market context
  - implied probs
  - bookmaker depth
  - overround

## Phases

### Phase 1. Shared feature foundation

- Add reusable `match_context` features.
- Keep the existing stack compatible.
- Measure whether these features help calibration or ROI before deeper rewrites.

### Phase 2. Outcome V2 research

- Build `draw` and `home-vs-away` submodels.
- Compare against current multiclass outcome stack.
- Measure:
  - log loss
  - macro-F1
  - draw calibration
  - ROI of strong-only signals

### Phase 3. Totals V2 research

- Predict expected goals by side.
- Derive `over2.5` from the goal model.
- Compare against current totals classifier.
- Pay special attention to confidence bins `0.55-0.65` and `0.75+`.

### Phase 4. Stacking and policy

- Compare:
  - current prod
  - V2 outcomes + current totals
  - current outcomes + V2 totals
  - full V2 hybrid
- Only then move the best contour into live policy.

## Validation Rules

Every candidate must be checked on:

- overall log loss
- per-league log loss
- per-league probability bias
- confidence-bin calibration
- realized ROI by:
  - league
  - market
  - outcome side
  - rating tier
- coverage after policy

## Current Priority

Priority order for implementation:

1. Shared `match_context` features
2. Outcome calibration cleanup
3. Goal-based totals prototype
4. Hybrid walk-forward comparison
