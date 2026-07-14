from __future__ import annotations

import json
from datetime import timedelta
from pathlib import Path

import numpy as np
import pandas as pd

from .baselines import add_market_baseline, blend_probs, build_simple_poisson_features
from .betting import build_best_bets, optimize_rule, summarize_bets
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_probs
from .features import build_result_form_features
from .ml import fit_catboost_outcome, predict_catboost_outcome


OUTPUT_PATH = Path("tmp/outcome_v4_3_walkforward.json")

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


def _league_specific_blend(cal_df, val_df, cal_market, val_market, cal_cat, val_cat):
    cal_blend = np.zeros_like(cal_cat)
    val_blend = np.zeros_like(val_cat)
    weights = {}
    for league, g in cal_df.groupby("league", sort=True):
        cal_idx = g.index.to_numpy()
        val_idx = val_df.index[val_df["league"] == league].to_numpy()
        w, _ = _optimize_weight(cal_market[cal_idx], cal_cat[cal_idx], g)
        weights[league] = w
        cal_blend[cal_idx] = blend_probs(cal_market[cal_idx], cal_cat[cal_idx], w)
        if len(val_idx):
            val_blend[val_idx] = blend_probs(val_market[val_idx], val_cat[val_idx], w)
    return weights, cal_blend, val_blend


def _window_report(
    name: str,
    cal_df: pd.DataFrame,
    cal_cat: np.ndarray,
    cal_blend: np.ndarray,
    val_df: pd.DataFrame,
    market_probs: np.ndarray,
    cat_probs: np.ndarray,
    blend_probs_arr: np.ndarray,
) -> dict:
    cat_rule, cat_cal = optimize_rule(cal_df, cal_cat)
    blend_rule, blend_cal = optimize_rule(cal_df, cal_blend)
    cat_bets = build_best_bets(val_df, cat_probs, cat_rule)
    blend_bets = build_best_bets(val_df, blend_probs_arr, blend_rule)
    return {
        "window": name,
        "n_val": int(len(val_df)),
        "overall": {
            "market": evaluate_probs(val_df, market_probs, "market"),
            "catboost_v41": evaluate_probs(val_df, cat_probs, "catboost_v41"),
            "catboost_leagueblend_v42": evaluate_probs(val_df, blend_probs_arr, "catboost_leagueblend_v42"),
        },
        "roi": {
            "catboost_v41": {
                "rule": cat_rule.__dict__,
                "cal": cat_cal,
                "val": summarize_bets(cat_bets),
            },
            "catboost_leagueblend_v42": {
                "rule": blend_rule.__dict__,
                "cal": blend_cal,
                "val": summarize_bets(blend_bets),
            },
        },
    }


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

        model = fit_catboost_outcome(tr, cal)
        cal_market = cal[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
        val_market = val[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
        cal_cat = predict_catboost_outcome(model, cal)
        val_cat = predict_catboost_outcome(model, val)
        _, cal_blend, val_blend = _league_specific_blend(cal, val, cal_market, val_market, cal_cat, val_cat)

        windows.append(
            _window_report(
                f"{val_start.date()}__{val_end.date()}",
                cal,
                cal_cat,
                cal_blend,
                val,
                val_market,
                val_cat,
                val_blend,
            )
        )
        val_end = val_end - timedelta(days=STEP_DAYS)

    def _aggregate(model_key: str) -> dict:
        rows = [w["roi"][model_key]["val"] for w in windows]
        if not rows:
            return {}
        total_bets = sum(r["bets"] for r in rows)
        total_profit = sum(r["profit"] for r in rows)
        total_wins = sum(r["wins"] for r in rows)
        return {
            "windows": len(rows),
            "bets": int(total_bets),
            "wins": int(total_wins),
            "profit": round(float(total_profit), 6),
            "roi": round(float(total_profit / total_bets), 6) if total_bets else 0.0,
        }

    def _aggregate_ll(model_key: str) -> dict:
        vals = [w["overall"][model_key]["logloss"] for w in windows]
        accs = [w["overall"][model_key]["accuracy"] for w in windows]
        return {
            "windows": len(vals),
            "avg_logloss": round(float(np.mean(vals)), 6) if vals else None,
            "avg_accuracy": round(float(np.mean(accs)), 6) if accs else None,
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
            "market": _aggregate_ll("market"),
            "catboost_v41": _aggregate_ll("catboost_v41"),
            "catboost_leagueblend_v42": _aggregate_ll("catboost_leagueblend_v42"),
            "roi_catboost_v41": _aggregate("catboost_v41"),
            "roi_catboost_leagueblend_v42": _aggregate("catboost_leagueblend_v42"),
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
