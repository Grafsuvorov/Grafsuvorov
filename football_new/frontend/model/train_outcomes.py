# train_outcomes.py
# Обучение модели исхода матча (1X2) с Poisson-веткой и калибровкой.

import numpy as np
import pandas as pd
from typing import List, Dict, Any, Optional

from sklearn.linear_model import LogisticRegression
from sklearn.metrics import log_loss, classification_report

import joblib
import xgboost as xgb

from data.splits import temporal_split_by_league
from models.xgb_outcome import train_xgb_outcome
from models.poisson import train_poisson_pair, build_poisson_probs_for_arrays
from models.blending import (
    sanitize_prob,
    blend_poisson_and_xgb,
    apply_market_anchor,
    apply_draw_cap,
)
from config import (
    OUTCOME_MODEL_PATH,
    CAL_DAYS,
    VAL_DAYS,
    GAP_DAYS,
    DRAW_CAP_MAX,
    DRAW_CAP_MIN,
    OUTCOME_XGB_PARAMS_BY_LEAGUE,
    OUTCOMES_USE_SELECTED_TEAM_POTENTIAL,
    OUTCOMES_TEAM_POTENTIAL_SELECTED_FEATURES,
    USE_SELECTED_PLAYER_CONTRIBUTION,
    PLAYER_CONTRIBUTION_SELECTED_FEATURES,
    USE_SELECTED_LINEUP_STRENGTH,
    LINEUP_STRENGTH_SELECTED_FEATURES,
)


def _safe_logit(p: np.ndarray) -> np.ndarray:
    p = np.clip(p.astype(float), 1e-6, 1 - 1e-6)
    return np.log(p / (1 - p))


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def _apply_draw_prior(P: np.ndarray, prior_draw: float, gamma: float) -> np.ndarray:
    if gamma <= 0 or prior_draw <= 0 or prior_draw >= 1:
        return sanitize_prob(P)

    P = sanitize_prob(P)
    pD = P[:, 1]
    new_pD = (1.0 - gamma) * pD + gamma * float(prior_draw)

    old_draw = np.clip(pD, 1e-6, 1 - 1e-6)
    scale = np.clip((1.0 - new_pD) / (1.0 - old_draw), 0.0, 10.0)
    P[:, 0] = P[:, 0] * scale
    P[:, 2] = P[:, 2] * scale
    P[:, 1] = new_pD
    return sanitize_prob(P)


def _predict_with_draw_threshold(P: np.ndarray, threshold: float) -> np.ndarray:
    if threshold <= 0:
        return P.argmax(axis=1)
    pD = P[:, 1]
    preds = P.argmax(axis=1)
    preds[pD >= threshold] = 1
    return preds


