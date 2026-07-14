from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .baselines import add_market_baseline, blend_probs, build_simple_poisson_features
from .calibration import apply_multiclass_calibrator, fit_multiclass_calibrator
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_by_league, evaluate_probs, outcome_target
from .features import build_result_form_features
from .ml_base import fit_catboost_base, predict_catboost_base
from .splits import temporal_split_by_league
from .settings import DEFAULT_CAL_DAYS, DEFAULT_GAP_DAYS, DEFAULT_VAL_DAYS


OUTPUT_PATH = Path("tmp/outcome_v4_9_calibrated.json")


def _optimize_two_way_blend(
    cal_market: np.ndarray,
    cal_base: np.ndarray,
    cal_y: np.ndarray,
) -> tuple[float, dict]:
    best_w = 0.0
    best_metrics = None
    best_ll = None
    for w in np.linspace(0.0, 1.0, 21):
        probs = blend_probs(cal_market, cal_base, w)
        metrics = evaluate_probs_from_y(cal_y, probs, f"blend_{w:.2f}")
        ll = metrics["logloss"]
        if best_ll is None or ll < best_ll:
            best_ll = ll
            best_w = float(w)
            best_metrics = metrics
    return best_w, best_metrics


def evaluate_probs_from_y(y: np.ndarray, probs: np.ndarray, label: str) -> dict:
    from .evaluate import multiclass_accuracy, multiclass_brier, multiclass_logloss, topclass_calibration_gap

    return {
        "label": label,
        "n": int(len(y)),
        "logloss": round(multiclass_logloss(y, probs), 6),
        "accuracy": round(multiclass_accuracy(y, probs), 6),
        "brier": round(multiclass_brier(y, probs), 6),
        "topclass_calibration_gap": round(topclass_calibration_gap(y, probs), 6),
    }


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

    model = fit_catboost_base(tr, cal)

    cal_y = outcome_target(cal)
    val_market = val[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    cal_market = cal[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    val_base = predict_catboost_base(model, val)
    cal_base = predict_catboost_base(model, cal)

    best_w, best_cal_blend = _optimize_two_way_blend(cal_market, cal_base, cal_y)
    val_blend = blend_probs(val_market, val_base, best_w)
    cal_blend = blend_probs(cal_market, cal_base, best_w)

    base_calibrator = fit_multiclass_calibrator(cal_base, cal_y)
    blend_calibrator = fit_multiclass_calibrator(cal_blend, cal_y)
    val_base_cal = apply_multiclass_calibrator(base_calibrator, val_base)
    val_blend_cal = apply_multiclass_calibrator(blend_calibrator, val_blend)

    report = {
        "dataset": {
            "rows": int(len(df)),
            "train": int(len(tr)),
            "cal": int(len(cal)),
            "val": int(len(val)),
        },
        "blend_choice": {
            "cat_market_weight": best_w,
            "cat_market_cal": best_cal_blend,
        },
        "overall": {
            "market": evaluate_probs(val, val_market, "market"),
            "catboost_base_v41": evaluate_probs(val, val_base, "catboost_base_v41"),
            "catboost_base_cal_v49": evaluate_probs(val, val_base_cal, "catboost_base_cal_v49"),
            "catboost_market_blend_v49": evaluate_probs(val, val_blend, "catboost_market_blend_v49"),
            "catboost_market_blend_cal_v49": evaluate_probs(val, val_blend_cal, "catboost_market_blend_cal_v49"),
        },
        "by_league": {
            "market": evaluate_by_league(val, val_market, "market"),
            "catboost_base_v41": evaluate_by_league(val, val_base, "catboost_base_v41"),
            "catboost_base_cal_v49": evaluate_by_league(val, val_base_cal, "catboost_base_cal_v49"),
            "catboost_market_blend_v49": evaluate_by_league(val, val_blend, "catboost_market_blend_v49"),
            "catboost_market_blend_cal_v49": evaluate_by_league(val, val_blend_cal, "catboost_market_blend_cal_v49"),
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
