import json
from pathlib import Path
import sys

import numpy as np
import pandas as pd
from sklearn.metrics import log_loss

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
from features.opponent_segments import build_opponent_segment_features
from features.outcome_script import add_outcome_scenario_features, build_result_script_features
from features.season_motivation import build_season_motivation_features
from features.team_potential import build_team_potential_features
from features.team_stats_form import build_team_stats_form
from models.blending import sanitize_prob
from models.calibration import apply_multinomial_lr, fit_multinomial_lr_calibrator
from models.poisson import build_poisson_probs_for_arrays, train_poisson_pair
from outcome_catboost_research import _build_cb_feature_sets, _prepare_y_outcome_3, _safe_market_probs
from outcome_v3_research import (
    BASE_CATEGORICAL_COLS,
    CAL_DAYS,
    GAP_DAYS,
    VAL_DAYS,
    _blend_probs,
    _compose_from_draw_side,
    _draw_risk_features,
    _fit_catboost_binary,
    _fit_catboost_multiclass,
    _build_contradiction_features,
    _prepare_y_draw,
    _prepare_y_side,
    _apply_prob_stabilizers,
    _apply_market_anchor,
    _search_blend_weights,
    _search_market_anchor,
)


OUT_JSON = Path("tmp/outcome_v3_segment_diagnostic.json")
OUT_CSV = Path("tmp/outcome_v3_candidate_dataset.csv")
OUT_SEGMENTS_CSV = Path("tmp/outcome_v3_segments_full.csv")

OUTCOMES = [("Away", 0, "avg_odds_away"), ("Draw", 1, "avg_odds_draw"), ("Home", 2, "avg_odds_home")]


def _safe_bin(values: pd.Series, bins: list[float], labels: list[str]) -> pd.Series:
    return pd.cut(values.astype(float), bins=bins, labels=labels, include_lowest=True, right=False).astype("string")


def _odds_bucket(series: pd.Series) -> pd.Series:
    vals = pd.to_numeric(series, errors="coerce")
    out = pd.Series("NA", index=series.index, dtype="string")
    m = vals.notna()
    out.loc[m] = _safe_bin(
        vals.loc[m],
        bins=[0.0, 1.55, 1.70, 2.00, 2.40, 3.20, 4.00, 100.0],
        labels=["<1.55", "1.55-1.70", "1.70-2.00", "2.00-2.40", "2.40-3.20", "3.20-4.00", "4.00+"],
    )
    return out


def _edge_bucket(series: pd.Series) -> pd.Series:
    vals = pd.to_numeric(series, errors="coerce")
    out = pd.Series("NA", index=series.index, dtype="string")
    m = vals.notna()
    out.loc[m] = _safe_bin(
        vals.loc[m],
        bins=[-10.0, -0.02, 0.02, 0.05, 0.08, 0.12, 10.0],
        labels=["<-0.02", "-0.02-0.02", "0.02-0.05", "0.05-0.08", "0.08-0.12", "0.12+"],
    )
    return out


def _draw_risk_bucket(series: pd.Series) -> pd.Series:
    vals = pd.to_numeric(series, errors="coerce")
    out = pd.Series("NA", index=series.index, dtype="string")
    m = vals.notna()
    out.loc[m] = _safe_bin(
        vals.loc[m],
        bins=[0.0, 0.22, 0.26, 0.30, 0.34, 1.01],
        labels=["<=0.22", "0.22-0.26", "0.26-0.30", "0.30-0.34", "0.34+"],
    )
    return out


def _binary_logloss(y: pd.Series, p: pd.Series) -> float | None:
    if y.empty:
        return None
    try:
        return float(log_loss(y.astype(int), sanitize_prob(p.astype(float).values), labels=[0, 1]))
    except Exception:
        return None


def _segment_status(row: pd.Series) -> str:
    n = int(row["n"])
    roi = float(row["roi"]) if pd.notna(row["roi"]) else np.nan
    ll_edge = float(row["model_minus_market_logloss"]) if pd.notna(row["model_minus_market_logloss"]) else np.nan
    calib_gap = abs(float(row["calibration_gap"])) if pd.notna(row["calibration_gap"]) else np.inf

    if n >= 25 and roi >= 0.03 and ll_edge <= -0.005 and calib_gap <= 0.03:
        return "ACTIVE"
    if n >= 15 and roi >= -0.02 and ll_edge <= 0.01 and calib_gap <= 0.06:
        return "WATCH"
    return "BLOCKED"


def _build_base_frame() -> pd.DataFrame:
    df_all = build_dataset(return_all=True)
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
        build_season_motivation_features(df_all),
        build_opponent_segment_features(df_all, windows=(5, 10)),
        _build_contradiction_features(df_all),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats, target_df=None)
    df_all = add_draw_diff_features(df_all)
    df_all = df_all.merge(build_result_script_features(df_all), on="fixture_id", how="left")
    df_all = add_outcome_scenario_features(df_all)
    return df_all[df_all["has_result"]].copy()


