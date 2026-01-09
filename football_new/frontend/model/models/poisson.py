# models/poisson.py

import numpy as np
import pandas as pd
import xgboost as xgb
from typing import Union, Optional

from data.splits import recency_weights
from config import (
    POISSON_MAX,
    POISSON_MIN_LAMBDA,
    POISSON_MAX_LAMBDA,
)


def _poisson_objective(preds: np.ndarray, dtrain: xgb.DMatrix):
    """
    Кастомный Poisson loss:
        y ~ Poisson(lambda),   lambda = exp(f(x))
        grad = lambda - y
        hess = lambda
    """
    y = dtrain.get_label()
    lam = np.exp(preds)
    grad = lam - y
    hess = lam
    return grad, hess


def best_ntree_limit(booster: Union[xgb.Booster, xgb.XGBModel]) -> Optional[int]:
    """
    Определяет лучшее число деревьев.
    Работает как для xgb.train, так и для XGBRegressor.
    """
    if hasattr(booster, "best_ntree_limit") and booster.best_ntree_limit:
        return int(booster.best_ntree_limit)

    if hasattr(booster, "best_iteration") and booster.best_iteration is not None:
        return int(booster.best_iteration) + 1

    try:
        attrs = booster.attributes()
        if "best_iteration" in attrs and attrs["best_iteration"] is not None:
            return int(attrs["best_iteration"]) + 1
    except Exception:
        pass

    return None


def _to_lambda(raw_pred: np.ndarray) -> np.ndarray:
    lam = np.exp(raw_pred)
    lam = np.clip(lam, POISSON_MIN_LAMBDA, POISSON_MAX_LAMBDA)
    return lam.astype("float64")


def train_poisson_pair(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    val: pd.DataFrame,
    feature_cols: list,
    ts_col: str = "date_utc",
    now_override: Optional[str] = None,
):
    """
    Обучает два Poisson-регрессора:
      - log(lambda_home)
      - log(lambda_away)
    Возвращает:
      dict с моделями и предсказанными лямбда на CAL/VAL.
    """
    X_tr = tr[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0).astype("float32")
    X_cal = cal[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0).astype("float32")
    X_val = val[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0).astype("float32")

    y_tr_home = pd.to_numeric(tr["home_goals"], errors="coerce").fillna(0).values.astype("float32")
    y_tr_away = pd.to_numeric(tr["away_goals"], errors="coerce").fillna(0).values.astype("float32")

    w_tr = recency_weights(tr, ts_col=ts_col, now_override=now_override)

    dtr_h = xgb.DMatrix(X_tr, label=y_tr_home, weight=w_tr, feature_names=feature_cols)
    dtr_a = xgb.DMatrix(X_tr, label=y_tr_away, weight=w_tr, feature_names=feature_cols)
    dcal = xgb.DMatrix(X_cal, feature_names=feature_cols)
    dval = xgb.DMatrix(X_val, feature_names=feature_cols)

    params = {
        "max_depth": 3,
        "eta": 0.06,
        "subsample": 0.85,
        "colsample_bytree": 0.85,
        "lambda": 3.0,
        "alpha": 0.10,
        "tree_method": "hist",
        "seed": 123,
        "eval_metric": "rmse",
    }

    model_h = xgb.train(
        params=params,
        dtrain=dtr_h,
        num_boost_round=600,
        obj=_poisson_objective,
        evals=[(dtr_h, "train_home")],
        early_stopping_rounds=60,
        verbose_eval=False,
    )

    model_a = xgb.train(
        params=params,
        dtrain=dtr_a,
        num_boost_round=600,
        obj=_poisson_objective,
        evals=[(dtr_a, "train_away")],
        early_stopping_rounds=60,
        verbose_eval=False,
    )

    n_best_h = best_ntree_limit(model_h)
    n_best_a = best_ntree_limit(model_a)

    lam_cal_h = _to_lambda(model_h.predict(dcal, iteration_range=(0, n_best_h)) if n_best_h else model_h.predict(dcal))
    lam_cal_a = _to_lambda(model_a.predict(dcal, iteration_range=(0, n_best_a)) if n_best_a else model_a.predict(dcal))
    lam_val_h = _to_lambda(model_h.predict(dval, iteration_range=(0, n_best_h)) if n_best_h else model_h.predict(dval))
    lam_val_a = _to_lambda(model_a.predict(dval, iteration_range=(0, n_best_a)) if n_best_a else model_a.predict(dval))

    return {
        "model_home": model_h,
        "model_away": model_a,
        "n_best_home": n_best_h,
        "n_best_away": n_best_a,
        "lam_cal_home": lam_cal_h,
        "lam_cal_away": lam_cal_a,
        "lam_val_home": lam_val_h,
        "lam_val_away": lam_val_a,
    }


def poisson_triplet_and_over(lh: float, la: float, K: int = POISSON_MAX):
    """
    lh, la — лямбда хозяев и гостей.
    Возвращает: p_away, p_draw, p_home, p_over25.
    """
    lh = float(max(1e-8, lh))
    la = float(max(1e-8, la))

    pmf_h = np.zeros(K + 1, dtype="float64")
    pmf_a = np.zeros(K + 1, dtype="float64")

    pmf_h[0] = np.exp(-lh)
    pmf_a[0] = np.exp(-la)

    for k in range(1, K):
        pmf_h[k] = pmf_h[k - 1] * lh / k
        pmf_a[k] = pmf_a[k - 1] * la / k

    pmf_h[K] = max(0.0, 1.0 - pmf_h[:K].sum())
    pmf_a[K] = max(0.0, 1.0 - pmf_a[:K].sum())

    pmf_h /= pmf_h.sum()
    pmf_a /= pmf_a.sum()

    joint = np.outer(pmf_h, pmf_a)

    idx = np.arange(K + 1)
    total_goals = np.add.outer(idx, idx)

    mask_H = idx[:, None] > idx[None, :]
    mask_D = idx[:, None] == idx[None, :]
    mask_A = idx[:, None] < idx[None, :]

    pH = joint[mask_H].sum()
    pD = joint[mask_D].sum()
    pA = joint[mask_A].sum()
    p_over = joint[total_goals >= 3].sum()

    S = pA + pD + pH
    if S <= 1e-12:
        pA = pD = pH = 1/3
    else:
        pA, pD, pH = pA / S, pD / S, pH / S

    return float(pA), float(pD), float(pH), float(p_over)


def build_poisson_probs_for_arrays(lam_home: np.ndarray, lam_away: np.ndarray):
    n = len(lam_home)
    pA = np.zeros(n, dtype="float64")
    pD = np.zeros(n, dtype="float64")
    pH = np.zeros(n, dtype="float64")
    pOv = np.zeros(n, dtype="float64")

    for i in range(n):
        pA[i], pD[i], pH[i], pOv[i] = poisson_triplet_and_over(lam_home[i], lam_away[i])

    P = np.stack([pA, pD, pH], axis=1)
    P = np.clip(P, 1e-6, 1 - 1e-6)
    P /= P.sum(axis=1, keepdims=True)
    return P, pOv
