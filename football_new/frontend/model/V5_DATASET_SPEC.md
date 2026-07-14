# Model V5 Dataset Spec

`v5` is a probability-first rebuild.

The goal is not to find more bets.
The goal is to produce probabilities that are closer to truth than the current `v4` snapshot allows.

## Core Principle

Every row in the dataset must answer:

`What was actually known at prediction_time for this match?`

If a field cannot be tied to a real timestamp before kickoff, it does not belong in the core prematch snapshot.

## Prediction Modes

`v5` should have two explicit modes.

1. `pre_lineup`
- default production mode
- built from data available before lineups
- main benchmark for probability quality

2. `post_lineup`
- late update mode
- only after confirmed starting XIs are available
- never mixed into `pre_lineup` evaluation

The two modes must be trained and evaluated separately.

## Row Contract

Each dataset row should contain at least:

- `fixture_id`
- `league_id`
- `season`
- `round`
- `match_start_utc`
- `prediction_time_utc`
- `mode`
- `hours_before_match`
- `home_team_id`
- `away_team_id`
- `target_result`
- `target_over25`

## Required Time Discipline

For every feature block, store the timestamp of the underlying source snapshot when possible:

- `odds_snapshot_time_utc`
- `table_snapshot_time_utc`
- `injury_snapshot_time_utc`
- `lineup_snapshot_time_utc`
- `feature_cutoff_time_utc`

The hard rule:

- feature data must satisfy `source_time <= prediction_time_utc`
- the model must never see data captured after `prediction_time_utc`

## Block A: Timed Market Data

This is the first missing block that can realistically move probability quality.

Recommended storage table:

- `football.odds_snapshots_v1`

Expected grain:

- one row per `fixture_id + snapshot_time_utc`

### Raw fields

- `odds_home_open`
- `odds_draw_open`
- `odds_away_open`
- `odds_home_current`
- `odds_draw_current`
- `odds_away_current`
- `odds_home_close` for analysis only, never as a live feature
- `odds_draw_close` for analysis only
- `odds_away_close` for analysis only
- `n_bookmakers_open`
- `n_bookmakers_current`
- `odds_snapshot_time_utc`
- `hours_before_match`

### Derived fields

- `p_home_open`
- `p_draw_open`
- `p_away_open`
- `p_home_current`
- `p_draw_current`
- `p_away_current`
- `overround_open`
- `overround_current`
- `market_entropy_open`
- `market_entropy_current`
- `line_move_home = p_home_current - p_home_open`
- `line_move_draw = p_draw_current - p_draw_open`
- `line_move_away = p_away_current - p_away_open`
- `favorite_side_open`
- `favorite_side_current`
- `favorite_changed_flag`

### Why it matters

The current `v4` snapshot only sees one market state.
That is enough to be competitive, but not enough to understand whether the market is strengthening or weakening a side.

## Block B: True Prematch xG Layer

This block must be time-safe and rolling.
It should not reuse noisy same-match stats.

### Team rolling fields

Overall windows:

- `home_xg_for_5`
- `home_xga_5`
- `home_npxg_for_5`
- `home_npxga_5`
- `home_xg_for_10`
- `home_xga_10`
- `home_npxg_for_10`
- `home_npxga_10`

- `away_xg_for_5`
- `away_xga_5`
- `away_npxg_for_5`
- `away_npxga_5`
- `away_xg_for_10`
- `away_xga_10`
- `away_npxg_for_10`
- `away_npxga_10`

Venue splits:

- `home_xg_for_home_5`
- `home_xga_home_5`
- `away_xg_for_away_5`
- `away_xga_away_5`

### Derived fields

- `xg_balance_home_5`
- `xg_balance_away_5`
- `xg_balance_diff_5`
- `npxg_balance_diff_5`
- `home_attack_vs_away_def_xg`
- `away_attack_vs_home_def_xg`
- `home_xg_trend_5v10`
- `away_xg_trend_5v10`

### Why it matters

The earlier heavy feature attempt failed because it used noisy raw match stats.
`v5` should use only stable rolling prematch strength summaries.

## Block C: Table and Motivation Snapshot

This block should stay in the core only if it is tied to a real prematch table state.

### Raw fields

- `home_table_position`
- `away_table_position`
- `home_points_before`
- `away_points_before`
- `home_matches_played_before`
- `away_matches_played_before`
- `season_progress`
- `round_number`

### Derived fields

- `points_diff`
- `position_diff`
- `home_gap_to_title`
- `away_gap_to_title`
- `home_gap_to_top4`
- `away_gap_to_top4`
- `home_gap_to_relegation`
- `away_gap_to_relegation`
- `home_must_win_score`
- `away_must_win_score`
- `must_win_diff`
- `dead_rubber_flag`
- `late_season_flag`

### Why it matters

We already saw seasonal regime shifts in old research.
This block stays, but only with explicit time discipline.

## Block D: Late Context Mode

This block is not allowed in the `pre_lineup` core unless the underlying data is truly available at prediction time.

### Coach fields

- `home_coach_change_30d`
- `away_coach_change_30d`
- `home_days_with_current_coach`
- `away_days_with_current_coach`

### Availability fields

- `home_injuries_core_minutes_share`
- `away_injuries_core_minutes_share`
- `home_missing_attack_share`
- `away_missing_attack_share`
- `home_missing_defense_share`
- `away_missing_defense_share`
- `home_main_gk_missing`
- `away_main_gk_missing`

### Confirmed lineup fields for `post_lineup` mode only

- `home_lineup_strength_expected`
- `away_lineup_strength_expected`
- `home_lineup_strength_confirmed`
- `away_lineup_strength_confirmed`
- `home_lineup_delta`
- `away_lineup_delta`
- `lineup_delta_diff`
- `formation_surprise_home`
- `formation_surprise_away`

### Why it matters

This block is useful, but it must not contaminate the `pre_lineup` benchmark.

## Features Explicitly Out of Scope for V5 Core

The following should stay out until the basic probability benchmark improves:

- manual league whitelists
- portfolio segment labels
- value-layer targets
- post-hoc ROI buckets as training signals
- closing odds as live features
- raw same-match stats captured after kickoff

## Research Order

`v5` should be built in phases.

### Phase 1

Build the new snapshot contract with:

- timed market data
- rolling xG layer
- table snapshot

Then compare:

- `market`
- `v4.1 base`
- `v5.0 market-aware catboost`

Success criterion:

- better walk-forward `logloss` than `market`
- better or equal `brier`

### Phase 2

If Phase 1 works, add:

- line movement features
- market entropy changes
- coach change flags

Success criterion:

- improvement on probability metrics without relying on ROI filters

### Phase 3

Only after Phase 1 and 2 are stable:

- `post_lineup` mode
- late-context refresh
- then separate value/portfolio logic

## Benchmark Rules

Every `v5` experiment must report:

- `logloss`
- `accuracy`
- `brier`
- `topclass_calibration_gap`
- by league and overall
- single holdout and walk-forward

Probability quality comes first.
ROI is secondary and only meaningful after the probability benchmark is credible.

## Minimal Success Definition

`v5` is worth continuing only if it beats both:

1. `market`
2. current best `v4.1` probability baseline

on walk-forward `logloss`.

If it cannot do that, no amount of portfolio logic should be trusted.
