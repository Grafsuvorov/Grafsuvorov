import pandas as pd

from config import UNDERSTAT_MIN_SEASON
from features.lineup_strength import (
    _add_team_rollups,
    _aggregate_match_lineup_strength,
    _normalize_position,
    _rolling_player_priors,
    build_lineup_strength_features,
    load_lineup_history,
)


def build_confirmed_lineup_delta_features(
    schedule: pd.DataFrame,
    engine,
    windows=(5, 10, 15),
    min_season: int = UNDERSTAT_MIN_SEASON,
) -> pd.DataFrame:
    """
    Research-only layer.

    Uses the actual starting XI recorded for the same fixture and compares it to the
    pre-match team baseline built only from prior fixtures.

    This is useful to estimate the upside of lineup-aware modeling, but it is not
    safe for pre-match production unless replaced by expected or confirmed live XI.
    """
    sched = schedule.copy()
    if sched.empty:
        return pd.DataFrame({"fixture_id": []})
    sched["date_utc"] = pd.to_datetime(sched["date_utc"], utc=True, errors="coerce")

    raw = load_lineup_history(engine, min_season=min_season)
    if raw.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    raw["date_utc"] = pd.to_datetime(raw["date_utc"], utc=True, errors="coerce")
    raw["pos_group"] = [
        _normalize_position(pos, grid)
        for pos, grid in zip(raw.get("position"), raw.get("grid"))
    ]
    raw = _rolling_player_priors(raw, windows=windows)

    current_xi = _aggregate_match_lineup_strength(raw)
    if current_xi.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    current_xi = _add_team_rollups(current_xi, windows=windows)

    current_keep = [
        "fixture_id",
        "team_id",
        "is_home",
        "ls_xi_rating",
        "ls_weakest_starter",
        "ls_gk_rating",
        "ls_def_rating",
        "ls_mid_rating",
        "ls_att_rating",
        "ls_line_balance",
    ]
    current_xi = current_xi[current_keep].copy()

    home_current = current_xi[current_xi["is_home"] == 1].drop(columns=["is_home", "team_id"]).rename(
        columns={
            "ls_xi_rating": "home_cl_xi_rating",
            "ls_weakest_starter": "home_cl_weakest_starter",
            "ls_gk_rating": "home_cl_gk_rating",
            "ls_def_rating": "home_cl_def_rating",
            "ls_mid_rating": "home_cl_mid_rating",
            "ls_att_rating": "home_cl_att_rating",
            "ls_line_balance": "home_cl_line_balance",
        }
    )
    away_current = current_xi[current_xi["is_home"] == 0].drop(columns=["is_home", "team_id"]).rename(
        columns={
            "ls_xi_rating": "away_cl_xi_rating",
            "ls_weakest_starter": "away_cl_weakest_starter",
            "ls_gk_rating": "away_cl_gk_rating",
            "ls_def_rating": "away_cl_def_rating",
            "ls_mid_rating": "away_cl_mid_rating",
            "ls_att_rating": "away_cl_att_rating",
            "ls_line_balance": "away_cl_line_balance",
        }
    )

    baseline = build_lineup_strength_features(sched, engine, windows=windows, min_season=min_season)
    out = (
        sched[["fixture_id"]]
        .merge(home_current, on="fixture_id", how="left")
        .merge(away_current, on="fixture_id", how="left")
        .merge(baseline, on="fixture_id", how="left")
    )

    specs = [
        ("home_cl_xi_delta_long", "home_cl_xi_rating", "home_ls_xi_rating_long"),
        ("away_cl_xi_delta_long", "away_cl_xi_rating", "away_ls_xi_rating_long"),
        ("home_cl_xi_delta_all_10", "home_cl_xi_rating", "home_ls_xi_rating_all_10"),
        ("away_cl_xi_delta_all_10", "away_cl_xi_rating", "away_ls_xi_rating_all_10"),
        ("home_cl_xi_delta_venue_10", "home_cl_xi_rating", "home_ls_xi_rating_home_10"),
        ("away_cl_xi_delta_venue_10", "away_cl_xi_rating", "away_ls_xi_rating_away_10"),
        ("home_cl_att_delta_all_10", "home_cl_att_rating", "home_ls_att_rating_all_10"),
        ("away_cl_att_delta_all_10", "away_cl_att_rating", "away_ls_att_rating_all_10"),
        ("home_cl_def_delta_all_10", "home_cl_def_rating", "home_ls_def_rating_all_10"),
        ("away_cl_def_delta_all_10", "away_cl_def_rating", "away_ls_def_rating_all_10"),
        ("home_cl_weakest_delta_long", "home_cl_weakest_starter", "home_ls_weakest_starter_long"),
        ("away_cl_weakest_delta_long", "away_cl_weakest_starter", "away_ls_weakest_starter_long"),
    ]
    for out_col, left, right in specs:
        if left in out.columns and right in out.columns:
            out[out_col] = pd.to_numeric(out[left], errors="coerce") - pd.to_numeric(out[right], errors="coerce")

    diff_specs = [
        ("cl_xi_rating_diff", "home_cl_xi_rating", "away_cl_xi_rating"),
        ("cl_att_rating_diff", "home_cl_att_rating", "away_cl_att_rating"),
        ("cl_def_rating_diff", "home_cl_def_rating", "away_cl_def_rating"),
        ("cl_mid_rating_diff", "home_cl_mid_rating", "away_cl_mid_rating"),
        ("cl_line_balance_diff", "home_cl_line_balance", "away_cl_line_balance"),
        ("cl_xi_delta_long_diff", "home_cl_xi_delta_long", "away_cl_xi_delta_long"),
        ("cl_xi_delta_all_10_diff", "home_cl_xi_delta_all_10", "away_cl_xi_delta_all_10"),
        ("cl_att_delta_all_10_diff", "home_cl_att_delta_all_10", "away_cl_att_delta_all_10"),
        ("cl_def_delta_all_10_diff", "home_cl_def_delta_all_10", "away_cl_def_delta_all_10"),
    ]
    for out_col, left, right in diff_specs:
        if left in out.columns and right in out.columns:
            out[out_col] = pd.to_numeric(out[left], errors="coerce") - pd.to_numeric(out[right], errors="coerce")

    keep_cols = [
        "fixture_id",
        "home_cl_xi_rating",
        "away_cl_xi_rating",
        "home_cl_weakest_starter",
        "away_cl_weakest_starter",
        "home_cl_gk_rating",
        "away_cl_gk_rating",
        "home_cl_def_rating",
        "away_cl_def_rating",
        "home_cl_mid_rating",
        "away_cl_mid_rating",
        "home_cl_att_rating",
        "away_cl_att_rating",
        "home_cl_line_balance",
        "away_cl_line_balance",
        "home_cl_xi_delta_long",
        "away_cl_xi_delta_long",
        "home_cl_xi_delta_all_10",
        "away_cl_xi_delta_all_10",
        "home_cl_xi_delta_venue_10",
        "away_cl_xi_delta_venue_10",
        "home_cl_att_delta_all_10",
        "away_cl_att_delta_all_10",
        "home_cl_def_delta_all_10",
        "away_cl_def_delta_all_10",
        "home_cl_weakest_delta_long",
        "away_cl_weakest_delta_long",
        "cl_xi_rating_diff",
        "cl_att_rating_diff",
        "cl_def_rating_diff",
        "cl_mid_rating_diff",
        "cl_line_balance_diff",
        "cl_xi_delta_long_diff",
        "cl_xi_delta_all_10_diff",
        "cl_att_delta_all_10_diff",
        "cl_def_delta_all_10_diff",
    ]
    keep_cols = [c for c in keep_cols if c in out.columns]
    return out[keep_cols].copy()
