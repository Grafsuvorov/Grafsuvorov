# Confirmed Lineup Delta Plan

## Goal
Measure the real upside of lineup-aware modeling through:

`today starting XI quality - team baseline lineup quality`

This is the feature family that should matter more than historical average lineup strength.

## Why baseline lineup strength was weak
The first lineup layer only answered:
- how strong the team usually is
- how strong its usual recent XI has been

That overlaps with:
- xG
- form
- Elo
- market odds

So the uplift was small.

## What this layer measures instead
For each historical fixture with recorded starters:
- actual XI rating for this fixture
- actual attack / defense / midfield line ratings
- weakest starter
- line balance

Then compare those values to pre-match baseline:
- long-term team XI baseline
- rolling all-match XI baseline
- venue-specific XI baseline
- attack / defense baseline

## Research-only status
Current implementation is **not pre-match safe** for production.

It uses the actual starting XI stored for the same fixture.

That makes it useful for:
- upper-bound research
- understanding whether lineup shocks matter materially
- designing expected-XI approximations

It is **not** yet suitable for live prediction before lineups are known.

## Feature families
Per side:
- `home_cl_xi_rating`
- `away_cl_xi_rating`
- `home_cl_att_rating`
- `away_cl_att_rating`
- `home_cl_def_rating`
- `away_cl_def_rating`
- `home_cl_mid_rating`
- `away_cl_mid_rating`
- `home_cl_weakest_starter`
- `away_cl_weakest_starter`

Delta vs baseline:
- `home_cl_xi_delta_long`
- `away_cl_xi_delta_long`
- `home_cl_xi_delta_all_10`
- `away_cl_xi_delta_all_10`
- `home_cl_xi_delta_venue_10`
- `away_cl_xi_delta_venue_10`
- `home_cl_att_delta_all_10`
- `away_cl_att_delta_all_10`
- `home_cl_def_delta_all_10`
- `away_cl_def_delta_all_10`
- `home_cl_weakest_delta_long`
- `away_cl_weakest_delta_long`

Matchup deltas:
- `cl_xi_rating_diff`
- `cl_att_rating_diff`
- `cl_def_rating_diff`
- `cl_mid_rating_diff`
- `cl_line_balance_diff`
- `cl_xi_delta_long_diff`
- `cl_xi_delta_all_10_diff`
- `cl_att_delta_all_10_diff`
- `cl_def_delta_all_10_diff`

## Next production-safe step
Replace actual XI with:
- expected XI from recent starters
- adjusted by injuries / suspensions / availability

Then these same delta features become pre-match safe:
- `expected_xi_vs_baseline`
- `expected_attack_vs_baseline`
- `expected_defense_vs_baseline`

## Decision rule
If confirmed-lineup deltas help materially in research, then:
1. keep them out of baseline pre-match model,
2. use them as proof that lineup shocks are real,
3. build expected-XI approximation next.
