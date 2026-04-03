from typing import Dict, List, Optional

import joblib
import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.isotonic import IsotonicRegression

from config import CAL_DAYS, OUTCOME_AUX_MODEL_PATH


OUTCOME_AUX_LEAGUES = {39, 61, 78, 135}


def _safe_prob(p):
    arr = np.asarray(p, dtype=float)
    return np.clip(arr, 1e-6, 1.0 - 1e-6)


def _candidate_rows(df: pd.DataFrame) -> pd.DataFrame:
    parts = []
    df = df.loc[:, ~df.columns.duplicated()].copy()
    base_cols = [
        "fixture_id",
        "league_id",
        "date_utc",
        "home_goals",
        "away_goals",
        "p_home",
        "p_draw",
        "p_away",
        "avg_odds_home",
        "avg_odds_draw",
        "avg_odds_away",
        "tp_match_balance_abs",
        "tp_match_openness",
        "home_xg_ema",
        "away_xg_ema",
        "home_us_npxg_all_5",
        "away_us_npxg_all_5",
        "tp_home_attack_xg",
        "tp_away_attack_xg",
        "tp_match_balance_abs",
        "tp_match_openness",
        "rs_draw_rate_diff",
        "rs_close_game_diff",
        "rs_fav_conversion_diff",
        "rs_dog_resilience_diff",
        "rs_fav_drop_diff",
        "osc_control_understat_diff",
        "osc_transition_matchup_diff",
        "osc_front_run_edge",
        "osc_draw_balance_elo_abs",
        "osc_draw_balance_control_abs",
        "osc_draw_balance_front_abs",
        "osc_draw_low_event_proxy",
        "osc_draw_script_diff",
        "osc_close_script_diff",
        "osc_fav_conversion_diff",
        "osc_dog_resilience_diff",
        "osc_fav_drop_diff",
    ]
    src = df[[c for c in base_cols if c in df.columns]].copy()
    side_map = [
        ("Home", "p_home", "avg_odds_home", lambda x: x["home_goals"] > x["away_goals"]),
        ("Draw", "p_draw", "avg_odds_draw", lambda x: x["home_goals"] == x["away_goals"]),
        ("Away", "p_away", "avg_odds_away", lambda x: x["home_goals"] < x["away_goals"]),
    ]
    for side, p_col, o_col, fn in side_map:
        part = src.copy()
        part["candidate"] = side
        part["candidate_prob"] = pd.to_numeric(part.get(p_col), errors="coerce")
        part["candidate_odds"] = pd.to_numeric(part.get(o_col), errors="coerce")
        part["candidate_ev"] = part["candidate_prob"] * part["candidate_odds"] - 1.0
        part["target_win"] = fn(part).astype(int)
        part["cand_home"] = 1 if side == "Home" else 0
        part["cand_draw"] = 1 if side == "Draw" else 0
        part["cand_away"] = 1 if side == "Away" else 0
        parts.append(part)
    out = pd.concat(parts, ignore_index=True)
    out = out[np.isfinite(out["candidate_prob"]) & np.isfinite(out["candidate_odds"])]
    return out


def _feature_cols(df: pd.DataFrame) -> List[str]:
    cols = [
        "candidate_prob",
        "candidate_odds",
        "candidate_ev",
        "p_home",
        "p_draw",
        "p_away",
        "tp_match_balance_abs",
        "tp_match_openness",
        "home_xg_ema",
        "away_xg_ema",
        "home_us_npxg_all_5",
        "away_us_npxg_all_5",
        "tp_home_attack_xg",
        "tp_away_attack_xg",
        "tp_match_balance_abs",
        "tp_match_openness",
        "rs_draw_rate_diff",
        "rs_close_game_diff",
        "rs_fav_conversion_diff",
        "rs_dog_resilience_diff",
        "rs_fav_drop_diff",
        "osc_control_understat_diff",
        "osc_transition_matchup_diff",
        "osc_front_run_edge",
        "osc_draw_balance_elo_abs",
        "osc_draw_balance_control_abs",
        "osc_draw_balance_front_abs",
        "osc_draw_low_event_proxy",
        "osc_draw_script_diff",
        "osc_close_script_diff",
        "osc_fav_conversion_diff",
        "osc_dog_resilience_diff",
        "osc_fav_drop_diff",
        "cand_home",
        "cand_draw",
        "cand_away",
    ]
    seen = set()
    out: List[str] = []
    for c in cols:
        if c in df.columns and c not in seen:
            seen.add(c)
            out.append(c)
    return out


