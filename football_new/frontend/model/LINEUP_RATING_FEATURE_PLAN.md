# Lineup Rating Feature Plan

## Goal
Add a reusable pre-match strength layer that captures:
- long-term team quality
- short-term team quality over `15 / 10 / 5` matches
- home-only and away-only team quality
- quality of recent starting XIs
- line quality by `GK / DEF / MID / ATT`

This is the bridge between raw injuries/player events and true match readiness.

## Current v1 implementation
Source tables:
- `football.api_football_schedule`
- `football.api_football_lineups`
- `football.api_football_player_stats`

Logic:
1. Build historical starter rows per match.
2. Normalize positions into:
   - `GK`
   - `DEF`
   - `MID`
   - `ATT`
3. Build player prior rating from past appearances only:
   - weighted by minutes
   - windows `5 / 10 / 15`
   - fallback to position-level mean
4. Aggregate each historical starting XI into:
   - `xi rating`
   - `weakest starter`
   - `rating std`
   - `gk / def / mid / att rating`
   - `line balance`
5. Turn these into team snapshots:
   - long expanding average
   - rolling `5 / 10 / 15`
   - home-only rolling `5 / 10 / 15`
   - away-only rolling `5 / 10 / 15`
6. Merge snapshots pre-match to future fixtures with `merge_asof`.

## Features added in v1
Side-level base:
- `home_ls_xi_rating_long`, `away_ls_xi_rating_long`
- `home_ls_def_rating_long`, `away_ls_def_rating_long`
- `home_ls_mid_rating_long`, `away_ls_mid_rating_long`
- `home_ls_att_rating_long`, `away_ls_att_rating_long`
- `home_ls_weakest_starter_long`, `away_ls_weakest_starter_long`

Rolling all-matches:
- `*_all_5`
- `*_all_10`
- `*_all_15`

Venue-specific:
- `home_ls_xi_rating_home_5/10/15`
- `away_ls_xi_rating_away_5/10/15`
- same pattern for `def/mid/att`

System features:
- `*_diff`
- `home_ls_xi_rating_trend_5v15`
- `away_ls_xi_rating_trend_5v15`
- `home_ls_att_rating_trend_5v15`
- `away_ls_att_rating_trend_5v15`
- `home_ls_def_rating_trend_5v15`
- `away_ls_def_rating_trend_5v15`
- `ls_matchup_home_attack_vs_away_def_10`
- `ls_matchup_away_attack_vs_home_def_10`
- `ls_matchup_home_mid_vs_away_mid_10`
- `ls_matchup_venue_xi_edge_10`

## Why this is useful
This gives the model:
- a stable long-term team rating
- a recent form rating without relying only on goals/xG
- separate home/away strength
- a proxy for lineup health and depth
- a better description of whether a team is getting stronger or weaker

## Important limitation
This v1 layer is still **pre-match baseline lineup quality**, not confirmed lineup quality.

It uses recent actual starters to estimate what quality level a team usually fields.
That makes it safe for pre-match inference.

It does **not** yet react to the exact confirmed starting XI for the current fixture.

## v2 upgrade path
Next layer should be `confirmed lineup strength`:
- detect expected or confirmed starters for the current match
- compare current XI vs team baseline
- add:
  - `starting_xi_vs_baseline`
  - `attack_line_vs_baseline`
  - `defense_line_vs_baseline`
  - `missing_core_xg_share`
  - `missing_core_minutes_share`
  - `bench_depth_gap`

That is the step that will directly answer:
"weak starters today should weaken the team in the model".
