from __future__ import annotations

import numpy as np
import pandas as pd
from catboost import CatBoostClassifier


V5_0_FEATURE_COLS = [
    "league_id",
    "season",
    "round",
    "home_team_id",
    "away_team_id",
    "hours_before_match",
    "avg_odds_home_current",
    "avg_odds_draw_current",
    "avg_odds_away_current",
    "avg_odds_home_open",
    "avg_odds_draw_open",
    "avg_odds_away_open",
    "n_bookmakers_current",
    "n_bookmakers_open",
    "p_away_current",
    "p_draw_current",
    "p_home_current",
    "p_away_open",
    "p_draw_open",
    "p_home_open",
    "overround_current",
    "overround_open",
    "market_entropy_current",
    "market_entropy_open",
    "line_move_home",
    "line_move_draw",
    "line_move_away",
    "favorite_side_open",
    "favorite_side_current",
    "favorite_changed_flag",
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
]

V5_3_EXTRA_FEATURE_COLS = [
    "home_points_home_10",
    "away_points_away_10",
    "venue_points_diff_10",
    "home_gd_home_10",
    "away_gd_away_10",
    "venue_gd_diff_10",
    "home_recent_opp_points_5",
    "away_recent_opp_points_5",
    "home_adj_points_5",
    "away_adj_points_5",
    "adj_points_diff_5",
    "home_table_position",
    "away_table_position",
    "home_points_before",
    "away_points_before",
    "home_matches_before",
    "away_matches_before",
    "position_diff",
    "points_diff_table",
    "season_progress",
    "late_season_flag",
    "home_gap_title",
    "away_gap_title",
    "home_gap_top4",
    "away_gap_top4",
    "home_gap_safe",
    "away_gap_safe",
    "home_must_win_score",
    "away_must_win_score",
    "must_win_diff",
]

V5_3_FEATURE_COLS = V5_0_FEATURE_COLS + V5_3_EXTRA_FEATURE_COLS

V5_4_EXTRA_FEATURE_COLS = [
    "home_xgf_5",
    "home_xga_5",
    "away_xgf_5",
    "away_xga_5",
    "home_xgf_10",
    "home_xga_10",
    "away_xgf_10",
    "away_xga_10",
    "home_xgf_home_5",
    "home_xga_home_5",
    "away_xgf_away_5",
    "away_xga_away_5",
    "xg_balance_home_5",
    "xg_balance_away_5",
    "xg_balance_diff_5",
    "xg_balance_diff_10",
    "xg_home_attack_vs_away_def_5",
    "xg_away_attack_vs_home_def_5",
    "home_xg_trend_5v10",
    "away_xg_trend_5v10",
    "home_xga_trend_5v10",
    "away_xga_trend_5v10",
    "home_shots_for_5",
    "away_shots_for_5",
    "home_shots_against_5",
    "away_shots_against_5",
    "shots_balance_diff_5",
    "home_sot_for_5",
    "away_sot_for_5",
    "sot_diff_5",
    "home_xg_per_shot_5",
    "away_xg_per_shot_5",
    "xg_per_shot_diff_5",
]

V5_4_FEATURE_COLS = V5_3_FEATURE_COLS + V5_4_EXTRA_FEATURE_COLS

V5_CATEGORICAL_COLS = [
    "league_id",
    "season",
    "round",
    "home_team_id",
    "away_team_id",
    "favorite_side_open",
    "favorite_side_current",
]


def _prepare_xy(df: pd.DataFrame, feature_cols: list[str]) -> tuple[pd.DataFrame, np.ndarray]:
    x = df[feature_cols].copy()
    for col in V5_CATEGORICAL_COLS:
        x[col] = x[col].astype(str)

    hg = pd.to_numeric(df["home_goals"], errors="coerce").fillna(0).to_numpy()
    ag = pd.to_numeric(df["away_goals"], errors="coerce").fillna(0).to_numpy()
    y = np.zeros(len(df), dtype="int64")
    y[ag > hg] = 0
    y[ag == hg] = 1
    y[hg > ag] = 2
    return x, y


def _fit_catboost(train_df: pd.DataFrame, cal_df: pd.DataFrame, feature_cols: list[str]) -> CatBoostClassifier:
    x_train, y_train = _prepare_xy(train_df, feature_cols)
    x_cal, y_cal = _prepare_xy(cal_df, feature_cols)
    model = CatBoostClassifier(
        loss_function="MultiClass",
        eval_metric="MultiClass",
        depth=6,
        learning_rate=0.03,
        iterations=1000,
        l2_leaf_reg=10.0,
        random_strength=1.5,
        min_data_in_leaf=15,
        verbose=False,
        random_seed=42,
    )
    model.fit(
        x_train,
        y_train,
        cat_features=[x_train.columns.get_loc(c) for c in V5_CATEGORICAL_COLS],
        eval_set=(x_cal, y_cal),
        use_best_model=True,
        verbose=False,
    )
    return model


def fit_catboost_v5(train_df: pd.DataFrame, cal_df: pd.DataFrame) -> CatBoostClassifier:
    return _fit_catboost(train_df, cal_df, V5_0_FEATURE_COLS)


def fit_catboost_v53(train_df: pd.DataFrame, cal_df: pd.DataFrame) -> CatBoostClassifier:
    return _fit_catboost(train_df, cal_df, V5_3_FEATURE_COLS)


def fit_catboost_v54(train_df: pd.DataFrame, cal_df: pd.DataFrame) -> CatBoostClassifier:
    return _fit_catboost(train_df, cal_df, V5_4_FEATURE_COLS)


def _predict(model: CatBoostClassifier, df: pd.DataFrame, feature_cols: list[str]) -> np.ndarray:
    x, _ = _prepare_xy(df, feature_cols)
    probs = model.predict_proba(x)
    probs = np.asarray(probs, dtype="float64")
    probs = np.clip(probs, 1e-6, 1 - 1e-6)
    probs /= probs.sum(axis=1, keepdims=True)
    return probs


def predict_catboost_v5(model: CatBoostClassifier, df: pd.DataFrame) -> np.ndarray:
    return _predict(model, df, V5_0_FEATURE_COLS)


def predict_catboost_v53(model: CatBoostClassifier, df: pd.DataFrame) -> np.ndarray:
    return _predict(model, df, V5_3_FEATURE_COLS)


def predict_catboost_v54(model: CatBoostClassifier, df: pd.DataFrame) -> np.ndarray:
    return _predict(model, df, V5_4_FEATURE_COLS)
