# train_totals.py
# Обучение модели Over 2.5 (XGB + Poisson + калибровка + рынок).

import numpy as np
import pandas as pd
from typing import List, Dict, Any, Optional

from sklearn.isotonic import IsotonicRegression
from sklearn.metrics import log_loss, brier_score_loss
from sklearn.linear_model import LogisticRegression

import joblib

from data.splits import temporal_split_by_league
from models.xgb_totals import train_xgb_totals
from models.poisson import train_poisson_pair, build_poisson_probs_for_arrays
from models.blending import sanitize_prob, _safe_blend  # можно скопировать safe_blend сюда, если нет
from config import (
    TOTALS_MODEL_PATH,
    CAL_DAYS,
    VAL_DAYS,
    GAP_DAYS,
)


MARKET_COLS_TOT = [
    "p_over_mkt",   # вероятность рынка на over2.5
    "overround_1x2",
    "n_bookmakers",
]


def _safe_blend_local(p_model: np.ndarray, p_mkt: np.ndarray, alpha: float) -> np.ndarray:
    """
    Локальная версия blend для скаляра alpha (если не хочешь импортировать _safe_blend).
    """
    p_model = sanitize_prob(p_model)
    p_mkt = sanitize_prob(p_mkt)
    out = p_model.copy()
    use = np.isfinite(p_mkt)
    if alpha > 0 and use.any():
        out[use] = (1.0 - alpha) * p_model[use] + alpha * p_mkt[use]
    return sanitize_prob(out)


def _safe_logit(p: np.ndarray) -> np.ndarray:
    p = np.clip(p.astype(float), 1e-6, 1 - 1e-6)
    return np.log(p / (1 - p))


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def _apply_logistic_calibration(
    p: np.ndarray,
    league_ids: Optional[pd.Series],
    league_cals: Dict[int, tuple],
    global_cal: Optional[tuple],
) -> np.ndarray:
    if (not league_cals) and (global_cal is None):
        return sanitize_prob(p)

    logits = _safe_logit(p)
    if league_ids is not None:
        lids = np.asarray(league_ids, dtype=float)
    else:
        lids = np.full(len(p), np.nan, dtype=float)

    out = logits.copy()

    for i in range(len(out)):
        lid = lids[i]
        key = int(lid) if np.isfinite(lid) else None
        params = league_cals.get(key) if (league_cals and key is not None) else None
        if params is None:
            params = global_cal
        if params is None:
            continue
        coef, intercept = params
        out[i] = coef * logits[i] + intercept

    return sanitize_prob(_sigmoid(out))