def _draw_f1(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    tp = np.sum((y_true == 1) & (y_pred == 1))
    fp = np.sum((y_true != 1) & (y_pred == 1))
    fn = np.sum((y_true == 1) & (y_pred != 1))
    denom = (2 * tp + fp + fn)
    return float((2 * tp) / denom) if denom > 0 else 0.0


def _macro_f1(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    f1s = []
    for cls in (0, 1, 2):
        tp = np.sum((y_true == cls) & (y_pred == cls))
        fp = np.sum((y_true != cls) & (y_pred == cls))
        fn = np.sum((y_true == cls) & (y_pred != cls))
        denom = (2 * tp + fp + fn)
        f1s.append((2 * tp) / denom if denom > 0 else 0.0)
    return float(np.mean(f1s)) if f1s else 0.0


def _predict_with_draw_rule(
    P: np.ndarray,
    df: pd.DataFrame,
    threshold: float,
    max_elo_diff: float,
    max_goal_diff: float,
) -> np.ndarray:
    preds = P.argmax(axis=1)
    if threshold <= 0:
        return preds

    mask = np.ones(len(df), dtype=bool)
    if "elo_diff" in df.columns and np.isfinite(max_elo_diff):
        mask &= df["elo_diff"].abs().values <= max_elo_diff
    if "goal_diff_avg_6_diff" in df.columns and np.isfinite(max_goal_diff):
        mask &= df["goal_diff_avg_6_diff"].abs().values <= max_goal_diff

    p_draw = P[:, 1]
    use = mask & (p_draw >= threshold)
    preds[use] = 1
    return preds


def _apply_league_prob_bias_scaled(P: np.ndarray, delta: np.ndarray, scale: float) -> np.ndarray:
    if scale <= 0:
        return sanitize_prob(P)
    return sanitize_prob(P + (delta.reshape(1, -1) * float(scale)))


# =========================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# =========================

MARKET_COLS_1X2 = [
    "p_home_norm",
    "p_draw_norm",
    "p_away_norm",
    "overround_1x2",
    "n_bookmakers",
]

MARKET_COLS_ALL = MARKET_COLS_1X2 + [
    "avg_odds_home",
    "avg_odds_draw",
    "avg_odds_away",
    "avg_odds_over25",
    "avg_odds_under25",
    "p_over_mkt",
]

TEAM_POTENTIAL_PREFIX = "tp_"
PLAYER_CONTRIBUTION_PREFIXES = ("home_pl_", "away_pl_", "pl_")
LINEUP_STRENGTH_PREFIXES = ("home_ls_", "away_ls_", "ls_")


def build_safe_feature_list(df: pd.DataFrame) -> List[str]:
    """
    Строим список фич:
      - только числовые
      - без таргетов, ключей и рыночных колонок
      - без сырых голов/скора
    """
    drop_exact = {
        "fixture_id",
        "season",
        "league_id",
        "home_team_id",
        "away_team_id",
        "date_utc",
        "home_goals",
        "away_goals",
        "target_result",
        "target_over25",
        "has_result",
    } | set(MARKET_COLS_ALL)

    num_cols = []
    for c in df.columns:
        if c in drop_exact:
            continue
        if pd.api.types.is_numeric_dtype(df[c]):
            num_cols.append(c)

    safe = []
    selected_team_potential = set(OUTCOMES_TEAM_POTENTIAL_SELECTED_FEATURES)
    selected_player_contribution = set(PLAYER_CONTRIBUTION_SELECTED_FEATURES)
    selected_lineup_strength = set(LINEUP_STRENGTH_SELECTED_FEATURES)
    for c in num_cols:
        lc = c.lower()
        # выкидываем явные goal / score если не агрегаты
        if ("goal" in lc or "score" in lc) and not any(
            sfx in lc
            for sfx in ("_mean_", "_std_", "_ema_", "_slope_", "_sum_", "_avg_")
        ):
            continue
        if c.startswith(TEAM_POTENTIAL_PREFIX) and OUTCOMES_USE_SELECTED_TEAM_POTENTIAL and c not in selected_team_potential:
            continue
        if c.startswith(PLAYER_CONTRIBUTION_PREFIXES) and USE_SELECTED_PLAYER_CONTRIBUTION and c not in selected_player_contribution:
            continue
        if c.startswith(LINEUP_STRENGTH_PREFIXES) and USE_SELECTED_LINEUP_STRENGTH and c not in selected_lineup_strength:
            continue
        safe.append(c)

    safe = sorted(set(safe))
    print(f"[FEATS] numeric safe features: {len(safe)}")
    return safe


def _prepare_y_outcome_3(df: pd.DataFrame) -> np.ndarray:
    """
    0 = Away, 1 = Draw, 2 = Home
    """
    h = df["home_goals"].astype(float)
    a = df["away_goals"].astype(float)
    y = np.where(h > a, 2, np.where(h < a, 0, 1))
    return y.astype(int)


def _prepare_y_draw(df: pd.DataFrame) -> np.ndarray:
    h = df["home_goals"].astype(float)
    a = df["away_goals"].astype(float)
    return (h == a).astype(int).values


def _prepare_y_homeaway(df: pd.DataFrame) -> np.ndarray:
    h = df["home_goals"].astype(float)
    a = df["away_goals"].astype(float)
    return (h > a).astype(int).values


def _build_X(df: pd.DataFrame, feature_cols: List[str]) -> pd.DataFrame:
    return df[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0)


def _train_stage_models(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    val: pd.DataFrame,
    feature_cols: List[str],
) -> Dict[str, Any]:
    X_tr = _build_X(tr, feature_cols)
    X_cal = _build_X(cal, feature_cols)
    X_val = _build_X(val, feature_cols)

    # Draw vs not-draw
    y_tr_draw = _prepare_y_draw(tr)
    y_cal_draw = _prepare_y_draw(cal)
    y_val_draw = _prepare_y_draw(val)

    pos = max(float(y_tr_draw.sum()), 1.0)
    neg = max(float(len(y_tr_draw) - y_tr_draw.sum()), 1.0)
    spw = neg / pos
    spw = min(spw * 2.5, 30.0)

    draw_feature_cols = [
        c for c in feature_cols
        if c.endswith("_diff") or c.endswith("_abs_diff") or c == "league_draw_rate"
    ]
    if not draw_feature_cols:
        draw_feature_cols = feature_cols

    draw_feature_priors = (
        tr[draw_feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .mean()
        .fillna(0.0)
        .to_dict()
    )

    X_tr_draw = _build_X(tr, draw_feature_cols)
    X_cal_draw = _build_X(cal, draw_feature_cols)
    X_val_draw = _build_X(val, draw_feature_cols)

    dtr = xgb.DMatrix(X_tr_draw, label=y_tr_draw, feature_names=draw_feature_cols)
    dcal = xgb.DMatrix(X_cal_draw, label=y_cal_draw, feature_names=draw_feature_cols)
    dval = xgb.DMatrix(X_val_draw, label=y_val_draw, feature_names=draw_feature_cols)

    params = {
        "objective": "binary:logistic",
        "eta": 0.04,
        "max_depth": 6,
        "min_child_weight": 8.0,
        "subsample": 0.9,
        "colsample_bytree": 0.9,
        "lambda": 2.0,
        "alpha": 0.0,
        "scale_pos_weight": spw,
        "tree_method": "hist",
        "eval_metric": "logloss",
        "seed": 123,
    }

    draw_model = xgb.train(
        params,
        dtr,
        num_boost_round=600,
        evals=[(dtr, "train"), (dcal, "cal")],
        early_stopping_rounds=60,
        verbose_eval=False,
    )
    best_iter_draw = draw_model.best_iteration + 1 if draw_model.best_iteration is not None else None
    p_cal_draw = draw_model.predict(dcal, iteration_range=(0, best_iter_draw)) if best_iter_draw else draw_model.predict(dcal)
    p_val_draw = draw_model.predict(dval, iteration_range=(0, best_iter_draw)) if best_iter_draw else draw_model.predict(dval)

    # market blend for draw-prob
    draw_market_alpha = 0.0
    if "p_draw_norm" in cal.columns and "p_draw_norm" in val.columns:
        p_mkt_cal = sanitize_prob(cal["p_draw_norm"].astype(float).values)
        p_mkt_val = sanitize_prob(val["p_draw_norm"].astype(float).values)
        best = (0.0, log_loss(y_cal_draw, p_cal_draw, labels=[0, 1]))
        for a in np.linspace(0.0, 0.8, 9):
            mix = sanitize_prob((1.0 - a) * p_cal_draw + a * p_mkt_cal)
            ll = log_loss(y_cal_draw, mix, labels=[0, 1])
            if ll < best[1]:
                best = (float(a), float(ll))
        draw_market_alpha = best[0]
        if draw_market_alpha > 0:
            p_cal_draw = sanitize_prob((1.0 - draw_market_alpha) * p_cal_draw + draw_market_alpha * p_mkt_cal)
            p_val_draw = sanitize_prob((1.0 - draw_market_alpha) * p_val_draw + draw_market_alpha * p_mkt_val)

    # Home vs Away (only non-draw matches)
    tr_nd = tr[tr["home_goals"] != tr["away_goals"]]
    cal_nd = cal[cal["home_goals"] != cal["away_goals"]]
    if tr_nd.empty or cal_nd.empty:
        return {
            "draw_model": draw_model,
            "draw_best_iter": best_iter_draw,
            "p_cal_draw": sanitize_prob(p_cal_draw),
            "p_val_draw": sanitize_prob(p_val_draw),
            "homeaway_model": None,
            "homeaway_best_iter": None,
            "p_cal_home": None,
            "p_val_home": None,
        }

    X_tr_nd = _build_X(tr_nd, feature_cols)
    X_cal_nd = _build_X(cal_nd, feature_cols)
    y_tr_home = _prepare_y_homeaway(tr_nd)
    y_cal_home = _prepare_y_homeaway(cal_nd)

    pos_ha = max(float(y_tr_home.sum()), 1.0)
    neg_ha = max(float(len(y_tr_home) - y_tr_home.sum()), 1.0)
    spw_ha = neg_ha / pos_ha

    dtr_ha = xgb.DMatrix(X_tr_nd, label=y_tr_home, feature_names=feature_cols)
    dcal_ha = xgb.DMatrix(X_cal_nd, label=y_cal_home, feature_names=feature_cols)

    params_ha = {
        "objective": "binary:logistic",
        "eta": 0.05,
        "max_depth": 6,
        "min_child_weight": 6.0,
        "subsample": 0.9,
        "colsample_bytree": 0.9,
        "lambda": 2.0,
        "alpha": 0.0,
        "scale_pos_weight": spw_ha,
        "tree_method": "hist",
        "eval_metric": "logloss",
        "seed": 123,
    }

    homeaway_model = xgb.train(
        params_ha,
        dtr_ha,
        num_boost_round=600,
        evals=[(dtr_ha, "train"), (dcal_ha, "cal")],
        early_stopping_rounds=60,
        verbose_eval=False,
    )
    best_iter_ha = homeaway_model.best_iteration + 1 if homeaway_model.best_iteration is not None else None

    dcal_all = xgb.DMatrix(X_cal, feature_names=feature_cols)
    dval_all = xgb.DMatrix(X_val, feature_names=feature_cols)
    p_cal_home = homeaway_model.predict(dcal_all, iteration_range=(0, best_iter_ha)) if best_iter_ha else homeaway_model.predict(dcal_all)
    p_val_home = homeaway_model.predict(dval_all, iteration_range=(0, best_iter_ha)) if best_iter_ha else homeaway_model.predict(dval_all)

    # market blend for home-away (home prob among non-draw)
    homeaway_market_alpha = 0.0
    if all(c in cal.columns for c in ["p_home_norm", "p_away_norm"]) and all(c in val.columns for c in ["p_home_norm", "p_away_norm"]):
        p_home_mkt_cal = cal["p_home_norm"].astype(float).values
        p_away_mkt_cal = cal["p_away_norm"].astype(float).values
        denom_cal = np.clip(p_home_mkt_cal + p_away_mkt_cal, 1e-6, None)
        p_home_mkt_cal = sanitize_prob(p_home_mkt_cal / denom_cal)

        p_home_mkt_val = val["p_home_norm"].astype(float).values
        p_away_mkt_val = val["p_away_norm"].astype(float).values
        denom_val = np.clip(p_home_mkt_val + p_away_mkt_val, 1e-6, None)
        p_home_mkt_val = sanitize_prob(p_home_mkt_val / denom_val)

        cal_mask = cal["home_goals"] != cal["away_goals"]
        p_home_mkt_cal_nd = p_home_mkt_cal[cal_mask.values]
        best = (0.0, log_loss(y_cal_home, p_cal_home[cal_mask.values], labels=[0, 1]))
        for a in np.linspace(0.0, 0.8, 9):
            mix = sanitize_prob((1.0 - a) * p_cal_home[cal_mask.values] + a * p_home_mkt_cal_nd)
            ll = log_loss(y_cal_home, mix, labels=[0, 1])
            if ll < best[1]:
                best = (float(a), float(ll))
        homeaway_market_alpha = best[0]
        if homeaway_market_alpha > 0:
            p_cal_home = sanitize_prob((1.0 - homeaway_market_alpha) * p_cal_home + homeaway_market_alpha * p_home_mkt_cal)
            p_val_home = sanitize_prob((1.0 - homeaway_market_alpha) * p_val_home + homeaway_market_alpha * p_home_mkt_val)

    return {
        "draw_model": draw_model,
        "draw_best_iter": best_iter_draw,
        "draw_feature_cols": draw_feature_cols,
        "draw_feature_priors": draw_feature_priors,
        "p_cal_draw": sanitize_prob(p_cal_draw),
        "p_val_draw": sanitize_prob(p_val_draw),
        "draw_market_alpha": draw_market_alpha,
        "homeaway_model": homeaway_model,
        "homeaway_best_iter": best_iter_ha,
        "p_cal_home": sanitize_prob(p_cal_home),
        "p_val_home": sanitize_prob(p_val_home),
        "homeaway_market_alpha": homeaway_market_alpha,
    }


# =========================
# ОСНОВНОЙ ТРЕНЕР
# =========================

def _train_outcomes_single(
    df_full: pd.DataFrame,
    league_id: Optional[int] = None,
    feature_cols_override: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """
    df_full — результат build_dataset(return_all=True) или аналогичный:
      - есть home_goals, away_goals
      - есть has_result (bool)
      - есть date_utc / league_id / team_id
      - есть фичи формы, Elo, H2H, травм и т.п.
      - рыночные колонки присутствуют, но в фичи НЕ попадают.
    """

    # используем только матчи с известным результатом
    train = df_full[df_full["has_result"]].copy().reset_index(drop=True)
    if train.empty:
        raise RuntimeError("Нет матчей с результатом для обучения исходов.")

    print(f"[OUT] train rows (has_result=1): {len(train)}")

    # сплит TR / CAL / VAL по времени и лигам
    tr, cal, val = temporal_split_by_league(
        train,
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
        raise RuntimeError("После сплита одна из выборок пуста (TR/CAL/VAL).")

    print(f"[OUT] TR={len(tr)}  CAL={len(cal)}  VAL={len(val)}")

    # выбор фичей
    feature_cols = feature_cols_override or build_safe_feature_list(train)
    feature_priors = (
        train[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .mean()
        .fillna(0.0)
        .to_dict()
    )

    # XGB: multi-class (A/D/H)
    best_xgb_params = None
    if league_id is not None and league_id in OUTCOME_XGB_PARAMS_BY_LEAGUE:
        best_xgb_params = OUTCOME_XGB_PARAMS_BY_LEAGUE[league_id]
        out_xgb = train_xgb_outcome(
            tr=tr,
            cal=cal,
            val=val,
            feature_cols=feature_cols,
            ts_col="date_utc",
            now_override=None,
            params_override=best_xgb_params,
        )
        ll = log_loss(out_xgb["y_cal"], sanitize_prob(out_xgb["P_cal"]), labels=[0, 1, 2])
        print(f"[OUT] fixed xgb params for L{league_id} = {best_xgb_params}  LL={ll:.4f}")
    else:
        xgb_param_grid = [
            {},
            {"max_depth": 5, "eta": 0.04, "min_child_weight": 8.0},
            {"max_depth": 7, "eta": 0.03, "min_child_weight": 12.0},
            {"max_depth": 6, "eta": 0.05, "min_child_weight": 10.0},
            {"max_depth": 4, "eta": 0.06, "min_child_weight": 6.0},
            {"max_depth": 8, "eta": 0.025, "min_child_weight": 14.0},
            {"max_depth": 6, "eta": 0.04, "min_child_weight": 14.0},
        ]
        best_xgb = None
        best_xgb_ll = 1e9
        best_xgb_params = {}
        for override in xgb_param_grid:
            out_try = train_xgb_outcome(
                tr=tr,
                cal=cal,
                val=val,
                feature_cols=feature_cols,
                ts_col="date_utc",
                now_override=None,
                params_override=override,
            )
            ll = log_loss(out_try["y_cal"], sanitize_prob(out_try["P_cal"]), labels=[0, 1, 2])
            if ll < best_xgb_ll:
                best_xgb_ll = ll
                best_xgb = out_try
                best_xgb_params = override

        out_xgb = best_xgb
        if best_xgb_params:
            print(f"[OUT] best xgb params on CAL = {best_xgb_params}  LL={best_xgb_ll:.4f}")

    P_cal_xgb = sanitize_prob(out_xgb["P_cal"])
    P_val_xgb = sanitize_prob(out_xgb["P_val"])

    y_cal_3 = out_xgb["y_cal"]
    y_val_3 = out_xgb["y_val"]

    # Poisson ветка: две лямбды (home/away) + конвертация в 1X2
    pois = train_poisson_pair(
        tr=tr,
        cal=cal,
        val=val,
        feature_cols=feature_cols,
        ts_col="date_utc",
        now_override=None,
    )

    P_cal_pois, _ = build_poisson_probs_for_arrays(
        pois["lam_cal_home"],
        pois["lam_cal_away"],
    )
    P_val_pois, _ = build_poisson_probs_for_arrays(
        pois["lam_val_home"],
        pois["lam_val_away"],
    )

    # подбор alpha смешивания XGB vs Poisson по CAL
    best_alpha = 0.0
    best_ll = 1e9

    for a in np.linspace(0.0, 0.9, 10):
        P_mix_cal = blend_poisson_and_xgb(
            P_poisson=P_cal_pois,
            P_xgb=P_cal_xgb,
            alpha=float(a),
        )
        ll = log_loss(y_cal_3, P_mix_cal, labels=[0, 1, 2])
        if ll < best_ll:
            best_ll = ll
            best_alpha = float(a)

    print(f"[OUT] best alpha (XGB vs Poisson) on CAL = {best_alpha:.3f}  LL={best_ll:.4f}")

    # применяем лучшую смесь на CAL/VAL
    P_cal_mix = blend_poisson_and_xgb(P_cal_pois, P_cal_xgb, best_alpha)
    P_val_mix = blend_poisson_and_xgb(P_val_pois, P_val_xgb, best_alpha)

    # калибровка через LogisticRegression (мультиномиальная по вероятностям)
    lr = LogisticRegression(
        max_iter=200,
        solver="lbfgs",
    )
    lr.fit(P_cal_mix, y_cal_3)

    P_cal_lr = sanitize_prob(lr.predict_proba(P_cal_mix))
    P_val_lr = sanitize_prob(lr.predict_proba(P_val_mix))

    # якорение рынком (если рынок есть)
    have_market = all(c in val.columns for c in MARKET_COLS_1X2[:3])
    P_val_anchored = P_val_lr.copy()
    tau_market = 0.0

    P_cal_anchored = P_cal_lr
    if have_market:
        Pm_cal = np.stack(
            [
                cal["p_away_norm"].astype(float).values,
                cal["p_draw_norm"].astype(float).values,
                cal["p_home_norm"].astype(float).values,
            ],
            axis=1,
        )
        Pm_cal = sanitize_prob(Pm_cal)

        Pm_val = np.stack(
            [
                val["p_away_norm"].astype(float).values,
                val["p_draw_norm"].astype(float).values,
                val["p_home_norm"].astype(float).values,
            ],
            axis=1,
        )
        Pm_val = sanitize_prob(Pm_val)

        best_tau = 0.0
        best_ll_mkt = log_loss(y_cal_3, P_cal_lr, labels=[0, 1, 2])

        for tau in np.linspace(0.0, 0.6, 7):
            P_anchor_cal = apply_market_anchor(P_cal_lr, Pm_cal, tau=float(tau))
            ll = log_loss(y_cal_3, P_anchor_cal, labels=[0, 1, 2])
            if ll < best_ll_mkt:
                best_ll_mkt = ll
                best_tau = float(tau)

        tau_market = best_tau
        print(f"[OUT] best tau_market on CAL = {tau_market:.3f}  LL={best_ll_mkt:.4f}")

        P_cal_anchored = apply_market_anchor(P_cal_lr, Pm_cal, tau_market)
        P_val_anchored = apply_market_anchor(P_val_lr, Pm_val, tau_market)
    else:
        print("[OUT] market columns not found -> без якорения.")
        P_val_anchored = P_val_lr

    # контроль ничьей
    P_cal_final = apply_draw_cap(
        P_cal_anchored,
        max_draw=DRAW_CAP_MAX,
        boost_small_draw=DRAW_CAP_MIN,
    )
    P_val_final = apply_draw_cap(
        P_val_anchored,
        max_draw=DRAW_CAP_MAX,
        boost_small_draw=DRAW_CAP_MIN,
    )

    # двухэтапная модель: Draw vs Not + Home vs Away
    stage = _train_stage_models(tr=tr, cal=cal, val=val, feature_cols=feature_cols)
    stage_alpha = 0.0
    if stage.get("homeaway_model") is not None:
        p_cal_draw = stage["p_cal_draw"]
        p_val_draw = stage["p_val_draw"]
        p_cal_home = stage["p_cal_home"]
        p_val_home = stage["p_val_home"]

        P_stage_cal = np.stack(
            [(1.0 - p_cal_draw) * (1.0 - p_cal_home), p_cal_draw, (1.0 - p_cal_draw) * p_cal_home],
            axis=1,
        )
        P_stage_val = np.stack(
            [(1.0 - p_val_draw) * (1.0 - p_val_home), p_val_draw, (1.0 - p_val_draw) * p_val_home],
            axis=1,
        )

        best = (0.0, log_loss(y_cal_3, P_cal_final, labels=[0, 1, 2]))
        for a in np.linspace(0.0, 0.6, 7):
            mix = sanitize_prob((1.0 - a) * P_cal_final + a * P_stage_cal)
            ll = log_loss(y_cal_3, mix, labels=[0, 1, 2])
            if ll < best[1]:
                best = (float(a), float(ll))
        stage_alpha = best[0]
        if stage_alpha > 0:
            P_cal_final = sanitize_prob((1.0 - stage_alpha) * P_cal_final + stage_alpha * P_stage_cal)
            P_val_final = sanitize_prob((1.0 - stage_alpha) * P_val_final + stage_alpha * P_stage_val)

    # draw prior (стабилизация вероятности ничьей)
    draw_prior = float((y_cal_3 == 1).mean())
    gamma_draw = 0.0
    if 0.0 < draw_prior < 1.0:
        best = (0.0, log_loss(y_cal_3, P_cal_final, labels=[0, 1, 2]))
        for g in np.linspace(0.0, 0.5, 6):
            P_try = _apply_draw_prior(P_cal_final, draw_prior, float(g))
            ll = log_loss(y_cal_3, P_try, labels=[0, 1, 2])
            if ll < best[1]:
                best = (float(g), float(ll))
        gamma_draw = best[0]
    if gamma_draw > 0:
        P_cal_final = _apply_draw_prior(P_cal_final, draw_prior, gamma_draw)
        P_val_final = _apply_draw_prior(P_val_final, draw_prior, gamma_draw)

    # порог по ничьей для повышения macro-F1 (подбираем на CAL)
    draw_threshold = 0.0
    base_pred = _predict_with_draw_threshold(P_cal_final, 0.0)
    base_acc = float((base_pred == y_cal_3).mean())
    acc_floor = max(0.0, base_acc - 0.03)
    best = (0.0, 0.0, base_acc)  # (threshold, macro_f1, acc)
    for t in np.linspace(0.0, 0.4, 9):
        pred_cal = _predict_with_draw_threshold(P_cal_final, float(t))
        macro_f1 = _macro_f1(y_cal_3, pred_cal)
        acc_cal = float((pred_cal == y_cal_3).mean())
        if acc_cal < acc_floor:
            continue
        if (macro_f1 > best[1]) or (macro_f1 == best[1] and acc_cal > best[2]):
            best = (float(t), float(macro_f1), acc_cal)
    draw_threshold = best[0]

    # rule-based draw override (prob + closeness)
    rule_draw_threshold = 0.0
    rule_max_elo = np.inf
    rule_max_goal = np.inf
    rule_best = (0.0, 0.0, base_acc, np.inf, np.inf)  # (t, macro_f1, acc, elo, goal)

    elo_abs = cal["elo_diff"].abs().values if "elo_diff" in cal.columns else None
    goal_abs = cal["goal_diff_avg_6_diff"].abs().values if "goal_diff_avg_6_diff" in cal.columns else None
    if elo_abs is not None:
        elo_cands = np.unique(np.nanquantile(elo_abs, [0.2, 0.3, 0.4]))
    else:
        elo_cands = np.array([np.inf])
    if goal_abs is not None:
        goal_cands = np.unique(np.nanquantile(goal_abs, [0.2, 0.3, 0.4]))
    else:
        goal_cands = np.array([np.inf])

    for t in np.linspace(0.3, 0.6, 7):
        for e in elo_cands:
            for g in goal_cands:
                pred_cal = _predict_with_draw_rule(P_cal_final, cal, float(t), float(e), float(g))
                macro_f1 = _macro_f1(y_cal_3, pred_cal)
                acc_cal = float((pred_cal == y_cal_3).mean())
                if acc_cal < acc_floor:
                    continue
                if (macro_f1 > rule_best[1]) or (macro_f1 == rule_best[1] and acc_cal > rule_best[2]):
                    rule_best = (float(t), float(macro_f1), acc_cal, float(e), float(g))

    rule_draw_threshold = rule_best[0]
    rule_max_elo = rule_best[3]
    rule_max_goal = rule_best[4]

    # финальные метрики по VAL
    y_val_3 = _prepare_y_outcome_3(val)
    ll_val = log_loss(y_val_3, P_val_final, labels=[0, 1, 2])
    pred_val = _predict_with_draw_threshold(P_val_final, draw_threshold)
    if rule_draw_threshold > 0:
        pred_val = _predict_with_draw_rule(P_val_final, val, rule_draw_threshold, rule_max_elo, rule_max_goal)
    acc_val = (pred_val == y_val_3).mean()

    print(f"\n[OUT] VAL: acc={acc_val:.4f}  LL={ll_val:.4f}")
    print(classification_report(
        y_val_3,
        pred_val,
        target_names=["Away(-1)", "Draw(0)", "Home(+1)"],
    ))
    league_prob_bias = {}
    if "league_id" in cal.columns:
        cal_lids = cal["league_id"].astype(float)
        y_cal_onehot = np.eye(3)[y_cal_3]
        for lid in sorted(cal_lids.dropna().unique()):
            mask = cal_lids == lid
            if mask.sum() < 30:
                continue
            mean_pred = P_cal_final[mask.values].mean(axis=0)
            mean_actual = y_cal_onehot[mask.values].mean(axis=0)
            delta = mean_actual - mean_pred
            if np.max(np.abs(delta)) < 0.01:
                continue
            best_scale = 0.0
            best_ll = log_loss(y_cal_3[mask.values], P_cal_final[mask.values], labels=[0, 1, 2])
            for scale in np.linspace(0.0, 1.0, 9):
                P_try = _apply_league_prob_bias_scaled(P_cal_final[mask.values], delta, float(scale))
                ll_try = log_loss(y_cal_3[mask.values], P_try, labels=[0, 1, 2])
                if ll_try < best_ll:
                    best_ll = float(ll_try)
                    best_scale = float(scale)
            if best_scale > 0:
                league_prob_bias[int(lid)] = (delta * best_scale).tolist()
                print(
                    f"[OUT] league prob bias L{int(lid)} -> delta={delta}, "
                    f"scale={best_scale:.2f}, ll={best_ll:.4f}"
                )
    else:
        print("[OUT] league_id missing in CAL -> skip league bias computation")

    draw_global_cal = None
    draw_league_cal = {}
    try:
        X_draw = _safe_logit(P_cal_final[:, 1]).reshape(-1, 1)
        y_draw = (y_cal_3 == 1).astype(int)
        lr_draw = LogisticRegression(max_iter=200, solver="lbfgs")
        lr_draw.fit(X_draw, y_draw)
        draw_global_cal = (float(lr_draw.coef_[0][0]), float(lr_draw.intercept_[0]))
    except Exception as exc:
        print(f"[OUT] global draw calibration skipped: {exc}")

    if "league_id" in cal.columns:
        cal_lids = cal["league_id"].astype(float)
        for lid in sorted(cal_lids.dropna().unique()):
            mask = cal_lids == lid
            if mask.sum() < 80:
                continue
            y_draw_l = (y_cal_3[mask.values] == 1).astype(int)
            if y_draw_l.mean() in (0.0, 1.0):
                continue
            X_draw_l = _safe_logit(P_cal_final[mask.values, 1]).reshape(-1, 1)
            try:
                lr_loc = LogisticRegression(max_iter=200, solver="lbfgs")
                lr_loc.fit(X_draw_l, y_draw_l)
                draw_league_cal[int(lid)] = (
                    float(lr_loc.coef_[0][0]),
                    float(lr_loc.intercept_[0]),
                )
                print(f"[OUT] league draw calibration L{int(lid)} ready")
            except Exception as exc:
                print(f"[OUT] draw calibration failed L{int(lid)}: {exc}")
    else:
        print("[OUT] league_id missing in CAL -> skip league draw calibration")
    for lid in sorted(val["league_id"].dropna().unique()):
        lid_int = int(lid)
        mask = val["league_id"].astype(int) == lid_int
        if mask.sum() < 5:
            continue
        ll_l = log_loss(y_val_3[mask], P_val_final[mask], labels=[0, 1, 2])
        acc_l = (pred_val[mask] == y_val_3[mask]).mean()
        print(f"[OUT][L{lid_int}] acc={acc_l:.4f}  LL={ll_l:.4f}  n={mask.sum()}")

    # сохранение всего пайплайна
    model_bundle = {
        "xgb_model": out_xgb["model"],
        "xgb_best_iter": out_xgb["best_iter"],
        "poisson": pois,
        "logreg_calibrator": lr,
        "mix_alpha": best_alpha,
        "tau_market": tau_market,
        "stage_draw_model": stage.get("draw_model"),
        "stage_draw_best_iter": stage.get("draw_best_iter"),
        "stage_draw_market_alpha": stage.get("draw_market_alpha", 0.0),
        "stage_draw_feature_cols": stage.get("draw_feature_cols"),
        "stage_draw_feature_priors": stage.get("draw_feature_priors"),
        "stage_homeaway_model": stage.get("homeaway_model"),
        "stage_homeaway_best_iter": stage.get("homeaway_best_iter"),
        "stage_homeaway_market_alpha": stage.get("homeaway_market_alpha", 0.0),
        "stage_alpha": stage_alpha,
        "draw_prior": draw_prior,
        "draw_prior_gamma": gamma_draw,
        "draw_threshold": draw_threshold,
        "rule_draw_threshold": rule_draw_threshold,
        "rule_max_elo_diff": rule_max_elo,
        "rule_max_goal_diff": rule_max_goal,
        "feature_cols": feature_cols,
        "feature_priors": feature_priors,
        "league_prob_bias": league_prob_bias,
        "draw_league_calibrators": draw_league_cal,
        "draw_global_calibrator": draw_global_cal,
        "meta": {
            "cal_days": CAL_DAYS,
            "val_days": VAL_DAYS,
            "gap_days": GAP_DAYS,
        },
    }

    return {
        "bundle": model_bundle,
        "metrics": {
            "val_acc": float(acc_val),
            "val_ll": float(ll_val),
            "val_n": int(len(val)),
        },
    }


def train_outcomes(
    df_full: pd.DataFrame,
    feature_cols_override: Optional[List[str]] = None,
    save_path: Optional[str] = None,
) -> Dict[str, Any]:
    league_models: Dict[int, Dict[str, Any]] = {}
    league_metrics: Dict[int, Any] = {}

    league_ids = sorted(
        {int(l) for l in df_full["league_id"].dropna().unique()}
    )
    if not league_ids:
        raise RuntimeError("train_outcomes(): df_full не содержит league_id")

    for lid in league_ids:
        subset = df_full[df_full["league_id"] == lid].copy()
        if subset.empty:
            print(f"[OUT] L{lid}: нет матчей, пропуск")
            continue
        try:
            res = _train_outcomes_single(
                subset,
                league_id=lid,
                feature_cols_override=feature_cols_override,
            )
            league_models[lid] = {**res["bundle"], "league_id": lid}
            league_metrics[lid] = res["metrics"]
            print(f"[OUT] L{lid}: модель обучена")
        except RuntimeError as exc:
            print(f"[OUT] L{lid}: пропуск ({exc})")

    if not league_models:
        raise RuntimeError("train_outcomes(): не удалось обучить ни одной лиги")

    target_path = save_path or OUTCOME_MODEL_PATH
    joblib.dump(league_models, target_path)
    print(f"[OUT] Outcome models saved -> {target_path}")
    return league_metrics


if __name__ == "__main__":
    from data.build_dataset import build_dataset

    df_full = build_dataset(return_all=True)
    train_outcomes(df_full)
