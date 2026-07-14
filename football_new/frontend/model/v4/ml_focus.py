from __future__ import annotations

import numpy as np
import pandas as pd
from catboost import CatBoostClassifier


FOCUS_FEATURE_COLS = [
    "league_id",
    "season",
    "round",
    "home_team_id",
    "away_team_id",
    "avg_odds_home",
    "avg_odds_draw",
    "avg_odds_away",
    "n_bookmakers",
    "p_away_mkt",
    "p_draw_mkt",
    "p_home_mkt",
    "league_home_avg",
    "league_away_avg",
    "lambda_home_v4",
    "lambda_away_v4",
    "p_away_pois",
    "p_draw_pois",
    "p_home_pois",
    "home_points_all_5",
    "home_points_all_10",
    "home_points_home_5",
    "home_gf_all_5",
    "home_ga_all_5",
    "home_gd_all_5",
    "home_gf_home_5",
    "home_ga_home_5",
    "away_points_all_5",
    "away_points_all_10",
    "away_points_away_5",
    "away_gf_all_5",
    "away_ga_all_5",
    "away_gd_all_5",
    "away_gf_away_5",
    "away_ga_away_5",
    "form_points_diff_5",
    "form_points_diff_10",
    "venue_points_diff_5",
    "gd_diff_5",
    "attack_vs_def_home_5",
    "attack_vs_def_away_5",
    "draw_risk_market",
    "draw_risk_poisson",
    "draw_risk_avg",
    "draw_risk_gap",
    "market_fav_code",
    "poisson_fav_code",
    "fav_agree_market_poisson",
    "home_market_minus_poisson",
    "draw_market_minus_poisson",
    "away_market_minus_poisson",
    "home_form_vs_market",
    "draw_balance_proxy",
]

FOCUS_CATEGORICAL_COLS = ["league_id", "season", "round", "home_team_id", "away_team_id"]


def _prepare_xy(df: pd.DataFrame) -> tuple[pd.DataFrame, np.ndarray]:
    x = df[FOCUS_FEATURE_COLS].copy()
    for col in FOCUS_CATEGORICAL_COLS:
        x[col] = x[col].astype(str)
    hg = pd.to_numeric(df["home_goals"], errors="coerce").fillna(0).to_numpy()
    ag = pd.to_numeric(df["away_goals"], errors="coerce").fillna(0).to_numpy()
    y = np.zeros(len(df), dtype="int64")
    y[ag > hg] = 0
    y[ag == hg] = 1
    y[hg > ag] = 2
    return x, y


def fit_catboost_focus(train_df: pd.DataFrame, cal_df: pd.DataFrame) -> CatBoostClassifier:
    x_train, y_train = _prepare_xy(train_df)
    x_cal, y_cal = _prepare_xy(cal_df)
    model = CatBoostClassifier(
        loss_function="MultiClass",
        eval_metric="MultiClass",
        depth=6,
        learning_rate=0.035,
        iterations=900,
        l2_leaf_reg=10.0,
        random_strength=1.5,
        min_data_in_leaf=15,
        verbose=False,
        random_seed=42,
    )
    model.fit(
        x_train,
        y_train,
        cat_features=[x_train.columns.get_loc(c) for c in FOCUS_CATEGORICAL_COLS],
        eval_set=(x_cal, y_cal),
        use_best_model=True,
        verbose=False,
    )
    return model


def predict_catboost_focus(model: CatBoostClassifier, df: pd.DataFrame) -> np.ndarray:
    x, _ = _prepare_xy(df)
    probs = model.predict_proba(x)
    probs = np.asarray(probs, dtype="float64")
    probs = np.clip(probs, 1e-6, 1 - 1e-6)
    probs /= probs.sum(axis=1, keepdims=True)
    return probs

