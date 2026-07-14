import json
from pathlib import Path
import sys

import numpy as np
import pandas as pd


THIS_DIR = Path(__file__).resolve().parent
if str(THIS_DIR) not in sys.path:
    sys.path.insert(0, str(THIS_DIR))

from outcome_value_layer_research import (
    BASE_WEIGHTS,
    _base_rule,
    _build_candidates,
    _build_model_probs_by_league,
    _by_league,
    _summarize,
)
from data.build_dataset import build_dataset
from data.loader import load_stats
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.match_context import build_match_context_features
from features.outcome_script import add_outcome_scenario_features, build_result_script_features
from features.team_potential import build_team_potential_features
from features.team_stats_form import build_team_stats_form


OUT_PATH = Path("tmp/outcome_value_layer_segmented_research.json")


def _apply_segmented_meta(cal_df: pd.DataFrame, val_df: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    from catboost import CatBoostClassifier

    pre_cal = cal_df[(cal_df["odds"] >= 1.55) & (cal_df["odds"] <= 4.00)].copy()
    pre_val = val_df[(val_df["odds"] >= 1.55) & (val_df["odds"] <= 4.00)].copy()

    feats_num = [
        "p_model",
        "p_market",
        "p_draw_model",
        "p_draw_market",
        "edge",
        "ev",
        "odds",
        "market_entropy",
        "model_entropy",
        "overround_1x2",
        "n_bookmakers",
        "same_favorite_flag",
    ]
    feats_cat = ["league_id", "outcome", "odds_bucket", "draw_risk_bin"]
    use_cols = feats_num + feats_cat

    X_cal = pre_cal[use_cols].copy()
    X_val = pre_val[use_cols].copy()
    for c in feats_num:
        X_cal[c] = pd.to_numeric(X_cal[c], errors="coerce").replace([np.inf, -np.inf], np.nan).fillna(0.0)
        X_val[c] = pd.to_numeric(X_val[c], errors="coerce").replace([np.inf, -np.inf], np.nan).fillna(0.0)
    for c in feats_cat:
        X_cal[c] = X_cal[c].astype(str).fillna("NA")
        X_val[c] = X_val[c].astype(str).fillna("NA")
    cat_idx = [X_cal.columns.get_loc(c) for c in feats_cat]

    clf = CatBoostClassifier(
        loss_function="Logloss",
        eval_metric="Logloss",
        iterations=500,
        learning_rate=0.03,
        depth=5,
        l2_leaf_reg=6.0,
        random_seed=123,
        verbose=False,
        allow_writing_files=False,
        auto_class_weights="Balanced",
    )
    clf.fit(X_cal, pre_cal["won"].astype(int).values, cat_features=cat_idx, eval_set=(X_val, pre_val["won"].astype(int).values), use_best_model=True)

    pre_cal["p_meta_win"] = clf.predict_proba(X_cal)[:, 1]
    pre_val["p_meta_win"] = clf.predict_proba(X_val)[:, 1]
    pre_cal["ev_meta"] = pre_cal["p_meta_win"] * pre_cal["odds"] - 1.0
    pre_val["ev_meta"] = pre_val["p_meta_win"] * pre_val["odds"] - 1.0

    league_configs = {}
    val_parts = []
    for lid, cal_l in pre_cal.groupby("league_id"):
        best = None
        for thr_ev in np.linspace(0.02, 0.14, 13):
            for thr_draw in np.linspace(0.22, 0.32, 6):
                picked = cal_l[(cal_l["ev_meta"] >= thr_ev) & (cal_l["p_draw_model"] <= thr_draw)].copy()
                if len(picked) < 15:
                    continue
                roi = picked["profit"].mean()
                if best is None or roi > best["roi"]:
                    best = {
                        "thr_ev_meta": float(thr_ev),
                        "thr_draw": float(thr_draw),
                        "bets": int(len(picked)),
                        "roi": float(roi),
                    }
        if best is None or best["roi"] <= 0:
            league_configs[int(lid)] = {"active": False}
            continue
        league_configs[int(lid)] = {"active": True, **best}
        val_l = pre_val[pre_val["league_id"] == lid].copy()
        val_pick = val_l[(val_l["ev_meta"] >= best["thr_ev_meta"]) & (val_l["p_draw_model"] <= best["thr_draw"])].copy()
        val_parts.append(val_pick)

    out = pd.concat(val_parts, ignore_index=True) if val_parts else pre_val.iloc[0:0].copy()
    return out, league_configs


def main():
    print("=== BUILD DATASET FOR SEGMENTED OUTCOME VALUE RESEARCH ===")
    df_all = build_dataset(return_all=True)
    print(f"RAW: {df_all.shape}")

    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()

    feats = [
        build_elo_features(df_all, mode="train"),
        build_form_xg_features(df_all, match_stats, window=5),
        build_team_stats_form(df_all, match_stats, window=5),
        build_team_potential_features(df_all),
        build_h2h_features(df_all, mode="train"),
        build_h2h_recent_features(df_all, window=5),
        build_league_context_features(df_all, window=60),
        build_match_context_features(df_all, lookback=5),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats, target_df=None)
    df_all = add_draw_diff_features(df_all)
    df_all = df_all.merge(build_result_script_features(df_all), on="fixture_id", how="left")
    df_all = add_outcome_scenario_features(df_all)
    df_train = df_all[df_all["has_result"]].copy()
    print(f"TRAIN: {df_train.shape}")

    cal_probs, val_probs = _build_model_probs_by_league(df_train)
    cal_cands = _build_candidates(cal_probs)
    val_cands = _build_candidates(val_probs)

    base_val = _base_rule(val_cands)
    segmented_val, league_cfg = _apply_segmented_meta(cal_cands, val_cands)

    report = {
        "base_weights": BASE_WEIGHTS,
        "baseline_rule": _summarize(base_val, "baseline_rule"),
        "segmented_meta_rule": _summarize(segmented_val, "segmented_meta_rule"),
        "league_config": league_cfg,
        "baseline_by_league": _by_league(base_val),
        "segmented_by_league": _by_league(segmented_val),
    }

    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