def _train_totals_single(df_full: pd.DataFrame) -> Dict[str, Any]:
    """
    df_full — тот же датасет, что и для исходов, но мы используем target_over25.
    """

    train = df_full[df_full["has_result"]].copy().reset_index(drop=True)
    if train.empty:
        raise RuntimeError("Нет матчей с результатом для обучения тоталов.")

    print(f"[OVR] train rows (has_result=1): {len(train)}")

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
        raise RuntimeError("После сплита одна из выборок пуста (TR/CAL/VAL) для тоталов.")

    print(f"[OVR] TR={len(tr)}  CAL={len(cal)}  VAL={len(val)}")

    tr = tr.reset_index(drop=True)
    cal = cal.reset_index(drop=True)
    val = val.reset_index(drop=True)

    # фичи (та же логика, что и в train_outcomes, можно вынести в общий модуль)
    from train_outcomes import build_safe_feature_list  # чтобы не дублировать

    feature_cols = build_safe_feature_list(train)
    feature_priors = (
        train[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .mean()
        .fillna(0.0)
        .to_dict()
    )

    # XGB-ветка
    out_tot = train_xgb_totals(
        tr=tr,
        cal=cal,
        val=val,
        feature_cols=feature_cols,
        ts_col="date_utc",
        now_override=None,
    )

    p_cal_raw = sanitize_prob(out_tot["p_cal_raw"])
    p_val_raw = sanitize_prob(out_tot["p_val_raw"])
    y_cal = out_tot["y_cal"]
    y_val = out_tot["y_val"]

    # Poisson-ветка: те же лямбды, что и для исходов, но нас интересует p_over25
    pois = train_poisson_pair(
        tr=tr,
        cal=cal,
        val=val,
        feature_cols=feature_cols,
        ts_col="date_utc",
        now_override=None,
    )

    _, p_over_cal = build_poisson_probs_for_arrays(
        pois["lam_cal_home"],
        pois["lam_cal_away"],
    )
    _, p_over_val = build_poisson_probs_for_arrays(
        pois["lam_val_home"],
        pois["lam_val_away"],
    )

    # калибровка XGB через IsotonicRegression
    iso = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
    try:
        iso.fit(p_cal_raw, y_cal)
        p_cal_iso = sanitize_prob(iso.predict(p_cal_raw))
        p_val_iso = sanitize_prob(iso.predict(p_val_raw))
    except Exception:
        print("[OVR] isotonic failed -> используем сырые XGB-вероятности.")
        p_cal_iso = p_cal_raw
        p_val_iso = p_val_raw

    # смешивание XGB vs Poisson по CAL
    best_c = (0.0, 1e9)  # (alpha, logloss)

    for a in np.linspace(0.0, 0.9, 10):
        pmix = sanitize_prob(a * p_over_cal + (1 - a) * p_cal_iso)
        ll = log_loss(y_cal, pmix, labels=[0, 1])
        if ll < best_c[1]:
            best_c = (float(a), float(ll))

    alpha_mix = best_c[0]
    print(f"[OVR] best alpha_mix on CAL = {alpha_mix:.3f}  LL={best_c[1]:.4f}")

    p_cal_mix = sanitize_prob(alpha_mix * p_over_cal + (1 - alpha_mix) * p_cal_iso)
    p_val_mix = sanitize_prob(alpha_mix * p_over_val + (1 - alpha_mix) * p_val_iso)

    # якорение к рынку Over 2.5 (если есть p_over_mkt)
    have_mkt = "p_over_mkt" in cal.columns and "p_over_mkt" in val.columns
    alpha_mkt = 0.0
    if have_mkt:
        pm_cal = sanitize_prob(cal["p_over_mkt"].astype(float).values)
        pm_val = sanitize_prob(val["p_over_mkt"].astype(float).values)

        best = (0.0, log_loss(y_cal, p_val_mix, labels=[0, 1]))
        for a in np.linspace(0.0, 0.6, 7):
            mix_cal = _safe_blend_local(p_val_mix[: len(pm_cal)], pm_cal, a)
            ll = log_loss(y_cal, mix_cal, labels=[0, 1])
            if ll < best[1]:
                best = (float(a), float(ll))
        alpha_mkt = best[0]
        print(f"[OVR] best alpha_market on CAL = {alpha_mkt:.3f}")

        p_cal_final = _safe_blend_local(p_cal_mix[: len(pm_cal)], pm_cal, alpha_mkt)
        p_val_final = _safe_blend_local(p_val_mix, pm_val, alpha_mkt)
    else:
        print("[OVR] p_over_mkt не найден -> без рыночного якорения.")
        p_cal_final = p_cal_mix
        p_val_final = p_val_mix

    # логит-калибровка по лигам (чтобы поправить bias)
    league_logit_calibrators: Dict[int, tuple] = {}
    global_logit_calibrator: tuple | None = None

    try:
        X_glob = _safe_logit(p_cal_final).reshape(-1, 1)
        lr_glob = LogisticRegression(max_iter=200, solver="lbfgs")
        lr_glob.fit(X_glob, y_cal)
        global_logit_calibrator = (
            float(lr_glob.coef_[0][0]),
            float(lr_glob.intercept_[0]),
        )
    except Exception as exc:
        print(f"[OVR] global logistic calibration skipped: {exc}")
        global_logit_calibrator = None

    if "league_id" in cal.columns:
        lids = cal["league_id"].astype(float)
        for lid in sorted(lids.dropna().unique()):
            mask = lids == lid
            if mask.sum() < 30:
                continue
            y_part = y_cal[mask.values]
            if len(np.unique(y_part)) < 2:
                continue
            X_part = _safe_logit(p_cal_final[mask.values]).reshape(-1, 1)
            try:
                lr_loc = LogisticRegression(max_iter=200, solver="lbfgs")
                lr_loc.fit(X_part, y_part)
                league_logit_calibrators[int(lid)] = (
                    float(lr_loc.coef_[0][0]),
                    float(lr_loc.intercept_[0]),
                )
            except Exception as exc:
                print(f"[OVR] league logistic calibration failed L{int(lid)}: {exc}")
    else:
        print("[OVR] league_id missing in CAL -> пропускаем league logistic calibration")

    p_cal_final = _apply_logistic_calibration(
        p_cal_final,
        cal.get("league_id"),
        league_logit_calibrators,
        global_logit_calibrator,
    )
    p_val_final = _apply_logistic_calibration(
        p_val_final,
        val.get("league_id"),
        league_logit_calibrators,
        global_logit_calibrator,
    )

    # league-specific bias offsets (calibration on CAL)
    league_offsets = {}
    if "league_id" in cal.columns:
        cal_tmp = cal.copy()
        cal_tmp["p_over_calibrated"] = p_cal_final
        cal_tmp["target_over25"] = y_cal
        for lid, part in cal_tmp.groupby("league_id"):
            if len(part) < 20:
                continue
            bias = float(part["target_over25"].mean() - part["p_over_calibrated"].mean())
            if abs(bias) < 0.01:
                continue
            league_offsets[int(lid)] = bias
        if league_offsets:
            print(f"[OVR] league bias offsets: {league_offsets}")
            if "league_id" in val.columns:
                lids_val = val["league_id"].astype(int).values
                offset_vec = np.array([
                    league_offsets.get(int(l), 0.0)
                    for l in lids_val
                ], dtype="float64")
                p_val_final = sanitize_prob(np.clip(p_val_final + offset_vec, 1e-6, 1 - 1e-6))
        else:
            print("[OVR] no league offsets detected")
    else:
        print("[OVR] league_id missing in CAL -> skip league offsets")

    # метрики VAL
    ll_val = log_loss(y_val, p_val_final, labels=[0, 1])
    br_val = brier_score_loss(y_val, p_val_final)
    acc_val = ((p_val_final >= 0.5).astype(int) == y_val).mean()

    print(f"[OVR] VAL: acc={acc_val:.4f}  LL={ll_val:.4f}  Brier={br_val:.4f}")
    for lid in sorted(val["league_id"].dropna().unique()):
        lid_int = int(lid)
        mask = val["league_id"].astype(int) == lid_int
        if mask.sum() < 5:
            continue
        ll_l = log_loss(y_val[mask], p_val_final[mask], labels=[0, 1])
        acc_l = (((p_val_final[mask] >= 0.5).astype(int)) == y_val[mask]).mean()
        print(f"[OVR][L{lid_int}] acc={acc_l:.4f}  LL={ll_l:.4f}  n={mask.sum()}")

    model_bundle = {
        "xgb_model": out_tot["model"],
        "xgb_best_iter": out_tot["best_iter"],
        "iso": iso,
        "poisson": pois,
        "alpha_mix": alpha_mix,
        "alpha_market": alpha_mkt,
        "feature_cols": feature_cols,
        "feature_priors": feature_priors,
        "league_offsets": league_offsets,
        "league_logit_calibrators": league_logit_calibrators,
        "global_logit_calibrator": global_logit_calibrator,
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
            "val_brier": float(br_val),
        },
    }


