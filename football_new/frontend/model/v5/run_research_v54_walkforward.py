from __future__ import annotations

import json
from datetime import timedelta
from pathlib import Path

import numpy as np

from frontend.model.v4.baselines import build_simple_poisson_features
from frontend.model.v4.evaluate import evaluate_probs
from frontend.model.v4.features import build_result_form_features

from .baselines import add_timed_market_features
from .data_snapshot import load_v5_snapshot
from .features_v53 import build_v53_context_features
from .features_v54 import build_v54_xg_features
from .ml import (
    fit_catboost_v53,
    fit_catboost_v54,
    predict_catboost_v53,
    predict_catboost_v54,
)


OUTPUT_PATH = Path("tmp/outcome_v5_4_walkforward.json")

TRAIN_DAYS = 540
CAL_DAYS = 120
VAL_DAYS = 30
STEP_DAYS = 30
MIN_TRAIN_ROWS = 1500
MIN_CAL_ROWS = 250
MIN_VAL_ROWS = 120


def main() -> None:
    df = load_v5_snapshot()
    df = add_timed_market_features(df)
    if "date_utc" not in df.columns:
        df["date_utc"] = df["match_start_utc"]
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)
    df = build_v53_context_features(df)
    df = build_v54_xg_features(df)
    df = df.sort_values(["date_utc", "fixture_id"]).reset_index(drop=True)

    max_date = df["date_utc"].max()
    min_date = df["date_utc"].min()

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

        market_probs = val[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy()

        model_v53 = fit_catboost_v53(tr, cal)
        probs_v53 = predict_catboost_v53(model_v53, val)

        model_v54 = fit_catboost_v54(tr, cal)
        probs_v54 = predict_catboost_v54(model_v54, val)

        windows.append(
            {
                "window": f"{val_start.date()}__{val_end.date()}",
                "n_val": int(len(val)),
                "overall": {
                    "market": evaluate_probs(val, market_probs, "market"),
                    "v5_3_catboost": evaluate_probs(val, probs_v53, "v5_3_catboost"),
                    "v5_4_catboost": evaluate_probs(val, probs_v54, "v5_4_catboost"),
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
            "v5_3_catboost": _aggregate("v5_3_catboost"),
            "v5_4_catboost": _aggregate("v5_4_catboost"),
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
