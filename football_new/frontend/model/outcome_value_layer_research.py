import json
from pathlib import Path
import sys

import numpy as np
import pandas as pd


THIS_DIR = Path(__file__).resolve().parent
if str(THIS_DIR) not in sys.path:
    sys.path.insert(0, str(THIS_DIR))

from data.build_dataset import build_dataset
from data.loader import load_stats
from data.splits import recency_weights, temporal_split_by_league
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
from outcome_catboost_research import _build_cb_feature_sets, _prepare_cb_frame
from train_outcomes import CAL_DAYS, GAP_DAYS, VAL_DAYS


OUT_PATH = Path("tmp/outcome_value_layer_research.json")
BASE_WEIGHTS = {"catboost": 0.80, "poisson": 0.10, "market": 0.10}
SIDE_OUTCOMES = ("Home", "Away")


def _prepare_y_outcome_3(df: pd.DataFrame) -> np.ndarray:
    h = df["home_goals"].astype(float)
    a = df["away_goals"].astype(float)
    return np.where(h > a, 2, np.where(h < a, 0, 1)).astype(int)


def _safe_market_probs(df: pd.DataFrame) -> np.ndarray:
    probs = np.stack(
        [
            df["p_away_norm"].astype(float).values,
            df["p_draw_norm"].astype(float).values,
            df["p_home_norm"].astype(float).values,
        ],
        axis=1,
    )
    return sanitize_prob(probs)


def _blend_probs(p_cb: np.ndarray, p_pois: np.ndarray, p_mkt: np.ndarray) -> np.ndarray:
    out = (
        BASE_WEIGHTS["catboost"] * p_cb
        + BASE_WEIGHTS["poisson"] * p_pois
        + BASE_WEIGHTS["market"] * p_mkt
    )
    return sanitize_prob(out)