def train_totals(df_full: pd.DataFrame) -> Dict[str, Any]:
    league_models: Dict[int, Dict[str, Any]] = {}
    league_metrics: Dict[int, Any] = {}

    league_ids = sorted(
        {int(l) for l in df_full["league_id"].dropna().unique()}
    )
    if not league_ids:
        raise RuntimeError("train_totals(): df_full не содержит league_id")

    for lid in league_ids:
        subset = df_full[df_full["league_id"] == lid].copy()
        if subset.empty:
            print(f"[OVR] L{lid}: нет матчей, пропуск")
            continue
        try:
            res = _train_totals_single(subset)
            league_models[lid] = {**res["bundle"], "league_id": lid}
            league_metrics[lid] = res["metrics"]
            print(f"[OVR] L{lid}: модель обучена")
        except RuntimeError as exc:
            print(f"[OVR] L{lid}: пропуск ({exc})")

    if not league_models:
        raise RuntimeError("train_totals(): не удалось обучить ни одной лиги")

    joblib.dump(league_models, TOTALS_MODEL_PATH)
    print(f"[OVR] Totals models saved -> {TOTALS_MODEL_PATH}")
    return league_metrics


if __name__ == "__main__":
    from data.build_dataset import build_full_dataset

    df_full = build_full_dataset()
    train_totals(df_full)
