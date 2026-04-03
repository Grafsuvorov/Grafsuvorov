import joblib

from config import OUTCOME_MODEL_PATH
from data.build_dataset import build_dataset
from data.loader import load_stats
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.team_stats_form import build_team_stats_form
from features.team_potential import build_team_potential_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.outcome_script import build_result_script_features, add_outcome_scenario_features
from models.inference import predict_outcomes
from models.outcome_auxiliary import train_outcome_auxiliary


def main():
    print("=== BUILD DATASET ===")
    df_all = build_dataset(return_all=True)

    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()

    print("=== BUILD OUTCOME FEATURES ===")
    feats = [
        build_elo_features(df_all, mode="train"),
        build_form_xg_features(df_all, match_stats, window=5),
        build_team_stats_form(df_all, match_stats, window=5),
        build_team_potential_features(df_all),
        build_h2h_features(df_all, mode="train"),
        build_h2h_recent_features(df_all, window=5),
        build_league_context_features(df_all, window=60),
    ]
    df_all = build_feature_matrix(df_all, feats)
    df_all = add_draw_diff_features(df_all)
    df_all = df_all.merge(build_result_script_features(df_all), on="fixture_id", how="left")
    df_all = add_outcome_scenario_features(df_all)
    df_train = df_all[df_all["has_result"]].copy()

    outcome_bundle = joblib.load(OUTCOME_MODEL_PATH)
    P = predict_outcomes(df_train, outcome_bundle)
    df_train["p_home"] = P[:, 2]
    df_train["p_draw"] = P[:, 1]
    df_train["p_away"] = P[:, 0]

    print("=== TRAIN OUTCOME AUXILIARY ===")
    bundle = train_outcome_auxiliary(df_train)
    print(f"[OUT AUX] leagues trained: {sorted(bundle.get('leagues', {}).keys())}")


if __name__ == "__main__":
    main()
