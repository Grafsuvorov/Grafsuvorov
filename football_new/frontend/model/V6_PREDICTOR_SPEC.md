`V6 predictor` is the current best accuracy-first outcome contour.

Core:
- `v5.5 draw-side` decomposition
- binary `Draw vs Not Draw`
- binary `Home vs Away | Not Draw`

Targeted correction:
- only for `La Liga` and `Ligue 1`
- only for low-confidence matches
- only when market leans to `Home`
- flips `Away/Draw -> Home`

Current best correction search space:
- `max_conf`: `0.40`, `0.42`, `0.45`, `0.48`
- `min_market_home`: `0.36`, `0.38`, `0.40`
- `min_home_gap`: `0.01`, `0.02`

Selection protocol:
- choose correction params on `cal`
- apply chosen params on `val`
- evaluate on walk-forward only

Primary metric:
- `top-pick accuracy`

Secondary metrics:
- `draw precision`
- `draw recall`
- accuracy by league

Current known behavior:
- `Bundesliga` and `Serie A` are strongest model-led leagues
- `La Liga` and `Ligue 1` need `Home` correction
- `Premier League` is near market parity
