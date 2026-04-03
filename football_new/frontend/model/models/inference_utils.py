# models/inference_utils.py

import os
import numpy as np
import pandas as pd


def ensure_features_soft(
    df: pd.DataFrame,
    feature_cols,
    *,
    fatal_if_all_missing=True,
    priors=None,
):
    """
    SOFT feature check:
    - creates missing features filled with 0.0
    - warns about missing count
    - protects from constant matrix (identical rows)
    """
    feature_cols = list(feature_cols)

    missing = [c for c in feature_cols if c not in df.columns]

    if fatal_if_all_missing and len(missing) == len(feature_cols):
        raise RuntimeError(
            f"[FATAL] Inference missing ALL features ({len(missing)}). "
            "Dataset does not contain any model feature columns."
        )

    if missing:
        # create missing columns with priors / safe defaults
        for c in missing:
            fill_val = 0.0
            if priors and c in priors:
                try:
                    fill_val = float(priors[c])
                except Exception:
                    fill_val = 0.0
            df[c] = fill_val

        print(
            f"[WARN] Inference missing {len(missing)} features -> filled with zeros. "
            f"Examples: {missing[:12]}"
        )

    X = df[feature_cols].replace([np.inf, -np.inf], np.nan)

    if priors:
        priors_series = pd.Series(
            {k: float(v) for k, v in priors.items() if k in X.columns}
        )
        X = X.fillna(priors_series)

    X = X.fillna(0.0).astype("float32")

    # protect from identical predictions due to constant features
    uniq = pd.util.hash_pandas_object(X, index=False).nunique()
    if len(X) > 1 and uniq <= 1:
        raise RuntimeError(
            "[FATAL] Feature matrix is constant. "
            "All rows identical → identical predictions guaranteed. "
            "You are likely not building any varying features for future matches."
        )

    return X, missing


def ensure_features_strict(df: pd.DataFrame, feature_cols):
    """
    STRICT feature check:
    - no silent zeros
    - no constant matrix
    """
    feature_cols = list(feature_cols)

    missing = [c for c in feature_cols if c not in df.columns]
    if missing:
        raise RuntimeError(
            f"[FATAL] Inference missing {len(missing)} features.\n"
            f"Examples: {missing[:20]}"
        )

    X = (
        df[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .fillna(0.0)
        .astype("float32")
    )

    uniq = pd.util.hash_pandas_object(X, index=False).nunique()
    if len(X) > 1 and uniq <= 1:
        raise RuntimeError(
            "[FATAL] Feature matrix is constant. "
            "All rows identical → identical predictions guaranteed."
        )

    return X
