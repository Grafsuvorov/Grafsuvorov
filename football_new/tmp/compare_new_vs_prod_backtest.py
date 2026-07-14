import json
import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "frontend" / "model"
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(MODEL_DIR))

from config import DB_URL, OUTCOME_AUX_MODEL_PATH
from data.build_dataset import build_dataset
from data.loader import load_stats
from decision.outcomes_decision import decide_outcome_bet
from decision.totals_decision import decide_total_bet
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.match_context import build_match_context_features
from features.outcome_script import (
    add_outcome_scenario_features,
    build_result_script_features,
)
from features.team_potential import build_team_potential_features
from features.team_stats_form import build_team_stats_form
from fill_match_predictions import pick_best
from predictor import MatchPredictor


DATE_FROM = "2025-08-01"
DATE_TO = "2026-01-30"

LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}


def _stake_from_tier(tier: str) -> float:
    if tier == "A":
        return 1.0
    if tier == "B":
        return 0.4
    return 0.0


def _profit_for_pick(row: pd.Series) -> float:
    if row["best_bet_type"] == "1X2":
        if row["best_bet_outcome"] == "Home":
            won = row["home_goals"] > row["away_goals"]
        elif row["best_bet_outcome"] == "Draw":
            won = row["home_goals"] == row["away_goals"]
        else:
            won = row["home_goals"] < row["away_goals"]
    else:
        goals = row["home_goals"] + row["away_goals"]
        if row["best_bet_outcome"] == "Over2.5":
            won = goals > 2.5
        else:
            won = goals <= 2.5
    return float(row["best_bet_odds"] - 1.0) if won else -1.0


def _tier_for_pick(row: pd.Series) -> str:
    if row["best_bet_type"] == "1X2":
        return decide_outcome_bet(
            float(row["best_bet_ev"]),
            float(row["best_bet_odds"]),
            int(row["league_id"]),
            str(row["best_bet_outcome"]),
        )
    p_side = float(row["p_over25"]) if row["best_bet_outcome"] == "Over2.5" else float(row["p_under25"])
    return decide_total_bet(
        float(row["best_bet_ev"]),
        float(row["best_bet_odds"]),
        int(row["league_id"]),
        p_side,
    )


def _summary(picks: pd.DataFrame) -> dict:
    bets = picks[picks["best_bet_type"] != "NONE"].copy()
    if bets.empty:
        return {"overall": {"matches": int(len(picks)), "bets": 0, "profit": 0.0, "roi": None}}

    bets["tier"] = bets.apply(_tier_for_pick, axis=1)
    bets = bets[bets["tier"].isin(["A", "B"])].copy()
    bets["stake"] = bets["tier"].map(_stake_from_tier)
    bets["profit"] = bets.apply(_profit_for_pick, axis=1) * bets["stake"]

    overall = {
        "matches": int(len(picks)),
        "bets": int(len(bets)),
        "coverage": float(len(bets) / len(picks)) if len(picks) else 0.0,
        "profit": float(bets["profit"].sum()),
        "roi": float(bets["profit"].sum() / bets["stake"].sum()) if float(bets["stake"].sum()) > 0 else None,
    }

    by_type = {}
    for bet_type, g in bets.groupby("best_bet_type"):
        by_type[str(bet_type)] = {
            "bets": int(len(g)),
            "profit": float(g["profit"].sum()),
            "roi": float(g["profit"].sum() / g["stake"].sum()) if float(g["stake"].sum()) > 0 else None,
        }

    by_outcome = {}
    for outcome, g in bets.groupby("best_bet_outcome"):
        by_outcome[str(outcome)] = {
            "bets": int(len(g)),
            "profit": float(g["profit"].sum()),
            "roi": float(g["profit"].sum() / g["stake"].sum()) if float(g["stake"].sum()) > 0 else None,
        }

    by_league = {}
    for lid, g in bets.groupby("league_id"):
        lid = int(lid)
        by_league[str(lid)] = {
            "league": LEAGUE_NAMES.get(lid, str(lid)),
            "bets": int(len(g)),
            "profit": float(g["profit"].sum()),
            "roi": float(g["profit"].sum() / g["stake"].sum()) if float(g["stake"].sum()) > 0 else None,
            "types": {
                t: {
                    "bets": int(len(x)),
                    "profit": float(x["profit"].sum()),
                    "roi": float(x["profit"].sum() / x["stake"].sum()) if float(x["stake"].sum()) > 0 else None,
                }
                for t, x in g.groupby("best_bet_type")
            },
        }

    return {"overall": overall, "by_type": by_type, "by_outcome": by_outcome, "by_league": by_league}


