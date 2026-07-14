import argparse
from datetime import date
import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sqlalchemy import MetaData, Table, create_engine, text
from sqlalchemy.dialects.postgresql import insert as pg_insert

ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "frontend" / "model"
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(MODEL_DIR))

from config import DB_URL, OUTCOME_AUX_MODEL_PATH, OUTCOME_MODEL_PATH
from data.build_dataset import build_dataset
from data.loader import load_stats
from decision.outcomes_decision import decide_outcome_bet
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.match_context import build_match_context_features
from features.outcome_script import add_outcome_scenario_features, build_result_script_features
from features.team_potential import build_team_potential_features
from features.team_stats_form import build_team_stats_form
from fill_match_predictions import pick_best
from predictor import MatchPredictor


SCHEMA = "football"
TABLE = "ml_predictions"
MODEL_VERSION = "xgb_v6_hybrid_outcomes_refresh"


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--date-from", default=str(date.today()))
    p.add_argument("--date-to", required=True)
    return p.parse_args()


def _build_outcome_features(date_from: str, date_to: str) -> pd.DataFrame:
    df_all = build_dataset(return_all=True)
    df_all["date_utc"] = pd.to_datetime(df_all["date_utc"], errors="coerce")
    if pd.api.types.is_datetime64tz_dtype(df_all["date_utc"]):
        df_all["date_utc"] = df_all["date_utc"].dt.tz_localize(None)

    mask = (
        (df_all["date_utc"] >= pd.to_datetime(date_from)) &
        (df_all["date_utc"] <= pd.to_datetime(date_to))
    )
    df_base = df_all.loc[mask].copy()
    if df_base.empty:
        return df_base

    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()

    feats = [
        build_elo_features(df_all, mode="inference"),
        build_form_xg_features(df_all, match_stats, window=5),
        build_team_stats_form(df_all, match_stats, window=5),
        build_team_potential_features(df_all),
        build_h2h_features(df_all, mode="inference"),
        build_h2h_recent_features(df_all, window=5),
        build_league_context_features(df_all, window=60),
        build_match_context_features(df_all, lookback=5),
    ]
    df_feat = build_feature_matrix(df_all, feats)
    df_feat = add_draw_diff_features(df_feat)
    df_feat = df_feat.merge(build_result_script_features(df_all), on="fixture_id", how="left")
    df_feat = add_outcome_scenario_features(df_feat)
    return df_feat.loc[df_feat["fixture_id"].isin(df_base["fixture_id"])].copy()


def _load_existing_totals(engine, fixture_ids) -> pd.DataFrame:
    q = text(
        """
        SELECT
            fixture_id,
            p_over25,
            avg_odds_home,
            avg_odds_draw,
            avg_odds_away,
            avg_odds_over25,
            avg_odds_under25,
            best_bet_type,
            best_bet_outcome,
            best_bet_odds,
            best_bet_ev,
            bet_reason,
            bet_rating
        FROM football.ml_predictions
        WHERE fixture_id = ANY(:fixture_ids)
        """
    )
    return pd.read_sql(q, engine, params={"fixture_ids": list(map(int, fixture_ids))})


def _best_bet_prob(row: pd.Series) -> float | None:
    bet_type = row.get("best_bet_type")
    outcome = row.get("best_bet_outcome")
    if bet_type == "1X2":
        return {
            "Home": row.get("p_home"),
            "Draw": row.get("p_draw"),
            "Away": row.get("p_away"),
        }.get(outcome)
    if bet_type == "TOTAL":
        if outcome == "Over2.5":
            return row.get("p_over25")
        if outcome == "Under2.5":
            return row.get("p_under25")
    return None


