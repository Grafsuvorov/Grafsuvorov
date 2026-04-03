import joblib

from config import TOTALS_MODEL_PATH
from data.build_dataset import build_dataset
from data.loader import load_stats
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.totals_features import build_totals_feature_list
from models.inference import predict_totals
from models.totals_auxiliary import train_totals_auxiliary


def main():
    print("=== BUILD DATASET ===")
    df_all = build_dataset(return_all=True)

    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()

    print("=== BUILD TOTALS FEATURES ===")
    feats = build_totals_feature_list(df_all, match_stats, mode="train")
    df_all = build_feature_matrix(df_all, feats)
    df_all = add_draw_diff_features(df_all)

    df_train = df_all[df_all["has_result"]].copy()
    totals_bundle = joblib.load(TOTALS_MODEL_PATH)
    p_base = predict_totals(df_train, totals_bundle)

    print("=== TRAIN TOTALS AUXILIARY ===")
    bundle = train_totals_auxiliary(df_train, p_base)
    print(f"[AUX] leagues trained: {sorted(bundle.get('leagues', {}).keys())}")


if __name__ == "__main__":
    main()
