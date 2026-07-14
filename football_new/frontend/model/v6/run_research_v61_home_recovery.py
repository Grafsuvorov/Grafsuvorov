from __future__ import annotations

import json
from collections import Counter
from datetime import timedelta
from pathlib import Path

import numpy as np
import pandas as pd

from frontend.model.v4.baselines import build_simple_poisson_features
from frontend.model.v4.features import build_result_form_features
from frontend.model.v4.ml import fit_catboost_binary
from frontend.model.v5.baselines import add_timed_market_features
from frontend.model.v5.data_snapshot import load_v5_snapshot
from frontend.model.v5.features_v53 import build_v53_context_features
from frontend.model.v5.ml import V5_3_FEATURE_COLS, V5_CATEGORICAL_COLS, fit_catboost_v53


OUTPUT_PATH = Path("tmp/outcome_v61_home_recovery.json")

TRAIN_DAYS = 540
CAL_DAYS = 120
VAL_DAYS = 30
STEP_DAYS = 30
MIN_TRAIN_ROWS = 1500
MIN_CAL_ROWS = 250
MIN_VAL_ROWS = 120


def _prepare_x(df: pd.DataFrame) -> pd.DataFrame:
    x = df[V5_3_FEATURE_COLS].copy()
    for col in V5_CATEGORICAL_COLS:
        x[col] = x[col].astype(str)
    return x


def _actual_idx(df: pd.DataFrame) -> np.ndarray:
    hg = pd.to_numeric(df["home_goals"], errors="coerce").fillna(0).to_numpy()
    ag = pd.to_numeric(df["away_goals"], errors="coerce").fillna(0).to_numpy()
    y = np.zeros(len(df), dtype="int64")
    y[ag > hg] = 0
    y[ag == hg] = 1
    y[hg > ag] = 2
    return y


def _clip_binary(p: np.ndarray) -> np.ndarray:
    return np.clip(np.asarray(p, dtype="float64"), 1e-6, 1.0 - 1e-6)


def _compose_probs(p_draw: np.ndarray, p_home_not_draw: np.ndarray) -> np.ndarray:
    p_draw = _clip_binary(p_draw)
    p_home_not_draw = _clip_binary(p_home_not_draw)
    p_home = (1.0 - p_draw) * p_home_not_draw
    p_away = (1.0 - p_draw) * (1.0 - p_home_not_draw)
    out = np.column_stack([p_away, p_draw, p_home])
    out = np.clip(out, 1e-6, 1.0 - 1e-6)
    out /= out.sum(axis=1, keepdims=True)
    return out


def _summary(actual: np.ndarray, pred: np.ndarray) -> dict:
    draw_pred = pred == 1
    draw_actual = actual == 1
    return {
        "matches": int(len(actual)),
        "correct": int(np.sum(pred == actual)),
        "accuracy": round(float(np.mean(pred == actual)), 6),
        "draw_predictions": int(np.sum(draw_pred)),
        "draw_precision": round(float(np.mean(draw_actual[draw_pred])), 6) if np.any(draw_pred) else 0.0,
        "draw_recall": round(float(np.sum(draw_pred & draw_actual) / np.sum(draw_actual)), 6) if np.any(draw_actual) else 0.0,
    }


def _apply_home_recovery(
    v55_probs: np.ndarray,
    market_probs: np.ndarray,
    home_recovery_prob: np.ndarray,
    max_v55_conf: float,
    min_market_home: float,
    min_market_gap: float,
    min_home_recovery_prob: float,
) -> tuple[np.ndarray, np.ndarray]:
    pred = np.argmax(v55_probs, axis=1).copy()
    conf = np.max(v55_probs, axis=1)
    market_pred = np.argmax(market_probs, axis=1)
    market_home = market_probs[:, 2]
    market_gap = market_probs[:, 2] - np.maximum(market_probs[:, 0], market_probs[:, 1])

    mask = (
        (pred != 2)
        & (conf < max_v55_conf)
        & (market_pred == 2)
        & (market_home >= min_market_home)
        & (market_gap >= min_market_gap)
        & (home_recovery_prob >= min_home_recovery_prob)
    )
    pred[mask] = 2
    return pred, mask


