# roi_totals_analysis.py

import pandas as pd
import numpy as np
from sqlalchemy import create_engine, text

from config import DB_URL
from decision.totals_decision import decide_total_bet

# ======================
# CONFIG
# ======================
DATE_FROM = "2025-08-01"
DATE_TO   = "2026-01-30"
SCHEMA = "football"

# ======================
# HELPERS
# ======================

def compute_p_over_mkt(df: pd.DataFrame) -> pd.Series:
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")

    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)

    overround = imp_over + imp_under
    return imp_over / overround


def profit_total(row):
    goals = row.home_goals + row.away_goals

    if row.side == "OVER":
        return row.avg_odds_over25 - 1 if goals > 2.5 else -1
    if row.side == "UNDER":
        return row.avg_odds_under25 - 1 if goals <= 2.5 else -1
    return 0.0


def summarize(df: pd.DataFrame):
    if df.empty:
        return {"bets": 0, "stake": 0.0, "profit": 0.0, "roi": np.nan}

    stake = df["stake"].sum()
    profit = df["profit"].sum()

    return {
        "bets": len(df),
        "stake": round(stake, 2),
        "profit": round(profit, 2),
        "roi": round(profit / stake, 4) if stake > 0 else np.nan,
    }


# ======================
# MAIN
# ======================

def main():
    engine = create_engine(DB_URL)

    print("Loading data...")

    q = text("""
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
    """)

    df = pd.read_sql(q, engine, params={"dfrom": DATE_FROM, "dto": DATE_TO})
    print(f"Loaded matches: {len(df)}")

    if df.empty:
        return

    # ======================
    # EDGE
    # ======================
    df["p_over_mkt"] = compute_p_over_mkt(df)
    df["edge"] = df["p_over25"] - df["p_over_mkt"]

    # ======================
    # DECISION (ONE TIME!)
    # ======================
    decisions = []
    sides = []
    stakes = []

    for edge, p, o_over, o_under, lid in zip(
        df.edge,
        df.p_over25,
        df.avg_odds_over25,
        df.avg_odds_under25,
        df.league_id,
    ):
        odds = o_over if p > 0.5 else o_under
        d = decide_total_bet(edge, odds, lid, p)

        if d == "A":
            stake = 1.0
        elif d == "B":
            stake = 0.5
        else:
            stake = 0.0

        side = "OVER" if p > 0.5 else "UNDER"

        decisions.append(d)
        stakes.append(stake)
        sides.append(side)

    df["tier"] = decisions
    df["stake"] = stakes
    df["side"] = sides

    # ======================
    # FILTER BETS
    # ======================
    bets = df[df.stake > 0].copy()
    print(f"Total bets: {len(bets)}")

    if bets.empty:
        return

    # ======================
    # PROFIT
    # ======================
    bets["profit_raw"] = bets.apply(profit_total, axis=1)
    bets["profit"] = bets["profit_raw"] * bets["stake"]

    # ======================
    # OUTPUT
    # ======================
    print("\n=== OVERALL ===")
    print(summarize(bets))

    print("\n=== BY TIER ===")
    for tier in ["A", "B"]:
        print(tier, summarize(bets[bets.tier == tier]))

    print("\n=== BY LEAGUE ===")
    by_league = bets.groupby("league_id").apply(summarize)
    print(pd.DataFrame(by_league.tolist(), index=by_league.index))


if __name__ == "__main__":
    main()
