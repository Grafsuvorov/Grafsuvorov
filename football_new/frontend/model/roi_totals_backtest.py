# roi_totals_backtest.py

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL
from decision.totals_decision import decide_total_bet

TEST_FROM = "2025-08-01"
TEST_TO = "2026-01-30"

# For diagnostic run: include all matches (no decision filters)
APPLY_DECISION = True

EDGE_BINS = [0.08, 0.10, 0.15, 1.0]
EDGE_LABELS = ["8–10%", "10–15%", "15%+"]

LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}


def _compute_p_market(df: pd.DataFrame) -> pd.Series:
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")

    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    return imp_over / overround


def _profit(row) -> float:
    goals = row.home_goals + row.away_goals
    if row.bet_decision in {"A", "B", "ALL"}:
        # Use calibrated side selection (p_model), consistent with decision logic.
        if row.p_model >= 0.5:
            return row.avg_odds_over25 - 1 if goals > 2.5 else -1
        return row.avg_odds_under25 - 1 if goals <= 2.5 else -1
    return 0.0


def main():
    engine = create_engine(DB_URL)

    q = text(
        """
        SELECT
            p.fixture_id,
            s.league_id,
            s.home_goals,
            s.away_goals,
            p.p_over25,
            m.avg_odds_over25,
            m.avg_odds_under25
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s
          ON s.fixture_id = p.fixture_id
        JOIN football.v_ml_epl_training m
          ON m.fixture_id = p.fixture_id
        WHERE s.date BETWEEN :dfrom AND :dto
          AND s.home_goals IS NOT NULL
          AND s.away_goals IS NOT NULL
        """
    )

    df = pd.read_sql(q, engine, params={"dfrom": TEST_FROM, "dto": TEST_TO})
    if df.empty:
        print("No data in TEST period")
        return

    df["p_market"] = _compute_p_market(df)
    df["p_model"] = df["p_over25"]
    # League-specific calibration (La Liga)
    df.loc[df["league_id"] == 140, "p_model"] = (
        0.9 * df.loc[df["league_id"] == 140, "p_over25"]
        + 0.1 * df.loc[df["league_id"] == 140, "p_market"]
    )
    df["edge"] = df["p_model"] - df["p_market"]
    df["odds_side"] = np.where(
        df["p_model"] >= 0.5,
        df["avg_odds_over25"],
        df["avg_odds_under25"],
    )

    missing_odds = df["odds_side"].isna().sum()
    if missing_odds:
        print(f"[WARN] Missing odds_side for {missing_odds} rows")
    df = df[df["odds_side"].notna()].copy()

    if APPLY_DECISION:
        df["bet_decision"] = [
            decide_total_bet(edge, odds, lid, p)
            for edge, odds, lid, p in zip(df["edge"], df["odds_side"], df["league_id"], df["p_model"])
        ]
    else:
        df["bet_decision"] = "ALL"

    matches_total = len(df)
    bets_df = df[df["bet_decision"].isin(["A", "B"])].copy() if APPLY_DECISION else df.copy()
    bets_total = len(bets_df)
    coverage = bets_total / matches_total if matches_total else 0.0

    bets_df["stake"] = (
        np.where(bets_df["bet_decision"] == "A", 1.0, 0.4)
        if APPLY_DECISION
        else 1.0
    )
    bets_df["profit_raw"] = bets_df.apply(_profit, axis=1)
    bets_df["profit"] = bets_df["profit_raw"] * bets_df["stake"]

    overall = {
        "matches": matches_total,
        "bets": bets_total,
        "coverage": coverage,
        "profit": bets_df["profit"].sum(),
        "roi": bets_df["profit"].sum() / bets_df["stake"].sum() if bets_total else np.nan,
    }

    by_league = bets_df.groupby("league_id").agg(
        bets=("fixture_id", "count"),
        stake=("stake", "sum"),
        profit=("profit", "sum"),
    )
    total_by_league = df.groupby("league_id").agg(
        matches_total=("fixture_id", "count"),
    )
    by_league = by_league.join(total_by_league)
    by_league["coverage"] = by_league["bets"] / by_league["matches_total"]
    by_league["roi"] = by_league["profit"] / by_league["stake"]

    bets_df["edge_bin"] = pd.cut(bets_df["edge"], bins=EDGE_BINS, labels=EDGE_LABELS, include_lowest=True)
    bins = bets_df.groupby("edge_bin").agg(
        bets=("fixture_id", "count"),
        stake=("stake", "sum"),
        profit=("profit", "sum"),
    )
    bins["share"] = bins["bets"] / bets_total if bets_total else 0.0
    bins["roi"] = bins["profit"] / bins["stake"]

    edge_quantiles = df["edge"].quantile([0.1, 0.25, 0.5, 0.75, 0.9]).to_dict()

    print("\n=== OVERALL (TEST) ===")
    print(overall)

    print("\n=== OUTCOMES (ALL MATCHES) ===")
    df["total_goals"] = df["home_goals"] + df["away_goals"]
    df["is_over25"] = df["total_goals"] > 2.5
    print(df["is_over25"].value_counts())

    bets_df["is_over25"] = df.loc[bets_df.index, "is_over25"].values
    bets_df["bet_side"] = np.where(bets_df["p_model"] >= 0.5, "OVER", "UNDER")
    bets_df["win"] = np.where(bets_df["bet_side"] == "OVER", bets_df["is_over25"], ~bets_df["is_over25"])
    print("\n=== MODEL SIDE (ALL MATCHES) ===")
    print(bets_df.groupby("bet_side")["win"].agg(["count", "sum"]))

    print("\n=== ROI BY LEAGUE (TEST) ===")
    by_league = by_league.reset_index()
    by_league["league"] = by_league["league_id"].map(LEAGUE_NAMES).fillna(by_league["league_id"].astype(str))
    by_league = by_league.set_index("league").drop(columns=["league_id"])
    print(by_league.sort_values("roi", ascending=False))

    print("\n=== EDGE BINS (TEST, bets only) ===")
    print(bins)

    print("\n=== EDGE QUANTILES (all matches) ===")
    print(edge_quantiles)

    print(f"\nMatches filtered due to missing odds: {missing_odds}")


if __name__ == "__main__":
    main()
