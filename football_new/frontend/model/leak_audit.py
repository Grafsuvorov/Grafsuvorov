# leak_audit.py
# Проверка на утечку: shuffle-тест
# Python 3.9

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, log_loss

from data.build_dataset import build_dataset
from data.splits import temporal_split_by_league


RANDOM_SEED = 42
np.random.seed(RANDOM_SEED)


def encode_y3(df):
    """
    target_result: -1 / 0 / 1 -> 0 / 1 / 2
    """
    return df["target_result"].map({-1: 0, 0: 1, 1: 2}).astype(int).values


def build_feature_cols(df):
    """
    Дублируем логику train_outcomes.build_safe_feature_list
    (чтобы аудит был честным)
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
    }

    num_cols = []
    for c in df.columns:
        if c in drop_exact:
            continue
        if pd.api.types.is_numeric_dtype(df[c]):
            num_cols.append(c)

    safe = []
    for c in num_cols:
        lc = c.lower()
        if ("goal" in lc or "score" in lc) and not any(
            sfx in lc for sfx in ("_mean", "_std", "_ema", "_sum", "_slope")
        ):
            continue
        safe.append(c)

    return sorted(set(safe))


def main():
    print("=== BUILD DATASET ===")
    df = build_dataset(return_all=False)
    print("df shape:", df.shape)

    print("\n=== SPLIT ===")
    tr, cal, val = temporal_split_by_league(
        df,
        ts_col="date_utc",
        league_col="league_id",
        cal_days=90,
        val_days=14,
        gap_days=0,
        min_cal_per_league=12,
        min_val_per_league=6,
    )

    print("TR / CAL / VAL:", len(tr), len(cal), len(val))

    # Проверка пересечений по fixture_id
    inter = (
        set(tr.fixture_id)
        & set(cal.fixture_id)
        | set(tr.fixture_id)
        & set(val.fixture_id)
        | set(cal.fixture_id)
        & set(val.fixture_id)
    )
    print("intersection fixture_id:", len(inter))

    feats = build_feature_cols(df)
    print("n features:", len(feats))

    # ===== matrices =====
    X_tr = (
        tr[feats]
        .replace([np.inf, -np.inf], np.nan)
        .fillna(0.0)
        .astype("float32")
        .values
    )
    X_val = (
        val[feats]
        .replace([np.inf, -np.inf], np.nan)
        .fillna(0.0)
        .astype("float32")
        .values
    )

    y_tr = encode_y3(tr)
    y_val = encode_y3(val)

    # ===== baseline =====
    print("\n=== REAL TARGET ===")
    lr = LogisticRegression(
        max_iter=400,
        multi_class="multinomial",
        solver="lbfgs",
    )
    lr.fit(X_tr, y_tr)

    P = lr.predict_proba(X_val)
    pred = P.argmax(axis=1)

    print(
        "[REAL]",
        "acc:", round(accuracy_score(y_val, pred), 4),
        "LL:", round(log_loss(y_val, P, labels=[0, 1, 2]), 4),
    )

    # ===== shuffle test =====
    print("\n=== SHUFFLED TARGET ===")
    y_tr_sh = y_tr.copy()
    np.random.shuffle(y_tr_sh)

    lr2 = LogisticRegression(
        max_iter=400,
        multi_class="multinomial",
        solver="lbfgs",
    )
    lr2.fit(X_tr, y_tr_sh)

    P2 = lr2.predict_proba(X_val)
    pred2 = P2.argmax(axis=1)

    print(
        "[SHUFFLE]",
        "acc:", round(accuracy_score(y_val, pred2), 4),
        "LL:", round(log_loss(y_val, P2, labels=[0, 1, 2]), 4),
    )


if __name__ == "__main__":
    main()
