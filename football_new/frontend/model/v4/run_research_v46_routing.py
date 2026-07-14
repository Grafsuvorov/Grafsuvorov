from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .baselines import add_market_baseline, blend_probs, build_simple_poisson_features
from .betting import build_best_bets, optimize_rule, summarize_bets, summarize_bets_by_league
from .data_snapshot import load_match_snapshot
from .evaluate import evaluate_by_league, evaluate_probs
from .features import add_draw_disagreement_features, build_result_form_features
from .ml_base import fit_catboost_base, predict_catboost_base
from .ml_focus import fit_catboost_focus, predict_catboost_focus
from .splits import temporal_split_by_league
from .settings import DEFAULT_CAL_DAYS, DEFAULT_GAP_DAYS, DEFAULT_VAL_DAYS


OUTPUT_PATH = Path("tmp/outcome_v4_6_routing.json")


def _optimize_market_blend(cal_market: np.ndarray, cal_base: np.ndarray, cal_df) -> tuple[float, dict]:
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


def _per_league_market_blend(cal_df, val_df, cal_market, val_market, cal_probs, val_probs):
    cal_out = np.zeros_like(cal_probs)
    val_out = np.zeros_like(val_probs)
    weights = {}
    metrics = {}
    for league, g in cal_df.groupby("league", sort=True):
        cal_idx = g.index.to_numpy()
        val_idx = val_df.index[val_df["league"] == league].to_numpy()
        w, m = _optimize_market_blend(cal_market[cal_idx], cal_probs[cal_idx], g)
        weights[league] = w
        metrics[league] = m
        cal_out[cal_idx] = blend_probs(cal_market[cal_idx], cal_probs[cal_idx], w)
        if len(val_idx):
            val_out[val_idx] = blend_probs(val_market[val_idx], val_probs[val_idx], w)
    return weights, metrics, cal_out, val_out


def main() -> None:
    df = load_match_snapshot()
    df = add_market_baseline(df)
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)
    df = add_draw_disagreement_features(df)

    tr, cal, val = temporal_split_by_league(
        df,
        ts_col="date_utc",
        league_col="league_id",
        cal_days=DEFAULT_CAL_DAYS,
        val_days=DEFAULT_VAL_DAYS,
        gap_days=DEFAULT_GAP_DAYS,
    )

    cal_market = cal[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()
    val_market = val[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy()

    base_model = fit_catboost_base(tr, cal)
    cal_base = predict_catboost_base(base_model, cal)
    val_base = predict_catboost_base(base_model, val)

    focus_model = fit_catboost_focus(tr, cal)
    cal_focus = predict_catboost_focus(focus_model, cal)
    val_focus = predict_catboost_focus(focus_model, val)

    base_weights, base_blend_cal_metrics, cal_base_blend, val_base_blend = _per_league_market_blend(
        cal, val, cal_market, val_market, cal_base, val_base
    )
    focus_weights, focus_blend_cal_metrics, cal_focus_blend, val_focus_blend = _per_league_market_blend(
        cal, val, cal_market, val_market, cal_focus, val_focus
    )

    routed_cal = np.zeros_like(cal_market)
    routed_val = np.zeros_like(val_market)
    routing = {}
    routing_cal_metrics = {}

    for league, g in cal.groupby("league", sort=True):
        cal_idx = g.index.to_numpy()
        val_idx = val.index[val["league"] == league].to_numpy()
        candidates = {
            "market": (cal_market[cal_idx], val_market[val_idx] if len(val_idx) else np.zeros((0, 3))),
            "base": (cal_base[cal_idx], val_base[val_idx] if len(val_idx) else np.zeros((0, 3))),
            "base_blend": (cal_base_blend[cal_idx], val_base_blend[val_idx] if len(val_idx) else np.zeros((0, 3))),
            "focus": (cal_focus[cal_idx], val_focus[val_idx] if len(val_idx) else np.zeros((0, 3))),
            "focus_blend": (cal_focus_blend[cal_idx], val_focus_blend[val_idx] if len(val_idx) else np.zeros((0, 3))),
        }
        scored = {
            name: evaluate_probs(g, probs_cal, name)
            for name, (probs_cal, _) in candidates.items()
        }
        best_name = min(scored, key=lambda k: scored[k]["logloss"])
        routing[league] = best_name
        routing_cal_metrics[league] = scored
        routed_cal[cal_idx] = candidates[best_name][0]
        if len(val_idx):
            routed_val[val_idx] = candidates[best_name][1]

    routed_rule, routed_rule_cal = optimize_rule(cal, routed_cal)
    routed_val_bets = build_best_bets(val, routed_val, routed_rule)

    report = {
        "dataset": {
            "rows": int(len(df)),
            "train": int(len(tr)),
            "cal": int(len(cal)),
            "val": int(len(val)),
        },
        "league_blends": {
            "base_weights": base_weights,
            "focus_weights": focus_weights,
            "base_blend_cal_metrics": base_blend_cal_metrics,
            "focus_blend_cal_metrics": focus_blend_cal_metrics,
        },
        "routing": routing,
        "routing_cal_metrics": routing_cal_metrics,
        "overall": {
            "market": evaluate_probs(val, val_market, "market"),
            "base": evaluate_probs(val, val_base, "base"),
            "focus": evaluate_probs(val, val_focus, "focus"),
            "base_blend": evaluate_probs(val, val_base_blend, "base_blend"),
            "focus_blend": evaluate_probs(val, val_focus_blend, "focus_blend"),
            "routed_v46": evaluate_probs(val, routed_val, "routed_v46"),
        },
        "by_league": {
            "market": evaluate_by_league(val, val_market, "market"),
            "base": evaluate_by_league(val, val_base, "base"),
            "focus": evaluate_by_league(val, val_focus, "focus"),
            "base_blend": evaluate_by_league(val, val_base_blend, "base_blend"),
            "focus_blend": evaluate_by_league(val, val_focus_blend, "focus_blend"),
            "routed_v46": evaluate_by_league(val, routed_val, "routed_v46"),
        },
        "roi": {
            "routed_v46": {
                "rule": routed_rule.__dict__,
                "cal": routed_rule_cal,
                "val": summarize_bets(routed_val_bets),
                "by_league": summarize_bets_by_league(routed_val_bets),
            }
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