def _fit_binary(tr: pd.DataFrame, cal: pd.DataFrame, feature_cols: List[str]) -> Dict[str, object]:
    tr = tr.loc[:, ~tr.columns.duplicated()].copy()
    cal = cal.loc[:, ~cal.columns.duplicated()].copy()
    priors = (
        tr[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .mean()
        .fillna(0.0)
        .to_dict()
    )
    x_tr = tr[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0.0)
    x_cal = cal[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0.0)
    y_tr = tr["target_win"].astype(int).to_numpy()
    y_cal = cal["target_win"].astype(int).to_numpy()
    dtr = xgb.DMatrix(x_tr, label=y_tr, feature_names=feature_cols)
    dcal = xgb.DMatrix(x_cal, label=y_cal, feature_names=feature_cols)
    model = xgb.train(
        {
            "objective": "binary:logistic",
            "eta": 0.04,
            "max_depth": 4,
            "min_child_weight": 8.0,
            "subsample": 0.9,
            "colsample_bytree": 0.9,
            "lambda": 2.0,
            "alpha": 0.0,
            "tree_method": "hist",
            "eval_metric": "logloss",
            "seed": 123,
        },
        dtr,
        num_boost_round=600,
        evals=[(dtr, "train"), (dcal, "cal")],
        early_stopping_rounds=60,
        verbose_eval=False,
    )
    best_iter = model.best_iteration + 1 if model.best_iteration is not None else None
    raw = model.predict(dcal, iteration_range=(0, best_iter)) if best_iter else model.predict(dcal)
    iso = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
    try:
        iso.fit(raw, y_cal)
    except Exception:
        iso = None
    return {
        "model": model,
        "best_iter": best_iter,
        "feature_cols": feature_cols,
        "feature_priors": priors,
        "iso": iso,
    }


def _predict(df: pd.DataFrame, bundle: Dict[str, object]) -> np.ndarray:
    feature_cols = bundle["feature_cols"]
    local = df.loc[:, ~df.columns.duplicated()].copy()
    for col in feature_cols:
        if col not in local.columns:
            local[col] = np.nan
    x = (
        local[feature_cols]
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


def _roi_of_threshold(df: pd.DataFrame, p_good: np.ndarray, threshold: float) -> tuple[float, int]:
    chosen = df[p_good >= threshold].copy()
    if chosen.empty:
        return -999.0, 0
    profit = np.where(chosen["target_win"].astype(bool), chosen["candidate_odds"] - 1.0, -1.0).sum()
    roi = float(profit) / float(len(chosen))
    return roi, int(len(chosen))


def train_outcome_auxiliary(df_train: pd.DataFrame) -> Dict[str, object]:
    bundle: Dict[str, object] = {"leagues": {}}
    for lid in sorted(OUTCOME_AUX_LEAGUES):
        hist = df_train[df_train["league_id"].astype(int) == lid].copy()
        if len(hist) < 120:
            continue
        cand = _candidate_rows(hist)
        if len(cand) < 180:
            continue
        cand = cand.sort_values("date_utc")
        cut = cand["date_utc"].max() - pd.Timedelta(days=max(int(CAL_DAYS), 45))
        tr = cand[cand["date_utc"] < cut].copy()
        cal = cand[cand["date_utc"] >= cut].copy()
        if len(cal) < 60:
            split_idx = max(int(len(cand) * 0.8), len(cand) - 90)
            tr = cand.iloc[:split_idx].copy()
            cal = cand.iloc[split_idx:].copy()
        if tr.empty or cal.empty:
            continue
        feature_cols = _feature_cols(cand)
        local = _fit_binary(tr, cal, feature_cols)
        p_cal = _predict(cal, local)
        best = None
        for threshold in np.linspace(0.48, 0.66, 10):
            roi, n_bets = _roi_of_threshold(cal, p_cal, float(threshold))
            if n_bets < 8:
                continue
            key = (roi, -n_bets)
            if best is None or key > best["key"]:
                best = {"key": key, "threshold": float(threshold)}
        if best is None:
            continue
        full = _fit_binary(tr, cal, feature_cols)
        bundle["leagues"][int(lid)] = {
            "model": full,
            "threshold": best["threshold"],
        }

    joblib.dump(bundle, OUTCOME_AUX_MODEL_PATH)
    return bundle


def apply_outcome_auxiliary(df: pd.DataFrame, candidates: List[tuple], aux_bundle: Optional[Dict[str, object]]) -> List[tuple]:
    if not aux_bundle or "leagues" not in aux_bundle:
        return candidates
    league_id = int(df.get("league_id")) if pd.notna(df.get("league_id")) else None
    info = aux_bundle.get("leagues", {}).get(league_id)
    if info is None:
        return candidates
    rows = []
    for market, outcome, odds, edge in candidates:
        if market != "1X2":
            rows.append((market, outcome, odds, edge))
            continue
        rec = df.copy()
        rec["candidate"] = outcome
        rec["candidate_prob"] = rec.get(f"p_{outcome.lower()}" if outcome != "Draw" else "p_draw")
        if outcome == "Home":
            rec["candidate_prob"] = rec.get("p_home")
        elif outcome == "Away":
            rec["candidate_prob"] = rec.get("p_away")
        else:
            rec["candidate_prob"] = rec.get("p_draw")
        rec["candidate_odds"] = odds
        rec["candidate_ev"] = edge
        rec["cand_home"] = 1 if outcome == "Home" else 0
        rec["cand_draw"] = 1 if outcome == "Draw" else 0
        rec["cand_away"] = 1 if outcome == "Away" else 0
        rows.append(rec)
    one_x2 = [r for r in rows if isinstance(r, dict)]
    if not one_x2:
        return candidates
    aux_df = pd.DataFrame(one_x2)
    p_good = _predict(aux_df, info["model"])
    out: List[tuple] = []
    idx = 0
    for item in candidates:
        if item[0] != "1X2":
            out.append(item)
            continue
        if p_good[idx] >= float(info["threshold"]):
            out.append(item)
        idx += 1
    return out