def main():
    args = parse_args()
    engine = create_engine(DB_URL)

    df_feat = _build_outcome_features(args.date_from, args.date_to)
    if df_feat.empty:
        print("No fixtures in selected window")
        return

    fixture_ids = df_feat["fixture_id"].astype(int).tolist()
    existing = _load_existing_totals(engine, fixture_ids)
    if existing.empty:
        raise RuntimeError("No existing totals found in ml_predictions for selected fixtures")

    predictor = MatchPredictor(outcome_pkl=OUTCOME_MODEL_PATH)
    pred = predictor.predict(df_feat)

    df = df_feat.copy()
    df["p_home"] = pred["p_outcome"][:, 2]
    df["p_draw"] = pred["p_outcome"][:, 1]
    df["p_away"] = pred["p_outcome"][:, 0]
    df = df.drop(
        columns=[
            c for c in [
                "avg_odds_home",
                "avg_odds_draw",
                "avg_odds_away",
                "avg_odds_over25",
                "avg_odds_under25",
            ]
            if c in df.columns
        ]
    )
    df = df.merge(existing, on="fixture_id", how="left")
    for odds_col in [
        "avg_odds_home",
        "avg_odds_draw",
        "avg_odds_away",
        "avg_odds_over25",
        "avg_odds_under25",
    ]:
        df[odds_col] = pd.to_numeric(df[odds_col], errors="coerce")
    df["p_under25"] = 1.0 - pd.to_numeric(df["p_over25"], errors="coerce")

    try:
        outcome_aux_bundle = joblib.load(OUTCOME_AUX_MODEL_PATH)
    except Exception:
        outcome_aux_bundle = None
    df["_outcome_aux_bundle"] = [outcome_aux_bundle] * len(df)

    existing_best_cols = [
        "best_bet_type",
        "best_bet_outcome",
        "best_bet_odds",
        "best_bet_ev",
        "bet_reason",
        "bet_rating",
    ]
    df = df.rename(columns={c: f"existing_{c}" for c in existing_best_cols if c in df.columns})

    best = df.apply(pick_best, axis=1)
    best.columns = [f"new_{c}" for c in best.columns]
    df = pd.concat([df.reset_index(drop=True), best.reset_index(drop=True)], axis=1)
    for col in ["best_bet_type", "best_bet_outcome", "best_bet_odds", "best_bet_ev"]:
        new_col = f"new_{col}"
        existing_col = f"existing_{col}"
        df[col] = df[new_col]
        if existing_col in df.columns:
            use_existing = df["best_bet_type"].eq("NONE") | df["best_bet_type"].isna()
            df.loc[use_existing, col] = df.loc[use_existing, existing_col]
    df["best_bet_p"] = df.apply(_best_bet_prob, axis=1)

    df["bet_reason"] = df.apply(
        lambda r: (
            f"p={float(r.best_bet_p):.2f} | odds={float(r.best_bet_odds):.2f} | EV={float(r.best_bet_ev):.3f}"
            if pd.notna(r.best_bet_p) and pd.notna(r.best_bet_odds) and pd.notna(r.best_bet_ev)
            else r.get("existing_bet_reason")
        ),
        axis=1,
    )
    df["bet_rating"] = np.where(
        df["best_bet_ev"] >= 0.10,
        "Strong",
        np.where(
            df["best_bet_ev"] >= 0.04,
            "Medium",
            np.where(df["best_bet_ev"] >= 0.01, "Weak", df.get("existing_bet_rating")),
        ),
    )
    df["model_version"] = MODEL_VERSION

    meta = MetaData()
    updated = 0
    with engine.begin() as conn:
        table = Table(TABLE, meta, schema=SCHEMA, autoload_with=conn)
        cols = {
            "fixture_id",
            "p_home",
            "p_draw",
            "p_away",
            "best_bet_type",
            "best_bet_outcome",
            "best_bet_odds",
            "best_bet_ev",
            "bet_reason",
            "bet_rating",
            "model_version",
        }
        for _, row in df.iterrows():
            data = {k: row[k] for k in cols if k in row and pd.notna(row[k])}
            if "fixture_id" not in data:
                continue
            stmt = pg_insert(table).values(**data)
            stmt = stmt.on_conflict_do_update(
                index_elements=[table.c.fixture_id],
                set_={k: stmt.excluded[k] for k in data if k != "fixture_id"},
            )
            conn.execute(stmt)
            updated += 1

    print(
        {
            "date_from": args.date_from,
            "date_to": args.date_to,
            "fixtures": int(len(df)),
            "updated": int(updated),
            "best_bet_type_counts": df["best_bet_type"].fillna("NONE").value_counts().to_dict(),
            "best_bet_outcome_counts": df["best_bet_outcome"].fillna("NONE").value_counts().to_dict(),
        }
    )


if __name__ == "__main__":
    main()