def main() -> None:
    df = load_v5_snapshot()
    df = add_timed_market_features(df)
    if "date_utc" not in df.columns:
        df["date_utc"] = df["match_start_utc"]
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)
    df = build_v53_context_features(df)
    df = df.sort_values(["date_utc", "fixture_id"]).reset_index(drop=True)
    df["actual_idx"] = _actual_idx(df)

    max_date = df["date_utc"].max()
    min_date = df["date_utc"].min()

    all_actual: list[np.ndarray] = []
    all_market_pred: list[np.ndarray] = []
    all_v55_pred: list[np.ndarray] = []
    all_corrected_pred: list[np.ndarray] = []
    cfg_counter: Counter[str] = Counter()
    windows: list[dict] = []

    max_conf_grid = (0.42, 0.45, 0.48)
    market_home_grid = (0.42, 0.45, 0.48)
    market_gap_grid = (0.02, 0.04, 0.06)
    recovery_prob_grid = (0.50, 0.55, 0.60)

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

        x_tr = _prepare_x(tr)
        x_cal = _prepare_x(cal)
        x_val = _prepare_x(val)

        # v5.5 core
        draw_y_tr = (tr["actual_idx"].to_numpy(dtype="int64") == 1).astype("int64")
        draw_y_cal = (cal["actual_idx"].to_numpy(dtype="int64") == 1).astype("int64")
        draw_model = fit_catboost_binary(x_tr, draw_y_tr, x_cal, draw_y_cal)

        side_tr = tr[tr["actual_idx"] != 1].copy().reset_index(drop=True)
        side_cal = cal[cal["actual_idx"] != 1].copy().reset_index(drop=True)
        x_side_tr = _prepare_x(side_tr)
        x_side_cal = _prepare_x(side_cal)
        side_y_tr = (side_tr["actual_idx"].to_numpy(dtype="int64") == 2).astype("int64")
        side_y_cal = (side_cal["actual_idx"].to_numpy(dtype="int64") == 2).astype("int64")
        side_model = fit_catboost_binary(x_side_tr, side_y_tr, x_side_cal, side_y_cal)

        cal_v55_probs = _compose_probs(
            draw_model.predict_proba(x_cal)[:, 1],
            side_model.predict_proba(x_cal)[:, 1],
        )
        val_v55_probs = _compose_probs(
            draw_model.predict_proba(x_val)[:, 1],
            side_model.predict_proba(x_val)[:, 1],
        )

        # separate binary home recovery model
        home_y_tr = (tr["actual_idx"].to_numpy(dtype="int64") == 2).astype("int64")
        home_y_cal = (cal["actual_idx"].to_numpy(dtype="int64") == 2).astype("int64")
        home_model = fit_catboost_binary(x_tr, home_y_tr, x_cal, home_y_cal)
        cal_home_recovery = _clip_binary(home_model.predict_proba(x_cal)[:, 1])
        val_home_recovery = _clip_binary(home_model.predict_proba(x_val)[:, 1])

        cal_market_probs = cal[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy(dtype="float64")
        val_market_probs = val[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy(dtype="float64")

        cal_actual = cal["actual_idx"].to_numpy(dtype="int64")
        val_actual = val["actual_idx"].to_numpy(dtype="int64")
        val_v55_pred = np.argmax(val_v55_probs, axis=1)
        val_market_pred = np.argmax(val_market_probs, axis=1)

        best_cfg = None
        best_score = -1.0
        for max_conf in max_conf_grid:
            for min_market_home in market_home_grid:
                for min_market_gap in market_gap_grid:
                    for min_home_recovery_prob in recovery_prob_grid:
                        cal_pred, _ = _apply_home_recovery(
                            cal_v55_probs,
                            cal_market_probs,
                            cal_home_recovery,
                            max_conf,
                            min_market_home,
                            min_market_gap,
                            min_home_recovery_prob,
                        )
                        acc = float(np.mean(cal_pred == cal_actual))
                        if acc > best_score:
                            best_score = acc
                            best_cfg = (
                                max_conf,
                                min_market_home,
                                min_market_gap,
                                min_home_recovery_prob,
                            )

        assert best_cfg is not None
        val_corrected_pred, recovered_mask = _apply_home_recovery(
            val_v55_probs,
            val_market_probs,
            val_home_recovery,
            *best_cfg,
        )

        cfg_counter[str(best_cfg)] += 1
        all_actual.append(val_actual)
        all_market_pred.append(val_market_pred)
        all_v55_pred.append(val_v55_pred)
        all_corrected_pred.append(val_corrected_pred)

        windows.append(
            {
                "window": f"{val_start.date()}__{val_end.date()}",
                "chosen_cfg": {
                    "max_v55_conf": best_cfg[0],
                    "min_market_home": best_cfg[1],
                    "min_market_gap": best_cfg[2],
                    "min_home_recovery_prob": best_cfg[3],
                },
                "recovered_matches": int(np.sum(recovered_mask)),
                "v55": _summary(val_actual, val_v55_pred),
                "corrected": _summary(val_actual, val_corrected_pred),
                "market": _summary(val_actual, val_market_pred),
            }
        )
        val_end = val_end - timedelta(days=STEP_DAYS)

    actual = np.concatenate(all_actual)
    market_pred = np.concatenate(all_market_pred)
    v55_pred = np.concatenate(all_v55_pred)
    corrected_pred = np.concatenate(all_corrected_pred)

    report = {
        "overall": {
            "market": _summary(actual, market_pred),
            "v55": _summary(actual, v55_pred),
            "v61_home_recovery": _summary(actual, corrected_pred),
        },
        "chosen_config_counts": dict(cfg_counter),
        "windows": windows,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
