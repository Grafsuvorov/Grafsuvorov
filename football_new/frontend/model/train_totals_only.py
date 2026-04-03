# train_totals_only.py

import numpy as np
import pandas as pd
import xgboost as xgb
import joblib

from sklearn.isotonic import IsotonicRegression
from sklearn.model_selection import train_test_split

from data.build_dataset import build_dataset
from data.loader import load_stats
from features.build_matrix import build_feature_matrix
from features.totals_features import build_totals_feature_list
from train_outcomes import build_safe_feature_list
from config import TOTALS_MODEL_PATH


def train_totals(df, feature_cols, target_col="is_over25"):
    X = df[feature_cols].astype("float32")
    y = df[target_col].astype(int)

    X_tr, X_val, y_tr, y_val = train_test_split(
        X, y, test_size=0.2, shuffle=False
    )

    model = xgb.XGBClassifier(
        n_estimators=600,
        max_depth=4,
        learning_rate=0.03,
        subsample=0.8,
        colsample_bytree=0.8,
        objective="binary:logistic",
        eval_metric="logloss",
        random_state=42,
    )

    model.fit(
        X_tr, y_tr,
        eval_set=[(X_val, y_val)],
        verbose=False,
    )

    # raw probs
    p_val = model.predict_proba(X_val)[:, 1]

    # isotonic calibration
    iso = IsotonicRegression(out_of_bounds="clip")
    iso.fit(p_val, y_val)

    bundle = {
        "xgb_model": model,
        "feature_cols": feature_cols,
        "calibrator": iso,
    }

    joblib.dump(bundle, TOTALS_MODEL_PATH)
    print(f"[OK] Totals model saved to {TOTALS_MODEL_PATH}")


def main():
    print("=== BUILD DATASET ===")
    df_all = build_dataset(return_all=True)

    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()

    print("=== BUILD FEATURES (totals only) ===")
    feats_list = build_totals_feature_list(df_all, match_stats, mode="train")
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats_list, target_df=None)

    df_train = df_all[df_all["has_result"]].copy()
    if "target_over25" not in df_train.columns:
        raise RuntimeError("train_totals_only: target_over25 column missing")

    df_train = df_train[df_train["target_over25"].notna()].copy()

    feature_cols = build_safe_feature_list(df_train)
    print("TRAIN FEATURES:", len(feature_cols))
    print(sorted(feature_cols))
    train_totals(df_train, feature_cols, target_col="target_over25")


if __name__ == "__main__":
    main()
