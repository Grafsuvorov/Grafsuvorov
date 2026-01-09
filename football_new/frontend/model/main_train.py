# main_train.py
from data.build_dataset import build_dataset

from features.elo import build_elo_features
from features.form import build_form_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.streaks import build_streak_features
from features.momentum import build_momentum_features
from features.build_matrix import build_feature_matrix
from features.league import build_league_context_features

from train_outcomes import train_outcomes
from train_totals import train_totals


def main():
    print("=== BUILDING DATASET ===")
    df_all = build_dataset(return_all=True)
    print(f"DATASET SHAPE (raw): {df_all.shape}")

    print("=== BUILD FEATURES (train) ===")
    feats_list = [
        build_elo_features(df_all, mode="train"),
        build_form_features(df_all, mode="train"),
        build_h2h_features(df_all, mode="train"),
        build_h2h_recent_features(df_all, window=5),
        build_streak_features(df_all, window=6),
        build_momentum_features(df_all, short_span=3, long_span=8),
        build_league_context_features(df_all, window=60),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats_list, target_df=None)
    print(f"DATASET SHAPE (with feats): {df_all.shape}")

    # тренируемся только на матчах с результатом
    df_train = df_all[df_all["has_result"]].copy()
    print(f"TRAIN SHAPE: {df_train.shape}")

    print("\n=== TRAINING OUTCOME MODEL (1X2) ===")
    res_out = train_outcomes(df_train)
    print("\nOUTCOME READY:", res_out)

    print("\n=== TRAINING TOTALS MODEL (OVER 2.5) ===")
    res_tot = train_totals(df_train)
    print("\nTOTALS READY:", res_tot)


if __name__ == "__main__":
    main()
