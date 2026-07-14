from __future__ import annotations

import json
from datetime import timedelta
from pathlib import Path

import numpy as np
import pandas as pd

from frontend.model.v4.ml import fit_catboost_binary
from frontend.model.v4.baselines import build_simple_poisson_features
from frontend.model.v4.features import build_result_form_features

from .baselines import add_timed_market_features
from .data_snapshot import load_v5_snapshot
from .features_v53 import build_v53_context_features
from .ml import V5_3_FEATURE_COLS, V5_CATEGORICAL_COLS, fit_catboost_v53, predict_catboost_v53


OUTPUT_PATH = Path("tmp/outcome_v55_draw_side.json")

TRAIN_DAYS = 540
CAL_DAYS = 120
VAL_DAYS = 30
STEP_DAYS = 30
MIN_TRAIN_ROWS = 1500
MIN_CAL_ROWS = 250
MIN_VAL_ROWS = 120

OUTCOMES = ["Away", "Draw", "Home"]


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


def _confusion(actual: np.ndarray, pred: np.ndarray) -> list[dict]:
    rows: list[dict] = []
    for actual_idx, actual_name in enumerate(OUTCOMES):
        mask = actual == actual_idx
        total = int(np.sum(mask))
        row = {"actual": actual_name}
        for pred_idx, pred_name in enumerate(OUTCOMES):
            count = int(np.sum(pred[mask] == pred_idx))
            row[pred_name] = count
            row[f"{pred_name}_share"] = round(count / total, 6) if total else 0.0
        rows.append(row)
    return rows


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

    all_base_actual: list[np.ndarray] = []
    all_base_pred: list[np.ndarray] = []
    all_market_pred: list[np.ndarray] = []
    all_ds_pred: list[np.ndarray] = []
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

        actual = val["actual_idx"].to_numpy(dtype="int64")

        base_model = fit_catboost_v53(tr, cal)
        base_probs = predict_catboost_v53(base_model, val)
        base_pred = np.argmax(base_probs, axis=1)

        market_probs = val[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy(dtype="float64")
        market_pred = np.argmax(market_probs, axis=1)

        x_tr = _prepare_x(tr)
        x_cal = _prepare_x(cal)
        x_val = _prepare_x(val)

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

        val_draw = _clip_binary(draw_model.predict_proba(x_val)[:, 1])
        val_home_side = _clip_binary(side_model.predict_proba(x_val)[:, 1])
        ds_probs = _compose_probs(val_draw, val_home_side)
        ds_pred = np.argmax(ds_probs, axis=1)

        all_base_actual.append(actual)
        all_base_pred.append(base_pred)
        all_market_pred.append(market_pred)
        all_ds_pred.append(ds_pred)

        windows.append(
            {
                "window": f"{val_start.date()}__{val_end.date()}",
                "n": int(len(val)),
                "base": _summary(actual, base_pred),
                "draw_side": _summary(actual, ds_pred),
                "market": _summary(actual, market_pred),
            }
        )
        val_end = val_end - timedelta(days=STEP_DAYS)

    actual = np.concatenate(all_base_actual)
    base_pred = np.concatenate(all_base_pred)
    ds_pred = np.concatenate(all_ds_pred)
    market_pred = np.concatenate(all_market_pred)

    report = {
        "overall": {
            "base_v53": _summary(actual, base_pred),
            "draw_side_v55": _summary(actual, ds_pred),
            "market": _summary(actual, market_pred),
        },
        "confusion": {
            "base_v53": _confusion(actual, base_pred),
            "draw_side_v55": _confusion(actual, ds_pred),
            "market": _confusion(actual, market_pred),
        },
        "windows": windows,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
