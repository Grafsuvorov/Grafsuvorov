import json
from typing import Dict, List, Optional, Tuple

import joblib
import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.isotonic import IsotonicRegression
from sklearn.metrics import brier_score_loss, log_loss

from config import CAL_DAYS, TOTALS_MODEL_PATH, VAL_DAYS
from data.build_dataset import build_dataset
from data.loader import load_stats
from data.splits import recency_weights, temporal_split_by_league
from decision.totals_decision import decide_total_bet
from decision.totals_policy import apply_total_league_policy, should_block_total_candidate
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.totals_features import build_totals_feature_list
from models.inference import predict_totals
from train_totals import select_totals_feature_cols


LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}
TOTALS_AUX_MAX_DELTA = 0.18
TOTALS_AUX_MIN_PROB = 0.08
TOTALS_AUX_MAX_PROB = 0.92
TOTALS_AUX_BLEND_META = 0.72
TOTALS_AUX_BLEND_BASE = 0.18
TOTALS_AUX_BLEND_MKT = 0.10


def _safe_prob(p: np.ndarray) -> np.ndarray:
    arr = np.asarray(p, dtype=float)
    return np.clip(arr, 1e-6, 1.0 - 1e-6)


def _bounded_prob(p: np.ndarray) -> np.ndarray:
    arr = np.asarray(p, dtype=float)
    return np.clip(arr, TOTALS_AUX_MIN_PROB, TOTALS_AUX_MAX_PROB)


def _safe_logit(p: np.ndarray) -> np.ndarray:
    p = _safe_prob(p)
    return np.log(p / (1.0 - p))


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def _compute_p_over_mkt(df: pd.DataFrame) -> np.ndarray:
    over = pd.to_numeric(df.get("avg_odds_over25"), errors="coerce")
    under = pd.to_numeric(df.get("avg_odds_under25"), errors="coerce")
    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    out = imp_over / overround
    return pd.to_numeric(out, errors="coerce").to_numpy(dtype=float)


def _feature_frame() -> pd.DataFrame:
    schedule = build_dataset(return_all=True)
    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(schedule["fixture_id"])].copy()
    feats = build_totals_feature_list(schedule, match_stats, mode="train")
    df = build_feature_matrix(schedule, feats)
    df = add_draw_diff_features(df)
    df["target_btts"] = ((df["home_goals"].fillna(0) > 0) & (df["away_goals"].fillna(0) > 0)).astype(float)
    df["target_open4"] = ((df["home_goals"].fillna(0) + df["away_goals"].fillna(0)) >= 4).astype(float)
    return df[df["has_result"]].copy()


def _binary_target(df: pd.DataFrame, target_col: str) -> np.ndarray:
    return pd.to_numeric(df[target_col], errors="coerce").fillna(0.0).astype(int).to_numpy()


