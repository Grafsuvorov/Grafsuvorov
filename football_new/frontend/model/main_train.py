# main_train.py
import joblib

from data.build_dataset import build_dataset
from data.loader import load_stats

from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.team_stats_form import build_team_stats_form
from features.team_potential import build_team_potential_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.build_matrix import build_feature_matrix
from features.league import build_league_context_features
from features.draw_diff import add_draw_diff_features
from features.outcome_script import build_result_script_features, add_outcome_scenario_features

from train_outcomes import train_outcomes
from train_totals import train_totals
from models.inference import predict_totals
from models.inference import predict_outcomes
from models.totals_auxiliary import train_totals_auxiliary
from models.totals_auxiliary import apply_totals_auxiliary
from models.outcome_auxiliary import train_outcome_auxiliary
from models.epl_totals_head import train_epl_totals_head
from models.epl_totals_model import train_epl_totals_model
from config import TOTALS_AUX_MODEL_PATH, TOTALS_MODEL_PATH, OUTCOME_MODEL_PATH


def main():
    print("=== BUILDING DATASET ===")
    df_all = build_dataset(return_all=True)
    print(f"DATASET SHAPE (raw): {df_all.shape}")

    print("=== BUILD FEATURES (train) ===")
    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()
    feats_list = [
        build_elo_features(df_all, mode="train"),
        build_form_xg_features(df_all, match_stats, window=5),
        build_team_stats_form(df_all, match_stats, window=5),
        build_team_potential_features(df_all),
        build_h2h_features(df_all, mode="train"),
        build_h2h_recent_features(df_all, window=5),
        build_league_context_features(df_all, window=60),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats_list, target_df=None)
    df_all = add_draw_diff_features(df_all)
    df_all = df_all.merge(build_result_script_features(df_all), on="fixture_id", how="left")
    df_all = add_outcome_scenario_features(df_all)
    print(f"DATASET SHAPE (with feats): {df_all.shape}")

    # тренируемся только на матчах с результатом
    df_train = df_all[df_all["has_result"]].copy()
    print(f"TRAIN SHAPE: {df_train.shape}")

    print("\n=== TRAINING OUTCOME MODEL (1X2) ===")
    res_out = train_outcomes(df_train)
    print("\nOUTCOME READY:", res_out)

    print("\n=== TRAINING OUTCOME AUXILIARY LAYER ===")
    outcome_bundle = joblib.load(OUTCOME_MODEL_PATH)
    P_out_train = predict_outcomes(df_train, outcome_bundle)
    df_out_aux = df_train.copy()
    df_out_aux["p_home"] = P_out_train[:, 2]
    df_out_aux["p_draw"] = P_out_train[:, 1]
    df_out_aux["p_away"] = P_out_train[:, 0]
    train_outcome_auxiliary(df_out_aux)
    print("\nOUTCOME AUX READY")

    print("\n=== TRAINING TOTALS MODEL (OVER 2.5) ===")
    res_tot = train_totals(df_train)
    print("\nTOTALS READY:", res_tot)

    print("\n=== TRAINING TOTALS AUXILIARY LAYER ===")
    totals_bundle = joblib.load(TOTALS_MODEL_PATH)
    p_base_train = predict_totals(df_train, totals_bundle)
    train_totals_auxiliary(df_train, p_base_train)
    print("\nTOTALS AUX READY")

    print("\n=== TRAINING EPL TOTALS HEAD ===")
    try:
        totals_aux_bundle = joblib.load(TOTALS_AUX_MODEL_PATH)
    except Exception:
        totals_aux_bundle = None
    p_base_train = apply_totals_auxiliary(df_train, p_base_train, totals_aux_bundle)
    train_epl_totals_head(df_train, p_base_train)
    print("\nEPL TOTALS HEAD READY")

    print("\n=== TRAINING EPL TOTALS STANDALONE MODEL ===")
    train_epl_totals_model(df_train)
    print("\nEPL TOTALS MODEL READY")


if __name__ == "__main__":
    main()