def _build_model_probs_by_league(df_full: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    from catboost import CatBoostClassifier
    from sklearn.linear_model import LogisticRegression

    cal_parts = []
    val_parts = []

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
        X_tr = _prepare_cb_frame(tr, numeric_market, categorical)
        X_cal = _prepare_cb_frame(cal, numeric_market, categorical)
        X_val = _prepare_cb_frame(val, numeric_market, categorical)
        y_tr = _prepare_y_outcome_3(tr)
        y_cal = _prepare_y_outcome_3(cal)
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

        P_cal = _blend_probs(P_cal_cb, P_cal_pois, P_cal_mkt)
        P_val = _blend_probs(P_val_cb, P_val_pois, P_val_mkt)

        for frame, probs, bucket in ((cal, P_cal, cal_parts), (val, P_val, val_parts)):
            x = frame[
                [
                    "fixture_id",
                    "league_id",
                    "date_utc",
                    "home_goals",
                    "away_goals",
                    "avg_odds_home",
                    "avg_odds_draw",
                    "avg_odds_away",
                    "p_home_norm",
                    "p_draw_norm",
                    "p_away_norm",
                    "overround_1x2",
                    "n_bookmakers",
                ]
            ].copy()
            x["p_away_model"] = probs[:, 0]
            x["p_draw_model"] = probs[:, 1]
            x["p_home_model"] = probs[:, 2]
            bucket.append(x)

    return pd.concat(cal_parts, ignore_index=True), pd.concat(val_parts, ignore_index=True)


def _entropy(a: float, b: float, c: float) -> float:
    vals = np.array([a, b, c], dtype=float)
    vals = vals[np.isfinite(vals) & (vals > 0)]
    if len(vals) == 0:
        return 0.0
    return float(-(vals * np.log(vals)).sum())


def _build_candidates(df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for _, row in df.iterrows():
        model_probs = {
            "Home": float(row["p_home_model"]),
            "Draw": float(row["p_draw_model"]),
            "Away": float(row["p_away_model"]),
        }
        market_probs = {
            "Home": float(row["p_home_norm"]),
            "Draw": float(row["p_draw_norm"]),
            "Away": float(row["p_away_norm"]),
        }
        odds_map = {
            "Home": float(row["avg_odds_home"]),
            "Draw": float(row["avg_odds_draw"]),
            "Away": float(row["avg_odds_away"]),
        }
        model_fav = max(model_probs, key=model_probs.get)
        market_fav = max(market_probs, key=market_probs.get)
        for outcome in SIDE_OUTCOMES:
            odds = odds_map[outcome]
            if not np.isfinite(odds) or odds <= 1.01:
                continue
            p_model = model_probs[outcome]
            p_market = market_probs[outcome]
            ev = p_model * odds - 1.0
            won = int(
                (outcome == "Home" and row["home_goals"] > row["away_goals"])
                or (outcome == "Away" and row["home_goals"] < row["away_goals"])
            )
            profit = float(odds - 1.0) if won else -1.0
            rows.append(
                {
                    "fixture_id": int(row["fixture_id"]),
                    "league_id": int(row["league_id"]),
                    "date_utc": row["date_utc"],
                    "outcome": outcome,
                    "odds": odds,
                    "p_model": p_model,
                    "p_market": p_market,
                    "p_draw_model": float(row["p_draw_model"]),
                    "p_draw_market": float(row["p_draw_norm"]),
                    "edge": p_model - p_market,
                    "ev": ev,
                    "won": won,
                    "profit": profit,
                    "market_entropy": _entropy(row["p_home_norm"], row["p_draw_norm"], row["p_away_norm"]),
                    "model_entropy": _entropy(row["p_home_model"], row["p_draw_model"], row["p_away_model"]),
                    "overround_1x2": float(row["overround_1x2"]) if np.isfinite(row["overround_1x2"]) else np.nan,
                    "n_bookmakers": float(row["n_bookmakers"]) if np.isfinite(row["n_bookmakers"]) else np.nan,
                    "same_favorite_flag": int(model_fav == market_fav),
                }
            )
    out = pd.DataFrame(rows)
    out["odds_bucket"] = pd.cut(
        out["odds"],
        bins=[0.0, 1.55, 1.70, 2.00, 2.40, 3.20, 4.00, 10.0],
        labels=["<1.55", "1.55-1.70", "1.70-2.00", "2.00-2.40", "2.40-3.20", "3.20-4.00", "4.00+"],
        include_lowest=True,
    ).astype(str)
    out["draw_risk_bin"] = pd.cut(
        out["p_draw_model"],
        bins=[0.0, 0.22, 0.26, 0.30, 0.34, 1.0],
        labels=["<=0.22", "0.22-0.26", "0.26-0.30", "0.30-0.34", "0.34+"],
        include_lowest=True,
    ).astype(str)
    return out


def _base_rule(df: pd.DataFrame) -> pd.DataFrame:
    return df[
        (df["odds"] >= 1.70)
        & (df["odds"] <= 3.20)
        & (df["edge"] >= 0.06)
        & (df["ev"] >= 0.10)
        & (df["p_draw_model"] <= 0.30)
    ].copy()


def _summarize(df: pd.DataFrame, label: str) -> dict:
    bets = int(len(df))
    wins = int(df["won"].sum()) if bets else 0
    profit = float(df["profit"].sum()) if bets else 0.0
    roi = float(profit / bets) if bets else None
    hit_rate = float(wins / bets) if bets else None
    return {"label": label, "bets": bets, "wins": wins, "profit": profit, "roi": roi, "hit_rate": hit_rate}


def _fit_value_layer(cal_df: pd.DataFrame, val_df: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
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
    clf.fit(X_cal, pre_cal["won"].astype(int).values, cat_features=cat_idx, eval_set=(X_val, val_df.loc[pre_val.index, "won"].astype(int).values), use_best_model=True)

    pre_cal["p_meta_win"] = clf.predict_proba(X_cal)[:, 1]
    pre_val["p_meta_win"] = clf.predict_proba(X_val)[:, 1]
    pre_cal["ev_meta"] = pre_cal["p_meta_win"] * pre_cal["odds"] - 1.0
    pre_val["ev_meta"] = pre_val["p_meta_win"] * pre_val["odds"] - 1.0

    best = None
    for thr_ev in np.linspace(0.00, 0.12, 13):
        for thr_draw in np.linspace(0.26, 0.32, 4):
            picked = pre_cal[(pre_cal["ev_meta"] >= thr_ev) & (pre_cal["p_draw_model"] <= thr_draw)].copy()
            if len(picked) < 20:
                continue
            roi = picked["profit"].mean()
            if best is None or roi > best["roi"]:
                best = {"thr_ev_meta": float(thr_ev), "thr_draw": float(thr_draw), "bets": int(len(picked)), "roi": float(roi)}

    if best is None:
        best = {"thr_ev_meta": 0.02, "thr_draw": 0.30, "bets": 0, "roi": None}

    picked_val = pre_val[(pre_val["ev_meta"] >= best["thr_ev_meta"]) & (pre_val["p_draw_model"] <= best["thr_draw"])].copy()
    return picked_val, best


def _by_league(df: pd.DataFrame) -> list[dict]:
    if df.empty:
        return []
    rows = []
    for lid, g in df.groupby("league_id"):
        rows.append(
            {
                "league_id": int(lid),
                "bets": int(len(g)),
                "wins": int(g["won"].sum()),
                "profit": float(g["profit"].sum()),
                "roi": float(g["profit"].mean()),
                "hit_rate": float(g["won"].mean()),
            }
        )
    return rows


def main():
    print("=== BUILD DATASET FOR OUTCOME VALUE LAYER RESEARCH ===")
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
    meta_val, meta_cfg = _fit_value_layer(cal_cands, val_cands)

    report = {
        "base_weights": BASE_WEIGHTS,
        "cal_candidates": int(len(cal_cands)),
        "val_candidates": int(len(val_cands)),
        "baseline_rule": _summarize(base_val, "baseline_rule"),
        "meta_rule": _summarize(meta_val, "meta_rule"),
        "meta_config": meta_cfg,
        "baseline_by_league": _by_league(base_val),
        "meta_by_league": _by_league(meta_val),
    }

    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
