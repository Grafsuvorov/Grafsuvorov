from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .baselines import add_market_baseline, blend_probs, build_simple_poisson_features
from .advanced_features import add_market_context_features, build_match_stat_rolling_features
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_by_league, evaluate_probs
from .features import build_result_form_features
from .ml import fit_catboost_outcome, predict_catboost_outcome
from .splits import temporal_split_by_league
from .settings import DEFAULT_CAL_DAYS, DEFAULT_GAP_DAYS, DEFAULT_VAL_DAYS


OUTPUT_PATH = Path("tmp/outcome_v4_1_catboost.json")


def _optimize_two_way_blend(cal_base: np.ndarray, cal_market: np.ndarray, cal_df, label_prefix: str) -> tuple[float, dict]:
    best_w = 0.0
    best_metrics = None
    best_ll = None
    for w in np.linspace(0.0, 1.0, 21):
        probs = blend_probs(cal_market, cal_base, w)
        metrics = evaluate_probs(cal_df, probs, f"{label_prefix}_{w:.2f}")
        ll = metrics["logloss"]
        if best_ll is None or ll < best_ll:
            best_ll = ll
            best_w = float(w)
            best_metrics = metrics
    return best_w, best_metrics


def main() -> None:
    df = load_match_snapshot()
    df = add_market_baseline(df)
    df = add_market_context_features(df)
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)
    df = build_match_stat_rolling_features(df)

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
    cal_pois = cal[["p_away_pois", "p_draw_pois", "p_home_pois"]].to_numpy()
    val_pois = val[["p_away_pois", "p_draw_pois", "p_home_pois"]].to_numpy()
    cal_cat = predict_catboost_outcome(model, cal)
    val_cat = predict_catboost_outcome(model, val)

    best_pois_w, best_pois_cal = _optimize_two_way_blend(cal_pois, cal_market, cal, "pois_mkt")
    best_cat_w, best_cat_cal = _optimize_two_way_blend(cal_cat, cal_market, cal, "cat_mkt")
    val_pois_blend = blend_probs(val_market, val_pois, best_pois_w)
    val_cat_blend = blend_probs(val_market, val_cat, best_cat_w)

    report = {
        "dataset": {
            "rows": int(len(df)),
            "train": int(len(tr)),
            "cal": int(len(cal)),
            "val": int(len(val)),
        },
        "blend_choice": {
            "poisson_market_weight": best_pois_w,
            "poisson_market_cal": best_pois_cal,
            "cat_market_weight": best_cat_w,
            "cat_market_cal": best_cat_cal,
        },
        "overall": {
            "market": evaluate_probs(val, val_market, "market"),
            "poisson_v4": evaluate_probs(val, val_pois, "poisson_v4"),
            "poisson_market_v4": evaluate_probs(val, val_pois_blend, "poisson_market_v4"),
            "catboost_v41": evaluate_probs(val, val_cat, "catboost_v41"),
            "catboost_market_v41": evaluate_probs(val, val_cat_blend, "catboost_market_v41"),
        },
        "by_league": {
            "market": evaluate_by_league(val, val_market, "market"),
            "poisson_v4": evaluate_by_league(val, val_pois, "poisson_v4"),
            "poisson_market_v4": evaluate_by_league(val, val_pois_blend, "poisson_market_v4"),
            "catboost_v41": evaluate_by_league(val, val_cat, "catboost_v41"),
            "catboost_market_v41": evaluate_by_league(val, val_cat_blend, "catboost_market_v41"),
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
