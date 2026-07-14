from __future__ import annotations

import json
from datetime import timedelta
from pathlib import Path

import numpy as np
import pandas as pd
from catboost import CatBoostClassifier

from .baselines import add_market_baseline, build_simple_poisson_features
from .betting import BetRule, build_best_bets, optimize_rule, summarize_bets
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_probs
from .features import build_result_form_features
from .ml_base import fit_catboost_base, predict_catboost_base


OUTPUT_PATH = Path("tmp/outcome_v4_8_value_walkforward.json")

TRAIN_DAYS = 540
CAL_DAYS = 120
VAL_DAYS = 30
STEP_DAYS = 30
MIN_TRAIN_ROWS = 1500
MIN_CAL_ROWS = 250
MIN_VAL_ROWS = 120

OUTCOME_TO_CODE = {"Away": 0.0, "Draw": 1.0, "Home": 2.0}


def _time_windows(df: pd.DataFrame):
    max_date = pd.to_datetime(df["date_utc"].max(), utc=True)
    min_date = pd.to_datetime(df["date_utc"].min(), utc=True)
    val_end = max_date
    while True:
        val_start = val_end - timedelta(days=VAL_DAYS)
        cal_end = val_start
        cal_start = cal_end - timedelta(days=CAL_DAYS)
        train_end = cal_start
        train_start = train_end - timedelta(days=TRAIN_DAYS)
        if train_start <= min_date:
            break
        yield train_start, train_end, cal_start, cal_end, val_start, val_end
        val_end = val_end - timedelta(days=STEP_DAYS)


