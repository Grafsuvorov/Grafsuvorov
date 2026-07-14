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
from frontend.model.v5.ml import V5_3_FEATURE_COLS, V5_CATEGORICAL_COLS


OUTPUT_PATH = Path("tmp/outcome_v62_predictor.json")
PREDICTIONS_PATH = Path("tmp/outcome_v62_predictions.csv")

TRAIN_DAYS = 540
CAL_DAYS = 120
VAL_DAYS = 30
STEP_DAYS = 30
MIN_TRAIN_ROWS = 1500
MIN_CAL_ROWS = 250
MIN_VAL_ROWS = 120

TARGET_LEAGUES = {"La Liga", "Ligue 1"}
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


def _apply_home_correction(
    pred: np.ndarray,
    probs: np.ndarray,
    market_probs: np.ndarray,
    leagues: pd.Series,
    max_conf: float,
    min_market_home: float,
    min_home_gap: float,
) -> tuple[np.ndarray, np.ndarray]:
    pred = pred.copy()
    model_conf = probs.max(axis=1)
    market_pred = np.argmax(market_probs, axis=1)
    market_home = market_probs[:, 2]
    market_gap = market_probs[:, 2] - np.maximum(market_probs[:, 0], market_probs[:, 1])
    in_target = np.array([x in TARGET_LEAGUES for x in leagues.astype(str).to_numpy()])
    mask = (
        in_target
        & (pred != 2)
        & (model_conf < max_conf)
        & (market_pred == 2)
        & (market_home >= min_market_home)
        & (market_gap >= min_home_gap)
    )
    pred[mask] = 2
    return pred, mask


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

    cfg_grid = [
        (0.40, 0.36, 0.01),
        (0.42, 0.36, 0.01),
        (0.45, 0.36, 0.01),
        (0.42, 0.38, 0.01),
        (0.45, 0.38, 0.01),
        (0.45, 0.40, 0.02),
        (0.48, 0.40, 0.02),
    ]

    max_date = df["date_utc"].max()
    min_date = df["date_utc"].min()

    all_actual: list[np.ndarray] = []
    all_market_pred: list[np.ndarray] = []
    all_v62_pred: list[np.ndarray] = []
    prediction_rows: list[pd.DataFrame] = []
    chosen_counts: Counter[str] = Counter()
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

        cal_probs = _compose_probs(
            draw_model.predict_proba(x_cal)[:, 1],
            side_model.predict_proba(x_cal)[:, 1],
        )
        val_probs = _compose_probs(
            draw_model.predict_proba(x_val)[:, 1],
            side_model.predict_proba(x_val)[:, 1],
        )

        cal_market = cal[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy(dtype="float64")
        val_market = val[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy(dtype="float64")

        cal_actual = cal["actual_idx"].to_numpy(dtype="int64")
        val_actual = val["actual_idx"].to_numpy(dtype="int64")
        cal_pred = np.argmax(cal_probs, axis=1)
        val_pred = np.argmax(val_probs, axis=1)
        val_market_pred = np.argmax(val_market, axis=1)

        best_cfg = None
        best_acc = -1.0
        for cfg in cfg_grid:
            corrected, _ = _apply_home_correction(cal_pred, cal_probs, cal_market, cal["league"], *cfg)
            acc = float(np.mean(corrected == cal_actual))
            if acc > best_acc:
                best_acc = acc
                best_cfg = cfg
        assert best_cfg is not None

        corrected_pred, recovered_mask = _apply_home_correction(
            val_pred,
            val_probs,
            val_market,
            val["league"],
            *best_cfg,
        )

        chosen_counts[str(best_cfg)] += 1
        all_actual.append(val_actual)
        all_market_pred.append(val_market_pred)
        all_v62_pred.append(corrected_pred)

        out = val[["fixture_id", "date_utc", "league"]].copy()
        if "home_team" in val.columns and "away_team" in val.columns:
            out["match"] = val["home_team"].astype(str) + " - " + val["away_team"].astype(str)
        out["actual_idx"] = val_actual
        out["actual_outcome"] = [OUTCOMES[i] for i in val_actual]
        out["v62_pred_idx"] = corrected_pred
        out["v62_pred"] = [OUTCOMES[i] for i in corrected_pred]
        out["market_pred"] = [OUTCOMES[i] for i in val_market_pred]
        out["v62_conf"] = val_probs.max(axis=1)
        out["market_conf"] = val_market.max(axis=1)
        out["recovered_home_flag"] = recovered_mask.astype(int)
        out["window"] = f"{val_start.date()}__{val_end.date()}"
        prediction_rows.append(out)

        windows.append(
            {
                "window": f"{val_start.date()}__{val_end.date()}",
                "chosen_cfg": {
                    "max_conf": best_cfg[0],
                    "min_market_home": best_cfg[1],
                    "min_home_gap": best_cfg[2],
                },
                "recovered_matches": int(np.sum(recovered_mask)),
                "v62": _summary(val_actual, corrected_pred),
                "market": _summary(val_actual, val_market_pred),
            }
        )
        val_end = val_end - timedelta(days=STEP_DAYS)

    actual = np.concatenate(all_actual)
    market_pred = np.concatenate(all_market_pred)
    v62_pred = np.concatenate(all_v62_pred)

    pred_df = pd.concat(prediction_rows, ignore_index=True)
    pred_df.to_csv(PREDICTIONS_PATH, index=False)

    by_league = []
    for league, g in pred_df.groupby("league", sort=True):
        actual_l = g["actual_idx"].to_numpy(dtype="int64")
        v62_l = g["v62_pred_idx"].to_numpy(dtype="int64")
        market_l = np.array([OUTCOMES.index(x) for x in g["market_pred"].tolist()], dtype="int64")
        by_league.append(
            {
                "league": league,
                "v62_accuracy": round(float(np.mean(v62_l == actual_l)), 6),
                "market_accuracy": round(float(np.mean(market_l == actual_l)), 6),
                "recovered_matches": int(g["recovered_home_flag"].sum()),
            }
        )

    report = {
        "overall": {
            "v62_predictor": _summary(actual, v62_pred),
            "market": _summary(actual, market_pred),
        },
        "by_league": by_league,
        "chosen_config_counts": dict(chosen_counts),
        "windows": windows,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
