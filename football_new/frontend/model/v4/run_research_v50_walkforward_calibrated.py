from __future__ import annotations

import json
from datetime import timedelta
from pathlib import Path

import numpy as np
import pandas as pd

from .baselines import add_market_baseline, blend_probs, build_simple_poisson_features
from .calibration import apply_multiclass_calibrator, fit_multiclass_calibrator
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_probs, outcome_target
from .features import build_result_form_features
from .ml_base import fit_catboost_base, predict_catboost_base


OUTPUT_PATH = Path("tmp/outcome_v4_50_walkforward_calibrated.json")

TRAIN_DAYS = 540
CAL_DAYS = 120
VAL_DAYS = 30
STEP_DAYS = 30
MIN_TRAIN_ROWS = 1500
MIN_CAL_ROWS = 250
MIN_VAL_ROWS = 120


def _optimize_weight(cal_market: np.ndarray, cal_base: np.ndarray, cal_df: pd.DataFrame) -> tuple[float, dict]:
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


def main() -> None:
    df = load_match_snapshot()
    df = add_market_baseline(df)
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)
    df = df.sort_values(["date_utc", "fixture_id"]).reset_index(drop=True)

    max_date = pd.to_datetime(df["date_utc"].max(), utc=True)
    min_date = pd.to_datetime(df["date_utc"].min(), utc=True)

    windows: list[dict] = []
    val_end = max_date
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

        model = fit_catboost_base(tr, cal)
        cal_market = cal[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
        val_market = val[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
        cal_base = predict_catboost_base(model, cal)
        val_base = predict_catboost_base(model, val)

        best_w, best_cal_blend = _optimize_weight(cal_market, cal_base, cal)
        cal_blend = blend_probs(cal_market, cal_base, best_w)
        val_blend = blend_probs(val_market, val_base, best_w)

        cal_y = outcome_target(cal)
        base_calibrator = fit_multiclass_calibrator(cal_base, cal_y)
        blend_calibrator = fit_multiclass_calibrator(cal_blend, cal_y)
        val_base_cal = apply_multiclass_calibrator(base_calibrator, val_base)
        val_blend_cal = apply_multiclass_calibrator(blend_calibrator, val_blend)

        windows.append(
            {
                "window": f"{val_start.date()}__{val_end.date()}",
                "n_val": int(len(val)),
                "blend_choice": {
                    "weight": best_w,
                    "cal": best_cal_blend,
                },
                "overall": {
                    "market": evaluate_probs(val, val_market, "market"),
                    "base": evaluate_probs(val, val_base, "base"),
                    "base_cal": evaluate_probs(val, val_base_cal, "base_cal"),
                    "blend": evaluate_probs(val, val_blend, "blend"),
                    "blend_cal": evaluate_probs(val, val_blend_cal, "blend_cal"),
                },
            }
        )
        val_end = val_end - timedelta(days=STEP_DAYS)

    def _aggregate(model_key: str) -> dict:
        vals = [w["overall"][model_key] for w in windows]
        if not vals:
            return {}
        return {
            "windows": len(vals),
            "avg_logloss": round(float(np.mean([v["logloss"] for v in vals])), 6),
            "avg_accuracy": round(float(np.mean([v["accuracy"] for v in vals])), 6),
            "avg_brier": round(float(np.mean([v["brier"] for v in vals])), 6),
            "avg_topclass_calibration_gap": round(
                float(np.mean([v["topclass_calibration_gap"] for v in vals])),
                6,
            ),
        }

    report = {
        "config": {
            "train_days": TRAIN_DAYS,
            "cal_days": CAL_DAYS,
            "val_days": VAL_DAYS,
            "step_days": STEP_DAYS,
        },
        "windows": windows,
        "aggregate": {
            "market": _aggregate("market"),
            "base": _aggregate("base"),
            "base_cal": _aggregate("base_cal"),
            "blend": _aggregate("blend"),
            "blend_cal": _aggregate("blend_cal"),
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
