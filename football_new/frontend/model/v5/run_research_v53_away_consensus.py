from __future__ import annotations

import json
from datetime import timedelta
from pathlib import Path

import numpy as np
import pandas as pd

from frontend.model.v4.baselines import build_simple_poisson_features
from frontend.model.v4.betting import build_best_bets, optimize_rule, summarize_bets, summarize_bets_by_league
from frontend.model.v4.features import build_result_form_features

from .baselines import add_timed_market_features
from .data_snapshot import load_v5_snapshot
from .features_v53 import build_v53_context_features
from .ml import fit_catboost_v53, predict_catboost_v53


OUTPUT_PATH = Path("tmp/outcome_v53_away_consensus.json")

TRAIN_DAYS = 540
CAL_DAYS = 120
VAL_DAYS = 30
STEP_DAYS = 30
MIN_TRAIN_ROWS = 1500
MIN_CAL_ROWS = 250
MIN_VAL_ROWS = 120


def _add_away_strength_votes(bets: pd.DataFrame) -> pd.DataFrame:
    out = bets.copy()
    for col in [
        "form_points_diff_5",
        "venue_points_diff_5",
        "adj_points_diff_5",
        "points_diff_table",
        "position_diff",
        "attack_vs_def_away_5",
        "attack_vs_def_home_5",
        "p_away_current",
        "p_home_current",
        "p_away_pois",
        "p_home_pois",
    ]:
        out[col] = pd.to_numeric(out[col], errors="coerce")

    out["market_away_fav"] = (out["p_away_current"] > out["p_home_current"]).astype(int)
    out["poisson_away_fav"] = (out["p_away_pois"] > out["p_home_pois"]).astype(int)
    out["form_away_fav"] = (out["form_points_diff_5"] < 0).astype(int)
    out["venue_away_fav"] = (out["venue_points_diff_5"] < 0).astype(int)
    out["adj_away_fav"] = (out["adj_points_diff_5"] < 0).astype(int)
    out["table_away_fav"] = (out["points_diff_table"] < 0).astype(int)
    out["position_away_fav"] = (out["position_diff"] < 0).astype(int)
    out["attack_away_fav"] = (out["attack_vs_def_away_5"] > out["attack_vs_def_home_5"]).astype(int)
    strength_cols = [
        "market_away_fav",
        "poisson_away_fav",
        "form_away_fav",
        "venue_away_fav",
        "adj_away_fav",
        "table_away_fav",
        "position_away_fav",
        "attack_away_fav",
    ]
    out["away_strength_votes"] = out[strength_cols].sum(axis=1)
    return out


def _apply_away_gate(
    bets: pd.DataFrame,
    min_votes: int,
    short_odds_cap: float,
) -> pd.DataFrame:
    out = _add_away_strength_votes(bets)
    is_away = out["bet_outcome"] == "Away"
    weak_away = is_away & (out["away_strength_votes"] < min_votes)
    overconfident_short_away = is_away & (out["away_strength_votes"] >= 8) & (out["bet_odds"] <= short_odds_cap)
    return out.loc[~(weak_away | overconfident_short_away)].copy()


def main() -> None:
    df = load_v5_snapshot()
    df = add_timed_market_features(df)
    if "date_utc" not in df.columns:
        df["date_utc"] = df["match_start_utc"]
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)
    df = build_v53_context_features(df)
    df = df.sort_values(["date_utc", "fixture_id"]).reset_index(drop=True)

    for a, b in [
        ("avg_odds_home_current", "avg_odds_home"),
        ("avg_odds_draw_current", "avg_odds_draw"),
        ("avg_odds_away_current", "avg_odds_away"),
    ]:
        if b not in df.columns:
            df[b] = df[a]

    max_date = df["date_utc"].max()
    min_date = df["date_utc"].min()

    configs = [
        {"min_votes": 4, "short_odds_cap": 2.10},
        {"min_votes": 5, "short_odds_cap": 2.10},
        {"min_votes": 5, "short_odds_cap": 2.15},
        {"min_votes": 5, "short_odds_cap": 2.20},
        {"min_votes": 6, "short_odds_cap": 2.10},
        {"min_votes": 6, "short_odds_cap": 2.15},
    ]
    all_results = []

    for cfg in configs:
        val_end = max_date
        windows = []
        all_kept = []
        while True:
            val_start = val_end - timedelta(days=VAL_DAYS)
            cal_end = val_start
            cal_start = cal_end - timedelta(days=CAL_DAYS)
            train_end = cal_start
            train_start = train_end - timedelta(days=TRAIN_DAYS)
            if train_start <= min_date:
                break

            tr = df[(df["date_utc"] > train_start) & (df["date_utc"] <= train_end)].copy().reset_index(drop=True)
            cal = df[(df["date_utc"] > cal_start) & (df["date_utc"] <= cal_end)].copy().reset_index(drop=True)
            val = df[(df["date_utc"] > val_start) & (df["date_utc"] <= val_end)].copy().reset_index(drop=True)
            if len(tr) < MIN_TRAIN_ROWS or len(cal) < MIN_CAL_ROWS or len(val) < MIN_VAL_ROWS:
                val_end = val_end - timedelta(days=STEP_DAYS)
                continue

            model = fit_catboost_v53(tr, cal)
            cal_probs = predict_catboost_v53(model, cal)
            val_probs = predict_catboost_v53(model, val)
            rule, cal_summary = optimize_rule(cal, cal_probs)
            raw_bets = build_best_bets(val, val_probs, rule)
            kept_bets = _apply_away_gate(raw_bets, cfg["min_votes"], cfg["short_odds_cap"])
            kept_bets["window"] = f"{val_start.date()}__{val_end.date()}"
            all_kept.append(kept_bets)
            windows.append(
                {
                    "window": f"{val_start.date()}__{val_end.date()}",
                    "rule": rule.__dict__,
                    "cal": cal_summary,
                    "raw": summarize_bets(raw_bets),
                    "gated": summarize_bets(kept_bets),
                }
            )
            val_end = val_end - timedelta(days=STEP_DAYS)

        bets = pd.concat(all_kept, ignore_index=True) if all_kept else pd.DataFrame()
        all_results.append(
            {
                "config": cfg,
                "aggregate": summarize_bets(bets),
                "by_league": summarize_bets_by_league(bets) if not bets.empty else [],
                "windows": windows,
            }
        )

    best = max(all_results, key=lambda x: (x["aggregate"]["roi"], x["aggregate"]["bets"]))
    report = {
        "tested_configs": all_results,
        "best": best,
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
