# models/xgb_outcome.py

import numpy as np
import pandas as pd
import xgboost as xgb
from typing import Optional, List

from data.splits import recency_weights
from config import DRAW_CLASS_WEIGHT


def _prepare_y_outcome(df: pd.DataFrame) -> np.ndarray:
    """
    Возвращает 0/1/2:
      0 = Away win
      1 = Draw
      2 = Home win
    """
    h = df["home_goals"].astype(float)
    a = df["away_goals"].astype(float)

    y = np.where(h > a, 2,
                 np.where(h < a, 0, 1))
    return y.astype(int)


def train_xgb_outcome(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    val: pd.DataFrame,
    feature_cols: List[str],
    ts_col: str = "date_utc",
    now_override: Optional[str] = None,
    params_override: Optional[dict] = None,
):
    """
    Тренируем XGBClassifier, но вручную через obj=softprob.
    Выдаёт вероятности для A/D/H.
    """
    X_tr = tr[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0)
    X_cal = cal[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0)
    X_val = val[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0)

    y_tr = _prepare_y_outcome(tr)
    y_cal = _prepare_y_outcome(cal)
    y_val = _prepare_y_outcome(val)

    w_tr = recency_weights(tr, ts_col=ts_col, now_override=now_override)
    if DRAW_CLASS_WEIGHT and float(DRAW_CLASS_WEIGHT) > 1.0:
        w_tr = w_tr.astype('float64')
        draw_mask = (y_tr == 1)
        if draw_mask.any():
            w_tr[draw_mask] *= float(DRAW_CLASS_WEIGHT)

    dtr = xgb.DMatrix(X_tr, label=y_tr, weight=w_tr, feature_names=feature_cols)
    dcal = xgb.DMatrix(X_cal, label=y_cal, feature_names=feature_cols)
    dval = xgb.DMatrix(X_val, label=y_val, feature_names=feature_cols)

    params = {
        "objective": "multi:softprob",
        "num_class": 3,
        "eta": 0.035,
        "max_depth": 6,
        "min_child_weight": 10.0,
        "subsample": 0.90,
        "colsample_bytree": 0.90,
        "lambda": 2.0,
        "alpha": 0.0,
        "tree_method": "hist",
        "eval_metric": "mlogloss",
        "seed": 123
    }
    if params_override:
        params.update(params_override)

    model = xgb.train(
        params,
        dtr,
        num_boost_round=1100,
        evals=[(dtr, "train"), (dcal, "cal")],
        early_stopping_rounds=90,
        verbose_eval=False,
    )

    best_iter = model.best_iteration + 1 if model.best_iteration is not None else None

    P_cal = model.predict(dcal, iteration_range=(0, best_iter)) if best_iter else model.predict(dcal)
    P_val = model.predict(dval, iteration_range=(0, best_iter)) if best_iter else model.predict(dval)

    return {
        "model": model,
        "best_iter": best_iter,
        "y_tr": y_tr,
        "y_cal": y_cal,
        "y_val": y_val,
        "P_cal": P_cal,
        "P_val": P_val,
    }
