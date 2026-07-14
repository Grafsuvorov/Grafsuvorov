from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

from .baselines import add_market_baseline, blend_probs, build_simple_poisson_features
from .betting import build_best_bets, optimize_rule, summarize_bets, summarize_bets_by_league
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_by_league, evaluate_probs, outcome_target
from .features import build_result_form_features
from .ml import fit_catboost_binary, fit_catboost_outcome, predict_catboost_outcome, prepare_x
from .splits import temporal_split_by_league
from .settings import DEFAULT_CAL_DAYS, DEFAULT_GAP_DAYS, DEFAULT_VAL_DAYS


OUTPUT_PATH = Path("tmp/outcome_v4_4_decomp.json")


def _clip_binary(p: np.ndarray) -> np.ndarray:
    return np.clip(np.asarray(p, dtype="float64"), 1e-6, 1 - 1e-6)


def _decomp_probs(train_df: pd.DataFrame, cal_df: pd.DataFrame, val_df: pd.DataFrame) -> tuple[np.ndarray, np.ndarray]:
    tr_x = prepare_x(train_df)
    cal_x = prepare_x(cal_df)
    val_x = prepare_x(val_df)

    tr_y = outcome_target(train_df)
    cal_y = outcome_target(cal_df)

    tr_draw_y = (tr_y == 1).astype(int)
    cal_draw_y = (cal_y == 1).astype(int)
    draw_model = fit_catboost_binary(tr_x, tr_draw_y, cal_x, cal_draw_y)

    tr_side_mask = tr_y != 1
    cal_side_mask = cal_y != 1
    tr_side_y = (tr_y[tr_side_mask] == 2).astype(int)  # home vs away, conditional on not-draw
    cal_side_y = (cal_y[cal_side_mask] == 2).astype(int)
    side_model = fit_catboost_binary(
        tr_x.loc[tr_side_mask].reset_index(drop=True),
        tr_side_y,
        cal_x.loc[cal_side_mask].reset_index(drop=True),
        cal_side_y,
    )

    cal_draw = _clip_binary(draw_model.predict_proba(cal_x)[:, 1])
    val_draw = _clip_binary(draw_model.predict_proba(val_x)[:, 1])
    cal_home_side = _clip_binary(side_model.predict_proba(cal_x)[:, 1])
    val_home_side = _clip_binary(side_model.predict_proba(val_x)[:, 1])

    cal_home = (1.0 - cal_draw) * cal_home_side
    cal_away = (1.0 - cal_draw) * (1.0 - cal_home_side)
    val_home = (1.0 - val_draw) * val_home_side
    val_away = (1.0 - val_draw) * (1.0 - val_home_side)

    cal_probs = np.column_stack([cal_away, cal_draw, cal_home])
    val_probs = np.column_stack([val_away, val_draw, val_home])
    cal_probs /= cal_probs.sum(axis=1, keepdims=True)
    val_probs /= val_probs.sum(axis=1, keepdims=True)
    return cal_probs, val_probs


def _optimize_weight(cal_market: np.ndarray, cal_base: np.ndarray, cal_df) -> tuple[float, dict]:
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

    tr, cal, val = temporal_split_by_league(
        df,
        ts_col="date_utc",
        league_col="league_id",
        cal_days=DEFAULT_CAL_DAYS,
        val_days=DEFAULT_VAL_DAYS,
        gap_days=DEFAULT_GAP_DAYS,
    )

    multi_model = fit_catboost_outcome(tr, cal)
    val_multi = predict_catboost_outcome(multi_model, val)
    cal_multi = predict_catboost_outcome(multi_model, cal)
    cal_decomp, val_decomp = _decomp_probs(tr, cal, val)

    cal_market = cal[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    val_market = val[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()

    multi_w, multi_cal = _optimize_weight(cal_market, cal_multi, cal)
    decomp_w, decomp_cal = _optimize_weight(cal_market, cal_decomp, cal)
    val_multi_blend = blend_probs(val_market, val_multi, multi_w)
    val_decomp_blend = blend_probs(val_market, val_decomp, decomp_w)

    multi_rule, multi_rule_cal = optimize_rule(cal, blend_probs(cal_market, cal_multi, multi_w))
    decomp_rule, decomp_rule_cal = optimize_rule(cal, blend_probs(cal_market, cal_decomp, decomp_w))
    val_multi_bets = build_best_bets(val, val_multi_blend, multi_rule)
    val_decomp_bets = build_best_bets(val, val_decomp_blend, decomp_rule)

    report = {
        "dataset": {
            "rows": int(len(df)),
            "train": int(len(tr)),
            "cal": int(len(cal)),
            "val": int(len(val)),
        },
        "blend_choice": {
            "multiclass_market_weight": multi_w,
            "multiclass_market_cal": multi_cal,
            "decomp_market_weight": decomp_w,
            "decomp_market_cal": decomp_cal,
        },
        "overall": {
            "market": evaluate_probs(val, val_market, "market"),
            "catboost_v41": evaluate_probs(val, val_multi, "catboost_v41"),
            "catboost_market_v41": evaluate_probs(val, val_multi_blend, "catboost_market_v41"),
            "decomp_v44": evaluate_probs(val, val_decomp, "decomp_v44"),
            "decomp_market_v44": evaluate_probs(val, val_decomp_blend, "decomp_market_v44"),
        },
        "by_league": {
            "market": evaluate_by_league(val, val_market, "market"),
            "catboost_v41": evaluate_by_league(val, val_multi, "catboost_v41"),
            "decomp_v44": evaluate_by_league(val, val_decomp, "decomp_v44"),
            "decomp_market_v44": evaluate_by_league(val, val_decomp_blend, "decomp_market_v44"),
        },
        "roi": {
            "catboost_market_v41": {
                "rule": multi_rule.__dict__,
                "cal": multi_rule_cal,
                "val": summarize_bets(val_multi_bets),
                "by_league": summarize_bets_by_league(val_multi_bets),
            },
            "decomp_market_v44": {
                "rule": decomp_rule.__dict__,
                "cal": decomp_rule_cal,
                "val": summarize_bets(val_decomp_bets),
                "by_league": summarize_bets_by_league(val_decomp_bets),
            },
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

