from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .baselines import add_market_baseline, blend_probs, build_simple_poisson_features
from .betting import build_best_bets, optimize_rule, summarize_bets, summarize_bets_by_league
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_by_league, evaluate_probs
from .features import build_result_form_features
from .ml import fit_catboost_outcome, predict_catboost_outcome
from .splits import temporal_split_by_league
from .settings import DEFAULT_CAL_DAYS, DEFAULT_GAP_DAYS, DEFAULT_VAL_DAYS


OUTPUT_PATH = Path("tmp/outcome_v4_2_leagueblend_roi.json")


def _optimize_weight(cal_market: np.ndarray, cal_base: np.ndarray, cal_df) -> tuple[float, dict]:
    best_w = 0.0
    best_metrics = None
    best_ll = None
    for w in np.linspace(0.0, 1.0, 21):
        probs = blend_probs(cal_market, cal_base, w)
        metrics = evaluate_probs(cal_df, probs, f"blend_{w:.2f}")
        ll = metrics["logloss"]
        if best_ll is None or ll < best_ll:
            best_ll = ll
            best_w = float(w)
            best_metrics = metrics
    return best_w, best_metrics


def _league_specific_blend(cal_df, val_df, cal_market, val_market, cal_cat, val_cat):
    cal_blend = np.zeros_like(cal_cat)
    val_blend = np.zeros_like(val_cat)
    weights = {}
    metrics = {}
    for league, g in cal_df.groupby("league", sort=True):
        cal_idx = g.index.to_numpy()
        val_idx = val_df.index[val_df["league"] == league].to_numpy()
        w, m = _optimize_weight(cal_market[cal_idx], cal_cat[cal_idx], g)
        weights[league] = w
        metrics[league] = m
        cal_blend[cal_idx] = blend_probs(cal_market[cal_idx], cal_cat[cal_idx], w)
        if len(val_idx):
            val_blend[val_idx] = blend_probs(val_market[val_idx], val_cat[val_idx], w)
    return weights, metrics, cal_blend, val_blend


def main() -> None:
    df = load_match_snapshot()
    df = add_market_baseline(df)
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)

    tr, cal, val = temporal_split_by_league(
        df,
        ts_col="date_utc",
        league_col="league_id",
        cal_days=DEFAULT_CAL_DAYS,
        val_days=DEFAULT_VAL_DAYS,
        gap_days=DEFAULT_GAP_DAYS,
    )

    model = fit_catboost_outcome(tr, cal)
    cal_market = cal[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    val_market = val[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    cal_cat = predict_catboost_outcome(model, cal)
    val_cat = predict_catboost_outcome(model, val)

    league_weights, league_metrics, cal_league_blend, val_league_blend = _league_specific_blend(
        cal, val, cal_market, val_market, cal_cat, val_cat
    )

    cat_rule, cat_cal_summary = optimize_rule(cal, cal_cat)
    blend_rule, blend_cal_summary = optimize_rule(cal, cal_league_blend)

    val_cat_bets = build_best_bets(val, val_cat, cat_rule)
    val_blend_bets = build_best_bets(val, val_league_blend, blend_rule)

    report = {
        "dataset": {
            "rows": int(len(df)),
            "train": int(len(tr)),
            "cal": int(len(cal)),
            "val": int(len(val)),
        },
        "league_blend": {
            "weights": league_weights,
            "cal_metrics": league_metrics,
        },
        "overall": {
            "market": evaluate_probs(val, val_market, "market"),
            "catboost_v41": evaluate_probs(val, val_cat, "catboost_v41"),
            "catboost_leagueblend_v42": evaluate_probs(val, val_league_blend, "catboost_leagueblend_v42"),
        },
        "by_league": {
            "market": evaluate_by_league(val, val_market, "market"),
            "catboost_v41": evaluate_by_league(val, val_cat, "catboost_v41"),
            "catboost_leagueblend_v42": evaluate_by_league(val, val_league_blend, "catboost_leagueblend_v42"),
        },
        "roi": {
            "catboost_v41": {
                "rule": cat_rule.__dict__,
                "cal": cat_cal_summary,
                "val": summarize_bets(val_cat_bets),
                "by_league": summarize_bets_by_league(val_cat_bets),
            },
            "catboost_leagueblend_v42": {
                "rule": blend_rule.__dict__,
                "cal": blend_cal_summary,
                "val": summarize_bets(val_blend_bets),
                "by_league": summarize_bets_by_league(val_blend_bets),
            },
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
