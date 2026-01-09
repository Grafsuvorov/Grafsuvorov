# rule_miner.py
import pandas as pd
import numpy as np
from sqlalchemy import create_engine
from config import DB_URL

DATE_FROM = "2025-09-01"
DATE_TO   = "2025-12-14"

MIN_BETS = 10   # минимум ставок для правила


# =========================
# PROFIT FUNCTIONS
# =========================

def profit_1x2(row):
    outcome = row["best_bet_outcome"]

    if outcome == "Home":
        return row["avg_odds_home"] - 1 if row["home_goals"] > row["away_goals"] else -1

    if outcome == "Away":
        return row["avg_odds_away"] - 1 if row["away_goals"] > row["home_goals"] else -1

    if outcome == "Draw":
        return row["avg_odds_draw"] - 1 if row["home_goals"] == row["away_goals"] else -1

    return 0.0


def profit_total(row):
    outcome = row["best_bet_outcome"]
    total_goals = row["home_goals"] + row["away_goals"]

    if outcome == "Over2.5":
        return row["avg_odds_over25"] - 1 if total_goals > 2.5 else -1

    if outcome == "Under2.5":
        return row["avg_odds_under25"] - 1 if total_goals <= 2.5 else -1

    return 0.0


# =========================
# LOAD DATA
# =========================

def load_data():
    print("Loading data...")

    q = """
    SELECT
        p.fixture_id,
        s.league_id,
        s.date::date AS match_date,
        s.home_goals,
        s.away_goals,

        p.best_bet_type,
        p.best_bet_outcome,

        v.avg_odds_home,
        v.avg_odds_draw,
        v.avg_odds_away,
        v.avg_odds_over25,
        v.avg_odds_under25

    FROM football.ml_predictions p
    JOIN football.api_football_schedule s
      ON s.fixture_id = p.fixture_id
    JOIN football.v_ml_epl_training v
      ON v.fixture_id = p.fixture_id

    WHERE s.date BETWEEN %(dfrom)s AND %(dto)s
      AND s.home_goals IS NOT NULL
      AND s.away_goals IS NOT NULL
      AND p.best_bet_type IS NOT NULL
      AND p.best_bet_outcome IS NOT NULL
    """

    eng = create_engine(DB_URL)
    df = pd.read_sql(q, eng, params={"dfrom": DATE_FROM, "dto": DATE_TO})

    print(f"Rows loaded: {len(df)}")
    return df


# =========================
# RULE MINING
# =========================

def mine_rules(df: pd.DataFrame) -> pd.DataFrame:
    rows = []

    for (league, btype, bout), g in df.groupby(
        ["league_id", "best_bet_type", "best_bet_outcome"]
    ):
        if len(g) < MIN_BETS:
            continue

        if btype == "1X2":
            profit = g.apply(profit_1x2, axis=1).sum()
        elif btype in ("OVER25", "UNDER25", "TOTAL"):
            profit = g.apply(profit_total, axis=1).sum()
        else:
            continue

        bets = len(g)
        roi = profit / bets if bets > 0 else np.nan

        rows.append({
            "league_id": league,
            "bet_type": btype,
            "bet_outcome": bout,
            "bets": bets,
            "profit": round(profit, 3),
            "roi": round(roi, 4),
        })

    if not rows:
        return pd.DataFrame()

    return (
        pd.DataFrame(rows)
        .sort_values(["roi", "bets"], ascending=[False, False])
        .reset_index(drop=True)
    )


# =========================
# MAIN
# =========================

def main():
    df = load_data()

    rules = mine_rules(df)

    if rules.empty:
        print("No valid rules found.")
        return

    print("\n=== DISCOVERED RULES ===")
    print(rules)

    print("\n=== TOP 10 RULES ===")
    print(rules.head(10))


if __name__ == "__main__":
    main()
