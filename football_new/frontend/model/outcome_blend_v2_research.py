import json
from pathlib import Path
import sys

import numpy as np
import pandas as pd
from sklearn.metrics import accuracy_score, log_loss


THIS_DIR = Path(__file__).resolve().parent
if str(THIS_DIR) not in sys.path:
    sys.path.insert(0, str(THIS_DIR))

from data.build_dataset import build_dataset
from data.loader import load_stats
from data.splits import temporal_split_by_league
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
from models.blending import sanitize_prob
from models.poisson import build_poisson_probs_for_arrays, train_poisson_pair
from outcome_catboost_research import (
    _build_cb_feature_sets,
    _metric_pack,
    _prepare_y_outcome_3,
    _safe_market_probs,
    _train_catboost_variant,
)
from train_outcomes import CAL_DAYS, GAP_DAYS, VAL_DAYS


OUT_PATH = Path("tmp/outcome_blend_v2_research.json")


def _weighted_metric(metrics: dict[int, dict], key: str) -> float | None:
    rows = [(int(v["val_n"]), float(v[key])) for v in metrics.values() if key in v and v.get("val_n")]
    if not rows:
        return None
    total_n = sum(n for n, _ in rows)
    if total_n <= 0:
        return None
    return sum(n * val for n, val in rows) / total_n


def _blend_probs(p_cb: np.ndarray, p_pois: np.ndarray, p_mkt: np.ndarray, w_cb: float, w_pois: float) -> np.ndarray:
    w_mkt = 1.0 - w_cb - w_pois
    out = (w_cb * p_cb) + (w_pois * p_pois) + (w_mkt * p_mkt)
    return sanitize_prob(out)


def _run_blend_by_league(df_full: pd.DataFrame) -> dict[int, dict]:
    out = {}
    for lid in sorted({int(x) for x in df_full["league_id"].dropna().unique()}):
        subset = df_full[(df_full["league_id"] == lid) & (df_full["has_result"])].copy().reset_index(drop=True)
        if subset.empty:
            continue

        tr, cal, val = temporal_split_by_league(
            subset,
            ts_col="date_utc",
            league_col="league_id",
            cal_days=CAL_DAYS,
            val_days=VAL_DAYS,
            gap_days=GAP_DAYS,
            min_cal_per_league=12,
            min_val_per_league=6,
            now_override=None,
        )
        if tr.empty or cal.empty or val.empty:
            continue

        numeric_base, numeric_market, categorical = _build_cb_feature_sets(subset)

        cb_res = _train_catboost_variant(
            tr=tr,
            cal=cal,
            val=val,
            numeric_cols=numeric_market,
            categorical_cols=categorical,
            use_market_anchor=False,
        )
        # rerun internals to get raw calibrated probs
        from catboost import CatBoostClassifier
        from sklearn.linear_model import LogisticRegression
        from data.splits import recency_weights
        from outcome_catboost_research import _prepare_cb_frame

        X_tr = _prepare_cb_frame(tr, numeric_market, categorical)
        X_cal = _prepare_cb_frame(cal, numeric_market, categorical)
        X_val = _prepare_cb_frame(val, numeric_market, categorical)
        y_tr = _prepare_y_outcome_3(tr)
        y_cal = _prepare_y_outcome_3(cal)
        y_val = _prepare_y_outcome_3(val)
        cat_idx = [X_tr.columns.get_loc(c) for c in categorical]
        w_tr = recency_weights(tr, ts_col="date_utc", now_override=None)
        cb_model = CatBoostClassifier(
            loss_function="MultiClass",
            eval_metric="MultiClass",
            iterations=900,
            learning_rate=0.03,
            depth=6,
            l2_leaf_reg=6.0,
            random_strength=1.5,
            bagging_temperature=0.5,
            min_data_in_leaf=20,
            random_seed=123,
            verbose=False,
            allow_writing_files=False,
        )
        cb_model.fit(
            X_tr,
            y_tr,
            sample_weight=w_tr,
            cat_features=cat_idx,
            eval_set=(X_cal, y_cal),
            use_best_model=True,
        )
        P_cal_cb_raw = sanitize_prob(cb_model.predict_proba(X_cal))
        P_val_cb_raw = sanitize_prob(cb_model.predict_proba(X_val))
        lr = LogisticRegression(max_iter=300, solver="lbfgs")
        lr.fit(P_cal_cb_raw, y_cal)
        P_cal_cb = sanitize_prob(lr.predict_proba(P_cal_cb_raw))
        P_val_cb = sanitize_prob(lr.predict_proba(P_val_cb_raw))

        pois = train_poisson_pair(
            tr=tr,
            cal=cal,
            val=val,
            feature_cols=numeric_base,
            ts_col="date_utc",
            now_override=None,
        )
        P_cal_pois, _ = build_poisson_probs_for_arrays(pois["lam_cal_home"], pois["lam_cal_away"])
        P_val_pois, _ = build_poisson_probs_for_arrays(pois["lam_val_home"], pois["lam_val_away"])
        P_cal_mkt = _safe_market_probs(cal)
        P_val_mkt = _safe_market_probs(val)

        best = None
        best_ll = float("inf")
        for w_cb in np.linspace(0.30, 0.80, 11):
            for w_pois in np.linspace(0.05, 0.40, 8):
                if w_cb + w_pois >= 1.0:
                    continue
                P_try = _blend_probs(P_cal_cb, P_cal_pois, P_cal_mkt, float(w_cb), float(w_pois))
                ll = log_loss(y_cal, P_try, labels=[0, 1, 2])
                if ll < best_ll:
                    best_ll = float(ll)
                    best = (float(w_cb), float(w_pois), float(1.0 - w_cb - w_pois))

        w_cb, w_pois, w_mkt = best
        P_val_final = _blend_probs(P_val_cb, P_val_pois, P_val_mkt, w_cb, w_pois)
        metrics = _metric_pack(y_val, P_val_final)
        metrics["w_catboost"] = w_cb
        metrics["w_poisson"] = w_pois
        metrics["w_market"] = w_mkt
        metrics["cal_ll_best"] = best_ll
        metrics["catboost_market_val_ll"] = float(cb_res["val_ll"])
        out[lid] = metrics
    return out


def main():
    print("=== BUILD DATASET FOR OUTCOME BLEND V2 RESEARCH ===")
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

    blend = _run_blend_by_league(df_train)
    report = {
        "blend_v2": {
            "by_league": blend,
            "weighted_val_acc": _weighted_metric(blend, "val_acc"),
            "weighted_val_ll": _weighted_metric(blend, "val_ll"),
        }
    }

    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