def _run_v3_candidates(df_full: pd.DataFrame) -> pd.DataFrame:
    all_rows: list[pd.DataFrame] = []
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
        categorical = [c for c in BASE_CATEGORICAL_COLS if c in categorical]

        P_cal_cb, P_val_cb = _fit_catboost_multiclass(tr, cal, val, numeric_market, categorical)
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

        draw_cal_feats = _draw_risk_features(cal, P_cal_mkt, P_cal_pois)
        draw_val_feats = _draw_risk_features(val, P_val_mkt, P_val_pois)
        draw_num_cols = list(draw_cal_feats.columns)
        draw_cat_cols = [c for c in categorical if c in cal.columns]
        cal_draw_frame = pd.concat([cal.reset_index(drop=True), draw_cal_feats.reset_index(drop=True)], axis=1)
        val_draw_frame = pd.concat([val.reset_index(drop=True), draw_val_feats.reset_index(drop=True)], axis=1)
        tr_draw_feats = _draw_risk_features(tr, _safe_market_probs(tr), None)
        tr_draw_frame = pd.concat([tr.reset_index(drop=True), tr_draw_feats.reset_index(drop=True)], axis=1)

        try:
            p_cal_draw, p_val_draw = _fit_catboost_binary(
                tr_draw_frame,
                cal_draw_frame,
                val_draw_frame,
                draw_num_cols,
                draw_cat_cols,
                _prepare_y_draw(tr),
                _prepare_y_draw(cal),
            )
        except Exception:
            p_cal_draw = P_cal_mkt[:, 1]
            p_val_draw = P_val_mkt[:, 1]

        tr_side = tr[_prepare_y_draw(tr) == 0].copy()
        cal_side = cal[_prepare_y_draw(cal) == 0].copy()
        try:
            p_cal_side, p_val_side = _fit_catboost_binary(
                tr_side,
                cal_side,
                val.copy(),
                numeric_market,
                categorical,
                _prepare_y_side(tr_side),
                _prepare_y_side(cal_side),
                pred_cal=cal,
                pred_val=val,
            )
        except Exception:
            denom_cal = np.clip(1.0 - P_cal_mkt[:, 1], 1e-6, None)
            denom_val = np.clip(1.0 - P_val_mkt[:, 1], 1e-6, None)
            p_cal_side = np.clip(P_cal_mkt[:, 2] / denom_cal, 1e-6, 1 - 1e-6)
            p_val_side = np.clip(P_val_mkt[:, 2] / denom_val, 1e-6, 1 - 1e-6)

        P_cal_ds = _compose_from_draw_side(p_cal_draw, p_cal_side)
        P_val_ds = _compose_from_draw_side(p_val_draw, p_val_side)
        y_cal = _prepare_y_outcome_3(cal)
        weights, _ = _search_blend_weights(y_cal, P_cal_cb, P_cal_pois, P_cal_mkt, P_cal_ds)
        P_cal_blend = _blend_probs(P_cal_cb, P_cal_pois, P_cal_mkt, P_cal_ds, weights)
        P_val_blend = _blend_probs(P_val_cb, P_val_pois, P_val_mkt, P_val_ds, weights)
        P_cal_blend = _apply_prob_stabilizers(P_cal_blend, P_cal_mkt, P_cal_pois, cal, lid)
        P_val_blend = _apply_prob_stabilizers(P_val_blend, P_val_mkt, P_val_pois, val, lid)
        cal_lr = fit_multinomial_lr_calibrator(P_cal_blend, y_cal)
        P_cal_final = apply_multinomial_lr(P_cal_blend, cal["league_id"], cal_lr, {})
        P_val_final = apply_multinomial_lr(P_val_blend, val["league_id"], cal_lr, {})
        if int(lid) == 39:
            alpha, _ = _search_market_anchor(y_cal, P_cal_final, P_cal_mkt)
            P_val_final = _apply_market_anchor(P_val_final, P_val_mkt, alpha)

        draw_risk = draw_val_feats["draw_risk_score"].reset_index(drop=True)
        val_reset = val.reset_index(drop=True).copy()
        actual = _prepare_y_outcome_3(val_reset)

        league_name = val_reset["league"] if "league" in val_reset.columns else pd.Series(str(lid), index=val_reset.index)

        for outcome_name, outcome_idx, odds_col in OUTCOMES:
            odds = pd.to_numeric(val_reset.get(odds_col), errors="coerce")
            p_model = pd.Series(P_val_final[:, outcome_idx], index=val_reset.index)
            p_market = pd.Series(P_val_mkt[:, outcome_idx], index=val_reset.index)
            won = pd.Series((actual == outcome_idx).astype(int), index=val_reset.index)
            profit = np.where(won == 1, odds - 1.0, -1.0)

            frame = pd.DataFrame(
                {
                    "league_id": lid,
                    "league": league_name.values,
                    "fixture_id": val_reset["fixture_id"].values,
                    "date_utc": val_reset["date_utc"].values,
                    "outcome": outcome_name,
                    "odds": odds.values,
                    "p_model": p_model.values,
                    "p_market": p_market.values,
                    "edge": (p_model - p_market).values,
                    "ev": (p_model * odds - 1.0).values,
                    "draw_risk_score": draw_risk.values,
                    "actual_win": won.values,
                    "profit": profit,
                    "p_catboost": P_val_cb[:, outcome_idx],
                    "p_poisson": P_val_pois[:, outcome_idx],
                    "p_market_base": P_val_mkt[:, outcome_idx],
                    "p_draw_side": P_val_ds[:, outcome_idx],
                }
            )
            frame["odds_bucket"] = _odds_bucket(frame["odds"])
            frame["edge_bucket"] = _edge_bucket(frame["edge"])
            frame["draw_risk_bucket"] = _draw_risk_bucket(frame["draw_risk_score"])
            frame["candidate_is_home"] = (outcome_name == "Home")
            frame["candidate_is_draw"] = (outcome_name == "Draw")
            frame["candidate_is_away"] = (outcome_name == "Away")
            frame["candidate_is_favorite"] = frame["p_market"] == frame.groupby("fixture_id")["p_market"].transform("max")
            frame["clv"] = np.nan
            frame = frame[frame["odds"].notna() & (frame["odds"] > 1.01)].copy()
            if frame.empty:
                continue
            all_rows.append(frame)

    if not all_rows:
        return pd.DataFrame()
    return pd.concat(all_rows, ignore_index=True)


