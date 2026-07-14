from __future__ import annotations

import json
from collections import Counter, defaultdict
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
from frontend.model.v5.ml import V5_3_FEATURE_COLS, V5_CATEGORICAL_COLS, fit_catboost_v53, predict_catboost_v53


OUTPUT_PATH = Path("tmp/outcome_v60_routing.json")

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


def _accuracy(actual: np.ndarray, pred: np.ndarray) -> float:
    return float(np.mean(actual == pred)) if len(actual) else 0.0


def _summary(actual: np.ndarray, pred: np.ndarray) -> dict:
    draw_pred = pred == 1
    draw_actual = actual == 1
    return {
        "matches": int(len(actual)),
        "correct": int(np.sum(pred == actual)),
        "accuracy": round(_accuracy(actual, pred), 6),
        "draw_predictions": int(np.sum(draw_pred)),
        "draw_precision": round(float(np.mean(draw_actual[draw_pred])), 6) if np.any(draw_pred) else 0.0,
        "draw_recall": round(float(np.sum(draw_pred & draw_actual) / np.sum(draw_actual)), 6) if np.any(draw_actual) else 0.0,
    }


def _best_model_by_league(
    leagues: pd.Series,
    actual: np.ndarray,
    preds: dict[str, np.ndarray],
) -> dict[str, str]:
    choices: dict[str, str] = {}
    tmp = pd.DataFrame({"league": leagues.to_numpy(), "actual": actual})
    for name, pred in preds.items():
        tmp[name] = pred
    for league, g in tmp.groupby("league", sort=True):
        scores = {
            name: _accuracy(g["actual"].to_numpy(dtype="int64"), g[name].to_numpy(dtype="int64"))
            for name in preds
        }
        # deterministic tie-breaker favors model over market only if strictly better
        best_name = max(
            scores.items(),
            key=lambda kv: (
                kv[1],
                1 if kv[0] == "market" else 0,
                1 if kv[0] == "v5_3" else 0,
                1 if kv[0] == "v5_5" else 0,
            ),
        )[0]
        choices[str(league)] = best_name
    return choices


def _apply_routing(
    leagues: pd.Series,
    choices: dict[str, str],
    preds: dict[str, np.ndarray],
) -> np.ndarray:
    out = np.zeros(len(leagues), dtype="int64")
    for i, league in enumerate(leagues.astype(str).to_numpy()):
        out[i] = int(preds[choices[league]][i])
    return out


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
    all_v53_pred: list[np.ndarray] = []
    all_v55_pred: list[np.ndarray] = []
    all_routed_pred: list[np.ndarray] = []
    route_counts: Counter[str] = Counter()
    route_by_league: dict[str, Counter[str]] = defaultdict(Counter)
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

        cal_actual = cal["actual_idx"].to_numpy(dtype="int64")
        val_actual = val["actual_idx"].to_numpy(dtype="int64")

        base_model = fit_catboost_v53(tr, cal)
        cal_v53_probs = predict_catboost_v53(base_model, cal)
        val_v53_probs = predict_catboost_v53(base_model, val)
        cal_v53_pred = np.argmax(cal_v53_probs, axis=1)
        val_v53_pred = np.argmax(val_v53_probs, axis=1)

        cal_market_probs = cal[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy(dtype="float64")
        val_market_probs = val[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy(dtype="float64")
        cal_market_pred = np.argmax(cal_market_probs, axis=1)
        val_market_pred = np.argmax(val_market_probs, axis=1)

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

        cal_draw = _clip_binary(draw_model.predict_proba(x_cal)[:, 1])
        val_draw = _clip_binary(draw_model.predict_proba(x_val)[:, 1])
        cal_home_side = _clip_binary(side_model.predict_proba(x_cal)[:, 1])
        val_home_side = _clip_binary(side_model.predict_proba(x_val)[:, 1])
        cal_v55_pred = np.argmax(_compose_probs(cal_draw, cal_home_side), axis=1)
        val_v55_pred = np.argmax(_compose_probs(val_draw, val_home_side), axis=1)

        choices = _best_model_by_league(
            cal["league"],
            cal_actual,
            {"market": cal_market_pred, "v5_3": cal_v53_pred, "v5_5": cal_v55_pred},
        )
        routed_pred = _apply_routing(
            val["league"],
            choices,
            {"market": val_market_pred, "v5_3": val_v53_pred, "v5_5": val_v55_pred},
        )

        route_counts.update(choices.values())
        for league, model_name in choices.items():
            route_by_league[league][model_name] += 1

        all_actual.append(val_actual)
        all_market_pred.append(val_market_pred)
        all_v53_pred.append(val_v53_pred)
        all_v55_pred.append(val_v55_pred)
        all_routed_pred.append(routed_pred)

        windows.append(
            {
                "window": f"{val_start.date()}__{val_end.date()}",
                "n": int(len(val)),
                "routing": choices,
                "market": _summary(val_actual, val_market_pred),
                "v5_3": _summary(val_actual, val_v53_pred),
                "v5_5": _summary(val_actual, val_v55_pred),
                "routed": _summary(val_actual, routed_pred),
            }
        )
        val_end = val_end - timedelta(days=STEP_DAYS)

    actual = np.concatenate(all_actual)
    market_pred = np.concatenate(all_market_pred)
    v53_pred = np.concatenate(all_v53_pred)
    v55_pred = np.concatenate(all_v55_pred)
    routed_pred = np.concatenate(all_routed_pred)

    report = {
        "overall": {
            "market": _summary(actual, market_pred),
            "v5_3": _summary(actual, v53_pred),
            "v5_5": _summary(actual, v55_pred),
            "routed_v60": _summary(actual, routed_pred),
        },
        "route_counts": dict(route_counts),
        "route_by_league": {league: dict(counter) for league, counter in route_by_league.items()},
        "windows": windows,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