def _fit_aux_model(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    feature_cols: List[str],
    target_col: str,
) -> Dict[str, object]:
    priors = (
        tr[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .mean()
        .fillna(0.0)
        .to_dict()
    )
    x_tr = tr[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0.0)
    x_cal = cal[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0.0)
    y_tr = _binary_target(tr, target_col)
    y_cal = _binary_target(cal, target_col)
    w_tr = recency_weights(tr, ts_col="date_utc", now_override=None)

    dtr = xgb.DMatrix(x_tr, label=y_tr, weight=w_tr, feature_names=feature_cols)
    dcal = xgb.DMatrix(x_cal, label=y_cal, feature_names=feature_cols)
    params = {
        "objective": "binary:logistic",
        "eta": 0.035,
        "max_depth": 6,
        "min_child_weight": 10.0,
        "subsample": 0.90,
        "colsample_bytree": 0.90,
        "lambda": 2.0,
        "alpha": 0.0,
        "tree_method": "hist",
        "eval_metric": "logloss",
        "seed": 123,
    }
    model = xgb.train(
        params,
        dtr,
        num_boost_round=1000,
        evals=[(dtr, "train"), (dcal, "cal")],
        early_stopping_rounds=90,
        verbose_eval=False,
    )
    best_iter = model.best_iteration + 1 if model.best_iteration is not None else None
    p_cal_raw = model.predict(dcal, iteration_range=(0, best_iter)) if best_iter else model.predict(dcal)
    iso = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
    try:
        iso.fit(p_cal_raw, y_cal)
    except Exception:
        iso = None
    return {
        "model": model,
        "best_iter": best_iter,
        "feature_cols": feature_cols,
        "feature_priors": priors,
        "iso": iso,
    }


def _predict_aux(df: pd.DataFrame, bundle: Dict[str, object]) -> np.ndarray:
    feature_cols = bundle["feature_cols"]
    x = (
        df[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .fillna(pd.Series(bundle["feature_priors"]))
        .fillna(0.0)
    )
    dmat = xgb.DMatrix(x, feature_names=feature_cols)
    best_iter = bundle.get("best_iter")
    model = bundle["model"]
    raw = model.predict(dmat, iteration_range=(0, best_iter)) if best_iter else model.predict(dmat)
    iso = bundle.get("iso")
    if iso is not None:
        raw = iso.predict(raw)
    return _safe_prob(raw)


def _fit_final_aux_bundle(df_hist: pd.DataFrame, feature_cols: List[str], target_col: str) -> Optional[Dict[str, object]]:
    if len(df_hist) < 120:
        return None
    hist = df_hist.sort_values("date_utc").copy()
    cal_days = max(int(CAL_DAYS), 45)
    cut = hist["date_utc"].max() - pd.Timedelta(days=cal_days)
    tr = hist[hist["date_utc"] < cut].copy()
    cal = hist[hist["date_utc"] >= cut].copy()
    if len(cal) < 25:
        split_idx = max(int(len(hist) * 0.8), len(hist) - 30)
        tr = hist.iloc[:split_idx].copy()
        cal = hist.iloc[split_idx:].copy()
    if tr.empty or cal.empty:
        return None
    return _fit_aux_model(tr, cal, feature_cols, target_col)


def _tune_meta_weights(shadow_df: pd.DataFrame) -> Dict[str, float]:
    best = None
    p_base = _safe_prob(shadow_df["p_base"].to_numpy())
    p_btts = _safe_prob(shadow_df["p_btts"].to_numpy())
    p_open = _safe_prob(shadow_df["p_open"].to_numpy())
    p_mkt_raw = pd.to_numeric(shadow_df["p_mkt"], errors="coerce").to_numpy(dtype=float)
    p_mkt = np.where(np.isfinite(p_mkt_raw), p_mkt_raw, p_base)
    p_mkt = _safe_prob(p_mkt)
    y = _binary_target(shadow_df, "target_over25")

    for w_btts in np.linspace(-0.6, 1.2, 10):
        for w_open in np.linspace(-0.6, 1.4, 11):
            for w_mkt in np.linspace(0.0, 0.6, 7):
                z = (
                    _safe_logit(p_base)
                    + w_btts * (p_btts - 0.5)
                    + w_open * (p_open - 0.5)
                    + w_mkt * (p_mkt - 0.5)
                )
                p_raw = _safe_prob(_sigmoid(z))
                p = _regularize_meta_output(p_base, p_raw, p_mkt)
                ll = log_loss(y, p, labels=[0, 1])
                br = brier_score_loss(y, p)
                over_share = float((p >= 0.5).mean())
                extreme_rate = float(((p <= 0.10) | (p >= 0.90)).mean())
                drift = float(np.mean(np.abs(p - p_base)))
                key = (
                    ll + 0.08 * extreme_rate + 0.03 * drift,
                    br,
                    abs(over_share - 0.5),
                    extreme_rate,
                    drift,
                )
                if best is None or key < best["key"]:
                    best = {
                        "key": key,
                        "weights": {
                            "w_btts": float(w_btts),
                            "w_open": float(w_open),
                            "w_mkt": float(w_mkt),
                        },
                        "ll": float(ll),
                        "brier": float(br),
                    }
    return best


def _regularize_meta_output(p_base: np.ndarray, p_meta: np.ndarray, p_mkt: np.ndarray) -> np.ndarray:
    p_base = _safe_prob(p_base)
    p_meta = _safe_prob(p_meta)
    p_mkt = np.where(np.isfinite(p_mkt), p_mkt, p_base)
    p_mkt = _safe_prob(p_mkt)

    mixed = (
        TOTALS_AUX_BLEND_META * p_meta
        + TOTALS_AUX_BLEND_BASE * p_base
        + TOTALS_AUX_BLEND_MKT * p_mkt
    )
    delta = np.clip(mixed - p_base, -TOTALS_AUX_MAX_DELTA, TOTALS_AUX_MAX_DELTA)
    return _bounded_prob(p_base + delta)


def _apply_meta(p_base: np.ndarray, p_btts: np.ndarray, p_open: np.ndarray, p_mkt: np.ndarray, weights: Dict[str, float]) -> np.ndarray:
    p_mkt = np.where(np.isfinite(p_mkt), p_mkt, p_base)
    z = (
        _safe_logit(p_base)
        + float(weights["w_btts"]) * (_safe_prob(p_btts) - 0.5)
        + float(weights["w_open"]) * (_safe_prob(p_open) - 0.5)
        + float(weights["w_mkt"]) * (_safe_prob(p_mkt) - 0.5)
    )
    p_raw = _safe_prob(_sigmoid(z))
    return _regularize_meta_output(p_base, p_raw, p_mkt)


def _profit_total(row: pd.Series) -> float:
    goals = float(row["home_goals"]) + float(row["away_goals"])
    if row["best_bet_outcome"] == "Over2.5":
        return float(row["avg_odds_over25"]) - 1.0 if goals > 2.5 else -1.0
    return float(row["avg_odds_under25"]) - 1.0 if goals <= 2.5 else -1.0


def _pick_totals(df: pd.DataFrame, p_over: np.ndarray) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)
    out["p_over25"] = _safe_prob(p_over)
    out["p_under25"] = 1.0 - out["p_over25"]
    out["p_market"] = _compute_p_over_mkt(out)

    best_type = []
    best_outcome = []
    best_odds = []
    best_ev = []
    best_tier = []

    for row in out.itertuples(index=False):
        row_dict = row._asdict()
        candidates: List[Tuple[str, str, float, float]] = []
        for outcome, prob_key, odds_key in [
            ("Over2.5", "p_over25", "avg_odds_over25"),
            ("Under2.5", "p_under25", "avg_odds_under25"),
        ]:
            odds = row_dict.get(odds_key)
            prob = row_dict.get(prob_key)
            if odds is None or not np.isfinite(odds) or odds < 1.01:
                continue
            ev_val = float(prob) * float(odds) - 1.0
            if outcome == "Over2.5" and should_block_total_candidate(row_dict, outcome):
                continue
            tier = decide_total_bet(ev_val, float(odds), int(row_dict["league_id"]), float(prob))
            if tier == "NO BET":
                continue
            candidates.append(("TOTAL", outcome, float(odds), float(ev_val)))

        candidates = apply_total_league_policy(row_dict, candidates)
        if not candidates:
            best_type.append(None)
            best_outcome.append(None)
            best_odds.append(np.nan)
            best_ev.append(np.nan)
            best_tier.append(None)
            continue

        market, outcome, odds, ev_val = max(candidates, key=lambda x: x[3])
        tier = decide_total_bet(ev_val, odds, int(row_dict["league_id"]), row_dict["p_over25"] if outcome == "Over2.5" else row_dict["p_under25"])
        best_type.append(market)
        best_outcome.append(outcome)
        best_odds.append(odds)
        best_ev.append(ev_val)
        best_tier.append(tier)

    out["best_bet_type"] = best_type
    out["best_bet_outcome"] = best_outcome
    out["best_bet_odds"] = best_odds
    out["best_bet_ev"] = best_ev
    out["bet_rating"] = best_tier
    mask = out["best_bet_outcome"].notna()
    out["profit"] = 0.0
    out.loc[mask, "profit"] = out.loc[mask].apply(_profit_total, axis=1)
    return out


def _summary(df: pd.DataFrame) -> Dict[str, object]:
    bets = df[df["best_bet_outcome"].notna()].copy()
    n = len(bets)
    profit = float(bets["profit"].sum())
    roi = (profit / n) if n else None
    return {
        "bets": int(n),
        "profit": profit,
        "roi": roi,
    }


def _by_league(df: pd.DataFrame) -> Dict[str, Dict[str, object]]:
    out: Dict[str, Dict[str, object]] = {}
    for lid in sorted(df["league_id"].dropna().astype(int).unique()):
        part = df[df["league_id"] == lid].copy()
        out[LEAGUE_NAMES.get(lid, str(lid))] = _summary(part)
    return out


def _hybrid_positive_only(
    test: pd.DataFrame,
    p_base: np.ndarray,
    p_meta: np.ndarray,
) -> np.ndarray:
    out = _safe_prob(np.asarray(p_base, dtype=float).copy())
    positive_lids = {39, 61, 78}
    mask = test["league_id"].astype(int).isin(positive_lids).to_numpy()
    out[mask] = _safe_prob(np.asarray(p_meta, dtype=float)[mask])
    return out


def _hybrid_with_antiover(
    test: pd.DataFrame,
    p_base: np.ndarray,
    p_meta: np.ndarray,
    p_btts: np.ndarray,
    p_open: np.ndarray,
    p_market: np.ndarray,
) -> np.ndarray:
    out = _hybrid_positive_only(test, p_base, p_meta)
    lids = test["league_id"].astype(int).to_numpy()
    p_btts = _safe_prob(p_btts)
    p_open = _safe_prob(p_open)
    p_market = np.where(np.isfinite(p_market), p_market, out)
    p_market = _safe_prob(p_market)

    for i, lid in enumerate(lids):
        if lid not in {135, 140}:
            continue
        # In Serie A / La Liga prefer not to inflate tempo.
        # If model already leans over, but BTTS/open signals are weak and market is not pushing over,
        # pull the probability down towards a more conservative midpoint.
        if out[i] >= 0.54:
            weak_btts = p_btts[i] <= 0.53
            weak_open = p_open[i] <= 0.34
            market_not_over = p_market[i] <= 0.52
            if weak_btts and weak_open:
                out[i] = 0.55 * out[i] + 0.45 * min(p_market[i], 0.50)
            elif weak_open and market_not_over:
                out[i] = 0.72 * out[i] + 0.28 * min(p_market[i], 0.50)
            elif weak_btts and market_not_over:
                out[i] = 0.76 * out[i] + 0.24 * min(p_market[i], 0.50)
    return _safe_prob(out)


def run() -> Dict[str, object]:
    df = _feature_frame()
    eval_season = int(df["season"].max())
    hist = df[df["season"].astype(int) < eval_season].copy()
    test = df[df["season"].astype(int) == eval_season].copy()
    total_model = joblib.load(TOTALS_MODEL_PATH)

    # Baseline: current prod model on current season.
    p_over_base_test = predict_totals(test, total_model)
    base_eval = _pick_totals(test, p_over_base_test)

    meta_probs = pd.Series(np.nan, index=test.index, dtype=float)
    aux_btts = pd.Series(np.nan, index=test.index, dtype=float)
    aux_open = pd.Series(np.nan, index=test.index, dtype=float)
    meta_weights = {}

    for lid in sorted(hist["league_id"].dropna().astype(int).unique()):
        hist_l = hist[hist["league_id"] == lid].copy().sort_values("date_utc")
        test_l = test[test["league_id"] == lid].copy().sort_values("date_utc")
        if hist_l.empty or test_l.empty or len(hist_l) < 160:
            continue

        tr, cal, val = temporal_split_by_league(
            hist_l,
            ts_col="date_utc",
            league_col="league_id",
            cal_days=CAL_DAYS,
            val_days=VAL_DAYS,
            gap_days=0,
            min_cal_per_league=12,
            min_val_per_league=6,
            now_override=None,
        )
        if tr.empty or cal.empty or val.empty:
            continue

        feature_cols = select_totals_feature_cols(hist_l)
        base_shadow = _fit_aux_model(tr, cal, feature_cols, "target_over25")
        btts_shadow = _fit_aux_model(tr, cal, feature_cols, "target_btts")
        open_shadow = _fit_aux_model(tr, cal, feature_cols, "target_open4")

        shadow_df = val.copy().reset_index(drop=True)
        shadow_df["p_base"] = _predict_aux(val, base_shadow)
        shadow_df["p_btts"] = _predict_aux(val, btts_shadow)
        shadow_df["p_open"] = _predict_aux(val, open_shadow)
        shadow_df["p_mkt"] = _compute_p_over_mkt(val)

        tuned = _tune_meta_weights(shadow_df)
        meta_weights[int(lid)] = tuned

        base_full = _fit_final_aux_bundle(hist_l, feature_cols, "target_over25")
        btts_full = _fit_final_aux_bundle(hist_l, feature_cols, "target_btts")
        open_full = _fit_final_aux_bundle(hist_l, feature_cols, "target_open4")
        if base_full is None or btts_full is None or open_full is None:
            continue

        part_idx = test_l.index
        p_base_local = _safe_prob(predict_totals(test_l, total_model))
        p_btts_local = _predict_aux(test_l, btts_full)
        p_open_local = _predict_aux(test_l, open_full)
        p_mkt_local = _compute_p_over_mkt(test_l)
        meta_probs.loc[part_idx] = _apply_meta(
            p_base_local,
            p_btts_local,
            p_open_local,
            p_mkt_local,
            tuned["weights"],
        )
        aux_btts.loc[part_idx] = p_btts_local
        aux_open.loc[part_idx] = p_open_local

    meta_probs = meta_probs.reindex(test.index)
    fallback = meta_probs.isna().to_numpy()
    meta_arr = meta_probs.to_numpy(dtype=float)
    meta_arr[fallback] = p_over_base_test[fallback]
    p_market_test = _compute_p_over_mkt(test)
    aux_btts = aux_btts.reindex(test.index)
    aux_open = aux_open.reindex(test.index)
    aux_btts_arr = aux_btts.to_numpy(dtype=float)
    aux_open_arr = aux_open.to_numpy(dtype=float)
    aux_btts_arr[np.isnan(aux_btts_arr)] = p_over_base_test[np.isnan(aux_btts_arr)]
    aux_open_arr[np.isnan(aux_open_arr)] = p_over_base_test[np.isnan(aux_open_arr)]

    meta_eval = _pick_totals(test, meta_arr)
    hybrid_positive = _hybrid_positive_only(test, p_over_base_test, meta_arr)
    hybrid_positive_eval = _pick_totals(test, hybrid_positive)
    hybrid_antiover = _hybrid_with_antiover(
        test,
        p_over_base_test,
        meta_arr,
        aux_btts_arr,
        aux_open_arr,
        p_market_test,
    )
    hybrid_antiover_eval = _pick_totals(test, hybrid_antiover)

    wrong_over_base = base_eval[(base_eval["best_bet_outcome"] == "Over2.5") & ((base_eval["home_goals"] + base_eval["away_goals"]) <= 2)].copy()
    wrong_over_meta = meta_eval[(meta_eval["best_bet_outcome"] == "Over2.5") & ((meta_eval["home_goals"] + meta_eval["away_goals"]) <= 2)].copy()
    wrong_over_hybrid_positive = hybrid_positive_eval[
        (hybrid_positive_eval["best_bet_outcome"] == "Over2.5")
        & ((hybrid_positive_eval["home_goals"] + hybrid_positive_eval["away_goals"]) <= 2)
    ].copy()
    wrong_over_hybrid_antiover = hybrid_antiover_eval[
        (hybrid_antiover_eval["best_bet_outcome"] == "Over2.5")
        & ((hybrid_antiover_eval["home_goals"] + hybrid_antiover_eval["away_goals"]) <= 2)
    ].copy()

    result = {
        "eval_season": eval_season,
        "baseline": _summary(base_eval),
        "meta": _summary(meta_eval),
        "hybrid_positive_only": _summary(hybrid_positive_eval),
        "hybrid_with_antiover": _summary(hybrid_antiover_eval),
        "baseline_by_league": _by_league(base_eval),
        "meta_by_league": _by_league(meta_eval),
        "hybrid_positive_only_by_league": _by_league(hybrid_positive_eval),
        "hybrid_with_antiover_by_league": _by_league(hybrid_antiover_eval),
        "wrong_over": {
            "baseline": int(len(wrong_over_base)),
            "meta": int(len(wrong_over_meta)),
            "hybrid_positive_only": int(len(wrong_over_hybrid_positive)),
            "hybrid_with_antiover": int(len(wrong_over_hybrid_antiover)),
        },
        "weights": {
            LEAGUE_NAMES.get(lid, str(lid)): info
            for lid, info in meta_weights.items()
        },
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return result


if __name__ == "__main__":
    run()
