from data.build_dataset import build_dataset
from data.loader import load_stats
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.totals_features import build_totals_feature_list
from models.epl_totals_model import train_epl_totals_model


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

    print("=== TRAIN EPL TOTALS MODEL ===")
    bundle = train_epl_totals_model(df_train)
    print(
        f"[EPL-TOTALS] enabled={bundle.get('enabled')} "
        f"roi={bundle.get('shadow_roi')} profit={bundle.get('shadow_profit')} "
        f"bets={bundle.get('shadow_bets')} params={bundle.get('params')}"
    )


if __name__ == "__main__":
    main()