def _summarize_segments(candidates: pd.DataFrame) -> pd.DataFrame:
    records = []
    group_cols = ["league", "outcome", "odds_bucket", "edge_bucket", "draw_risk_bucket"]
    for keys, g in candidates.groupby(group_cols, dropna=False):
        league, outcome, odds_bucket, edge_bucket, draw_risk_bucket = keys
        y = g["actual_win"].astype(int)
        p_model = g["p_model"].astype(float)
        p_market = g["p_market"].astype(float)
        model_ll = _binary_logloss(y, p_model)
        market_ll = _binary_logloss(y, p_market)
        avg_clv = float(g["clv"].mean()) if g["clv"].notna().any() else None

        rec = {
            "league": league,
            "outcome": outcome,
            "odds_bucket": str(odds_bucket),
            "edge_bucket": str(edge_bucket),
            "draw_risk_bucket": str(draw_risk_bucket),
            "n": int(len(g)),
            "model_logloss": model_ll,
            "market_logloss": market_ll,
            "model_minus_market_logloss": None if model_ll is None or market_ll is None else float(model_ll - market_ll),
            "avg_p_model": float(p_model.mean()),
            "actual_win_rate": float(y.mean()),
            "avg_p_market": float(p_market.mean()),
            "calibration_gap": float(p_model.mean() - y.mean()),
            "avg_edge": float(g["edge"].mean()),
            "avg_ev": float(g["ev"].mean()),
            "avg_odds": float(g["odds"].mean()) if g["odds"].notna().any() else None,
            "roi": float(g["profit"].mean()),
            "profit": float(g["profit"].sum()),
            "hit_rate": float(y.mean()),
            "clv": avg_clv,
        }
        rec["status"] = _segment_status(pd.Series(rec))
        records.append(rec)
    out = pd.DataFrame(records)
    if out.empty:
        return out
    return out.sort_values(["status", "roi", "n"], ascending=[True, False, False]).reset_index(drop=True)


def main():
    df_train = _build_base_frame()
    candidates = _run_v3_candidates(df_train)
    candidates.to_csv(OUT_CSV, index=False)

    segments = _summarize_segments(candidates)
    segments.to_csv(OUT_SEGMENTS_CSV, index=False)
    active = segments[segments["status"] == "ACTIVE"].sort_values(["roi", "n"], ascending=[False, False]).head(25)
    watch = segments[segments["status"] == "WATCH"].sort_values(["roi", "n"], ascending=[False, False]).head(25)
    blocked = segments[segments["status"] == "BLOCKED"].sort_values(["roi", "n"], ascending=[True, False]).head(25)

    payload = {
        "overall": {
            "candidate_rows": int(len(candidates)),
            "segments": int(len(segments)),
        },
        "status_counts": segments["status"].value_counts(dropna=False).to_dict(),
        "top_active": active.to_dict(orient="records"),
        "top_watch": watch.to_dict(orient="records"),
        "top_blocked": blocked.to_dict(orient="records"),
    }
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
