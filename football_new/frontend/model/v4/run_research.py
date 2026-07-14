from __future__ import annotations

import json

import numpy as np

from .baselines import add_market_baseline, blend_probs, build_simple_poisson_features
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_by_league, evaluate_probs
from .splits import temporal_split_by_league
from .settings import DEFAULT_CAL_DAYS, DEFAULT_GAP_DAYS, DEFAULT_VAL_DAYS, OUTPUT_PATH


def _optimize_weight(cal_market: np.ndarray, cal_pois: np.ndarray, cal_df) -> tuple[float, dict]:
    best_w = 0.0
    best_metrics = None
    best_ll = None
    for w in np.linspace(0.0, 1.0, 21):
        probs = blend_probs(cal_market, cal_pois, w)
        metrics = evaluate_probs(cal_df, probs, f"blend_{w:.2f}")
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

    tr, cal, val = temporal_split_by_league(
        df,
        ts_col="date_utc",
        league_col="league_id",
        cal_days=DEFAULT_CAL_DAYS,
        val_days=DEFAULT_VAL_DAYS,
        gap_days=DEFAULT_GAP_DAYS,
    )

    cal_market = cal[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    val_market = val[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    cal_pois = cal[["p_away_pois", "p_draw_pois", "p_home_pois"]].to_numpy()
    val_pois = val[["p_away_pois", "p_draw_pois", "p_home_pois"]].to_numpy()

    best_w, cal_best = _optimize_weight(cal_market, cal_pois, cal)
    val_blend = blend_probs(val_market, val_pois, best_w)

    report = {
        "dataset": {
            "rows": int(len(df)),
            "train": int(len(tr)),
            "cal": int(len(cal)),
            "val": int(len(val)),
        },
        "calibration_choice": {
            "best_poisson_weight": best_w,
            "best_cal_metrics": cal_best,
        },
        "overall": {
            "market": evaluate_probs(val, val_market, "market"),
            "poisson_v4": evaluate_probs(val, val_pois, "poisson_v4"),
            "blend_v4": evaluate_probs(val, val_blend, "blend_v4"),
        },
        "by_league": {
            "market": evaluate_by_league(val, val_market, "market"),
            "poisson_v4": evaluate_by_league(val, val_pois, "poisson_v4"),
            "blend_v4": evaluate_by_league(val, val_blend, "blend_v4"),
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
