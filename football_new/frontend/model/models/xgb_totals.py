# models/xgb_totals.py

import numpy as np
import pandas as pd
import xgboost as xgb
from typing import Optional, List

from data.splits import recency_weights


def _prepare_y_totals(df: pd.DataFrame) -> np.ndarray:
    """
    Возвращает бинарный target:
      0 = under 2.5
      1 = over 2.5
    """
    goals = df["home_goals"].astype(float) + df["away_goals"].astype(float)
    return (goals > 2.5).astype(int)


def train_xgb_totals(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    val: pd.DataFrame,
    feature_cols: List[str],
    ts_col: str = "date_utc",
    now_override: Optional[str] = None,
):
    """
    Тренируем бинарную XGBoost-модель для тотала.
    """
    X_tr = tr[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0)
    X_cal = cal[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0)
    X_val = val[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0)

    y_tr = _prepare_y_totals(tr)
    y_cal = _prepare_y_totals(cal)
    y_val = _prepare_y_totals(val)

    w_tr = recency_weights(tr, ts_col=ts_col, now_override=now_override)

    dtr = xgb.DMatrix(X_tr, label=y_tr, weight=w_tr, feature_names=feature_cols)
    dcal = xgb.DMatrix(X_cal, label=y_cal, feature_names=feature_cols)
    dval = xgb.DMatrix(X_val, label=y_val, feature_names=feature_cols)

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
        "seed": 123
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

    p_cal = model.predict(dcal, iteration_range=(0, best_iter)) if best_iter else model.predict(dcal)
    p_val = model.predict(dval, iteration_range=(0, best_iter)) if best_iter else model.predict(dval)

    return {
        "model": model,
        "best_iter": best_iter,
        "y_cal": y_cal,
        "y_val": y_val,
        "p_cal_raw": p_cal,
        "p_val_raw": p_val,
    }
