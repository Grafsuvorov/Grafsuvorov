# train_outcomes.py
# Обучение модели исхода матча (1X2) с Poisson-веткой и калибровкой.

import numpy as np
import pandas as pd
from typing import List, Dict, Any, Optional

from sklearn.linear_model import LogisticRegression
from sklearn.metrics import log_loss, classification_report

import joblib

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
)


def _safe_logit(p: np.ndarray) -> np.ndarray:
    p = np.clip(p.astype(float), 1e-6, 1 - 1e-6)
    return np.log(p / (1 - p))


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


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
    } | set(MARKET_COLS_1X2)

    num_cols = []
    for c in df.columns:
        if c in drop_exact:
            continue
        if pd.api.types.is_numeric_dtype(df[c]):
            num_cols.append(c)

    safe = []
    for c in num_cols:
        lc = c.lower()
        # выкидываем явные goal / score если не агрегаты
        if ("goal" in lc or "score" in lc) and not any(
            sfx in lc
            for sfx in ("_mean_", "_std_", "_ema_", "_slope_", "_sum_", "_avg_")
        ):
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


# =========================
# ОСНОВНОЙ ТРЕНЕР
# =========================

def _train_outcomes_single(df_full: pd.DataFrame) -> Dict[str, Any]:
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
    feature_cols = build_safe_feature_list(train)
    feature_priors = (
        train[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .mean()
        .fillna(0.0)
        .to_dict()
    )

    # XGB: multi-class (A/D/H)
    out_xgb = train_xgb_outcome(
        tr=tr,
        cal=cal,
        val=val,
        feature_cols=feature_cols,
        ts_col="date_utc",
        now_override=None,
    )

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
        multi_class="multinomial",
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

    # финальные метрики по VAL
    y_val_3 = _prepare_y_outcome_3(val)
    ll_val = log_loss(y_val_3, P_val_final, labels=[0, 1, 2])
    pred_val = P_val_final.argmax(axis=1)
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
            league_prob_bias[int(lid)] = delta.tolist()
            print(f"[OUT] league prob bias L{int(lid)} -> delta={delta}")
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
        },
    }


def train_outcomes(df_full: pd.DataFrame) -> Dict[str, Any]:
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
            res = _train_outcomes_single(subset)
            league_models[lid] = {**res["bundle"], "league_id": lid}
            league_metrics[lid] = res["metrics"]
            print(f"[OUT] L{lid}: модель обучена")
        except RuntimeError as exc:
            print(f"[OUT] L{lid}: пропуск ({exc})")

    if not league_models:
        raise RuntimeError("train_outcomes(): не удалось обучить ни одной лиги")

    joblib.dump(league_models, OUTCOME_MODEL_PATH)
    print(f"[OUT] Outcome models saved -> {OUTCOME_MODEL_PATH}")
    return league_metrics


if __name__ == "__main__":
    # пример: ожидаем, что где-то есть функция build_full_dataset()
    from data.build_dataset import build_full_dataset

    df_full = build_full_dataset()
    train_outcomes(df_full)
