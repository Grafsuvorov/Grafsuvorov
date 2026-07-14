from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .baselines import add_market_baseline, blend_probs, build_simple_poisson_features
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_by_league, evaluate_probs
from .features import add_draw_disagreement_features, build_result_form_features
from .ml_focus import fit_catboost_focus, predict_catboost_focus
from .splits import temporal_split_by_league
from .settings import DEFAULT_CAL_DAYS, DEFAULT_GAP_DAYS, DEFAULT_VAL_DAYS


OUTPUT_PATH = Path("tmp/outcome_v4_1_focus.json")


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
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)
    df = add_draw_disagreement_features(df)

    tr, cal, val = temporal_split_by_league(
        df,
        ts_col="date_utc",
        league_col="league_id",
        cal_days=DEFAULT_CAL_DAYS,
        val_days=DEFAULT_VAL_DAYS,
        gap_days=DEFAULT_GAP_DAYS,
    )

    model = fit_catboost_focus(tr, cal)

    cal_market = cal[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    val_market = val[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    cal_focus = predict_catboost_focus(model, cal)
    val_focus = predict_catboost_focus(model, val)

    best_w, best_cal = _optimize_two_way_blend(cal_focus, cal_market, cal, "focus_mkt")
    val_blend = blend_probs(val_market, val_focus, best_w)

    report = {
        "dataset": {
            "rows": int(len(df)),
            "train": int(len(tr)),
            "cal": int(len(cal)),
            "val": int(len(val)),
        },
        "blend_choice": {
            "focus_market_weight": best_w,
            "focus_market_cal": best_cal,
        },
        "overall": {
            "market": evaluate_probs(val, val_market, "market"),
            "catboost_focus_v41": evaluate_probs(val, val_focus, "catboost_focus_v41"),
            "catboost_focus_market_v41": evaluate_probs(val, val_blend, "catboost_focus_market_v41"),
        },
        "by_league": {
            "market": evaluate_by_league(val, val_market, "market"),
            "catboost_focus_v41": evaluate_by_league(val, val_focus, "catboost_focus_v41"),
            "catboost_focus_market_v41": evaluate_by_league(val, val_blend, "catboost_focus_market_v41"),
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