def _build_feature_frame() -> pd.DataFrame:
    df_all = build_dataset(return_all=True)
    df_all["date_utc"] = pd.to_datetime(df_all["date_utc"], errors="coerce")
    if pd.api.types.is_datetime64tz_dtype(df_all["date_utc"]):
        df_all["date_utc"] = df_all["date_utc"].dt.tz_localize(None)

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
        build_match_context_features(df_all, lookback=5),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats_list, target_df=None)
    df_all = add_draw_diff_features(df_all)
    df_all = df_all.merge(build_result_script_features(df_all), on="fixture_id", how="left")
    df_all = add_outcome_scenario_features(df_all)

    mask = (
        (df_all["date_utc"] >= pd.to_datetime(DATE_FROM)) &
        (df_all["date_utc"] <= pd.to_datetime(DATE_TO)) &
        df_all["home_goals"].notna() &
        df_all["away_goals"].notna()
    )
    return df_all.loc[mask].copy()


def _load_prod_predictions(engine) -> pd.DataFrame:
    q = text(
        """
        SELECT
            p.fixture_id,
            p.p_home,
            p.p_draw,
            p.p_away,
            p.p_over25
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s
          ON s.fixture_id = p.fixture_id
        WHERE s.date BETWEEN :dfrom AND :dto
          AND s.home_goals IS NOT NULL
          AND s.away_goals IS NOT NULL
        """
    )
    return pd.read_sql(q, engine, params={"dfrom": DATE_FROM, "dto": DATE_TO})


def main():
    engine = create_engine(DB_URL)
    aux_bundle = joblib.load(OUTCOME_AUX_MODEL_PATH)

    base = _build_feature_frame()
    predictor = MatchPredictor()
    pred_new = predictor.predict(base)
    new_preds = pd.DataFrame(
        {
            "fixture_id": base["fixture_id"].astype(int).values,
            "p_home": pred_new["p_outcome"][:, 2],
            "p_draw": pred_new["p_outcome"][:, 1],
            "p_away": pred_new["p_outcome"][:, 0],
            "p_over25": pred_new["p_over25"],
        }
    )

    prod_preds = _load_prod_predictions(engine)
    hybrid_preds = prod_preds.merge(
        new_preds[["fixture_id", "p_home", "p_draw", "p_away"]],
        on="fixture_id",
        how="inner",
        suffixes=("_prod", "_new"),
    )
    hybrid_preds = pd.DataFrame(
        {
            "fixture_id": hybrid_preds["fixture_id"].astype(int),
            "p_home": hybrid_preds["p_home_new"],
            "p_draw": hybrid_preds["p_draw_new"],
            "p_away": hybrid_preds["p_away_new"],
            "p_over25": hybrid_preds["p_over25"],
        }
    )

    def build_df(preds: pd.DataFrame) -> pd.DataFrame:
        base_cols = [
            c for c in base.columns
            if c not in {"p_home", "p_draw", "p_away", "p_over25", "p_under25", "_outcome_aux_bundle"}
        ]
        pred_cols = ["fixture_id", "p_home", "p_draw", "p_away", "p_over25"]
        df = base[base_cols].merge(preds[pred_cols], on="fixture_id", how="inner")
        df["p_under25"] = 1.0 - pd.to_numeric(df["p_over25"], errors="coerce")
        df["_outcome_aux_bundle"] = [aux_bundle] * len(df)
        picks = df.apply(pick_best, axis=1)
        return pd.concat([df.reset_index(drop=True), picks.reset_index(drop=True)], axis=1)

    prod_df = build_df(prod_preds)
    new_df = build_df(new_preds)
    hybrid_df = build_df(hybrid_preds)

    report = {
        "window": {"date_from": DATE_FROM, "date_to": DATE_TO, "matches": int(len(base))},
        "prod": _summary(prod_df),
        "new": _summary(new_df),
        "hybrid_outcomes_new_totals_prod": _summary(hybrid_df),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