def _candidate_frame(df: pd.DataFrame, probs: np.ndarray, base_rule: BetRule) -> pd.DataFrame:
    bets = build_best_bets(df, probs, base_rule)
    if bets.empty:
        return bets

    outcome_idx = bets["bet_outcome"].map(OUTCOME_TO_CODE).astype(int).to_numpy()
    market = df.loc[bets.index, ["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy(dtype="float64")
    poisson = df.loc[bets.index, ["p_away_pois", "p_draw_pois", "p_home_pois"]].to_numpy(dtype="float64")
    model_prob = bets["bet_prob"].to_numpy(dtype="float64")
    market_prob = market[np.arange(len(bets)), outcome_idx]
    poisson_prob = poisson[np.arange(len(bets)), outcome_idx]

    cand = bets.copy()
    cand["outcome_code"] = outcome_idx.astype(float)
    cand["market_prob"] = market_prob
    cand["poisson_prob"] = poisson_prob
    cand["prob_minus_market"] = model_prob - market_prob
    cand["prob_minus_poisson"] = model_prob - poisson_prob
    cand["market_minus_poisson"] = market_prob - poisson_prob
    cand["is_home"] = (cand["bet_outcome"] == "Home").astype(float)
    cand["is_draw"] = (cand["bet_outcome"] == "Draw").astype(float)
    cand["is_away"] = (cand["bet_outcome"] == "Away").astype(float)
    cand["candidate_is_market_fav"] = (cand["outcome_code"] == np.argmax(market, axis=1)).astype(float)
    cand["form_points_diff_5"] = df.loc[bets.index, "form_points_diff_5"].to_numpy(dtype="float64")
    cand["venue_points_diff_5"] = df.loc[bets.index, "venue_points_diff_5"].to_numpy(dtype="float64")
    cand["gd_diff_5"] = df.loc[bets.index, "gd_diff_5"].to_numpy(dtype="float64")
    cand["attack_vs_def_home_5"] = df.loc[bets.index, "attack_vs_def_home_5"].to_numpy(dtype="float64")
    cand["attack_vs_def_away_5"] = df.loc[bets.index, "attack_vs_def_away_5"].to_numpy(dtype="float64")
    cand["league_id"] = df.loc[bets.index, "league_id"].astype(str).to_numpy()
    cand["season"] = df.loc[bets.index, "season"].astype(str).to_numpy()
    return cand.reset_index(drop=True)


VALUE_FEATURES = [
    "league_id",
    "season",
    "outcome_code",
    "bet_odds",
    "bet_prob",
    "market_prob",
    "poisson_prob",
    "bet_ev",
    "bet_edge",
    "prob_minus_market",
    "prob_minus_poisson",
    "market_minus_poisson",
    "candidate_is_market_fav",
    "is_home",
    "is_draw",
    "is_away",
    "form_points_diff_5",
    "venue_points_diff_5",
    "gd_diff_5",
    "attack_vs_def_home_5",
    "attack_vs_def_away_5",
]
VALUE_CAT = ["league_id", "season"]


def _prepare_value_xy(df: pd.DataFrame) -> tuple[pd.DataFrame, np.ndarray]:
    x = df[VALUE_FEATURES].copy()
    for c in VALUE_CAT:
        x[c] = x[c].astype(str)
    y = df["won"].astype(int).to_numpy()
    return x, y


def _fit_value_model(cal_candidates: pd.DataFrame) -> CatBoostClassifier:
    x, y = _prepare_value_xy(cal_candidates)
    model = CatBoostClassifier(
        loss_function="Logloss",
        eval_metric="Logloss",
        depth=5,
        learning_rate=0.04,
        iterations=700,
        l2_leaf_reg=8.0,
        random_strength=1.0,
        min_data_in_leaf=8,
        verbose=False,
        random_seed=42,
    )
    model.fit(
        x,
        y,
        cat_features=[x.columns.get_loc(c) for c in VALUE_CAT],
        verbose=False,
    )
    return model


def _score_candidates(model: CatBoostClassifier, candidates: pd.DataFrame) -> np.ndarray:
    if candidates.empty:
        return np.zeros(0, dtype="float64")
    x, _ = _prepare_value_xy(candidates)
    return model.predict_proba(x)[:, 1]


def _optimize_value_threshold(cal_candidates: pd.DataFrame, value_scores: np.ndarray) -> tuple[float, dict]:
    best_thr = 0.5
    best_summary = {"bets": 0, "wins": 0, "hit_rate": 0.0, "avg_odds": 0.0, "avg_ev": 0.0, "profit": 0.0, "roi": 0.0}
    best_score = (-999.0, -999)
    for thr in np.linspace(0.35, 0.75, 17):
        picked = cal_candidates.loc[value_scores >= thr].copy()
        summary = summarize_bets(picked)
        if summary["bets"] < 10:
            continue
        score = (summary["roi"], summary["bets"])
        if score > best_score:
            best_score = score
            best_thr = float(thr)
            best_summary = summary
    return best_thr, best_summary


def main() -> None:
    df = load_match_snapshot()
    df = add_market_baseline(df)
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)
    df = df.sort_values(["date_utc", "fixture_id"]).reset_index(drop=True)

    windows: list[dict] = []
    for train_start, train_end, cal_start, cal_end, val_start, val_end in _time_windows(df):
        tr = df[(df["date_utc"] > train_start) & (df["date_utc"] <= train_end)].copy().reset_index(drop=True)
        cal = df[(df["date_utc"] > cal_start) & (df["date_utc"] <= cal_end)].copy().reset_index(drop=True)
        val = df[(df["date_utc"] > val_start) & (df["date_utc"] <= val_end)].copy().reset_index(drop=True)
        if len(tr) < MIN_TRAIN_ROWS or len(cal) < MIN_CAL_ROWS or len(val) < MIN_VAL_ROWS:
            continue

        base_model = fit_catboost_base(tr, cal)
        cal_probs = predict_catboost_base(base_model, cal)
        val_probs = predict_catboost_base(base_model, val)

        base_rule, base_cal_summary = optimize_rule(cal, cal_probs)
        val_baseline_bets = build_best_bets(val, val_probs, base_rule)

        cal_candidates = _candidate_frame(cal, cal_probs, base_rule)
        val_candidates = _candidate_frame(val, val_probs, base_rule)
        if len(cal_candidates) < 12:
            windows.append(
                {
                    "window": f"{val_start.date()}__{val_end.date()}",
                    "n_val": int(len(val)),
                    "overall": {"base_probs": evaluate_probs(val, val_probs, "base_probs")},
                    "baseline_rule": {"rule": base_rule.__dict__, "cal": base_cal_summary, "val": summarize_bets(val_baseline_bets)},
                    "value_layer": {"threshold": None, "cal": None, "val": summarize_bets(val_candidates.iloc[[]].copy())},
                }
            )
            continue

        value_model = _fit_value_model(cal_candidates)
        cal_scores = _score_candidates(value_model, cal_candidates)
        val_scores = _score_candidates(value_model, val_candidates)
        value_thr, value_cal_summary = _optimize_value_threshold(cal_candidates, cal_scores)
        val_value_bets = val_candidates.loc[val_scores >= value_thr].copy()

        windows.append(
            {
                "window": f"{val_start.date()}__{val_end.date()}",
                "n_val": int(len(val)),
                "overall": {"base_probs": evaluate_probs(val, val_probs, "base_probs")},
                "baseline_rule": {"rule": base_rule.__dict__, "cal": base_cal_summary, "val": summarize_bets(val_baseline_bets)},
                "value_layer": {"threshold": value_thr, "cal": value_cal_summary, "val": summarize_bets(val_value_bets)},
            }
        )

    def _aggregate(path: str) -> dict:
        rows = []
        for w in windows:
            obj = w
            for part in path.split("."):
                obj = obj[part]
            rows.append(obj)
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

    report = {
        "config": {
            "train_days": TRAIN_DAYS,
            "cal_days": CAL_DAYS,
            "val_days": VAL_DAYS,
            "step_days": STEP_DAYS,
        },
        "windows": windows,
        "aggregate": {
            "baseline_rule": _aggregate("baseline_rule.val"),
            "value_layer": _aggregate("value_layer.val"),
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

