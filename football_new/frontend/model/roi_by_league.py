# roi_by_league.py
import pandas as pd
import numpy as np
from sqlalchemy import create_engine, text

# ======================
# CONFIG
# ======================
DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"

DATE_FROM = "2025-11-01"
DATE_TO   = "2026-01-05"

SCHEMA = "football"

# ======================
# HELPERS
# ======================
def profit_1x2(row):
    if row.best_bet_outcome == "Home":
        return row.avg_odds_home - 1 if row.home_goals > row.away_goals else -1
    if row.best_bet_outcome == "Away":
        return row.avg_odds_away - 1 if row.home_goals < row.away_goals else -1
    if row.best_bet_outcome == "Draw":
        return row.avg_odds_draw - 1 if row.home_goals == row.away_goals else -1
    return 0.0


def profit_total(row):
    goals = row.home_goals + row.away_goals
    if row.best_bet_outcome == "Over2.5":
        return row.avg_odds_over25 - 1 if goals > 2.5 else -1
    if row.best_bet_outcome == "Under2.5":
        return row.avg_odds_under25 - 1 if goals <= 2.5 else -1
    return 0.0


def roi_df(df):
    if df.empty:
        return pd.DataFrame(columns=["bets", "profit", "roi"])

    g = df.groupby("league_id").agg(
        bets=("profit", "count"),
        profit=("profit", "sum")
    )
    g["roi"] = g["profit"] / g["bets"]
    return g.sort_values("roi", ascending=False)


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

            p.best_bet_type,
            p.best_bet_outcome,
            p.bet_rating,

            m.avg_odds_home,
            m.avg_odds_draw,
            m.avg_odds_away,
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
          AND p.best_bet_type IS NOT NULL
          AND p.best_bet_type <> 'NONE'
    """)

    df = pd.read_sql(
        q,
        engine,
        params={"dfrom": DATE_FROM, "dto": DATE_TO}
    )

    print(f"Loaded rows (played bets): {len(df)}")

    if df.empty:
        print("❌ No bets in period")
        return

    # ======================
    # SPLIT BETS
    # ======================
    df_1x2 = df[df.best_bet_type == "1X2"].copy()
    df_tot = df[df.best_bet_type.isin(["OVER25", "UNDER25"])].copy()
    df_draw = df_1x2[df_1x2.best_bet_outcome == "Draw"].copy()

    # ======================
    # CALC PROFIT
    # ======================
    df_1x2["profit"] = df_1x2.apply(profit_1x2, axis=1)
    df_tot["profit"] = df_tot.apply(profit_total, axis=1)
    df_draw["profit"] = df_draw.apply(profit_1x2, axis=1)

    # ======================
    # OUTPUT
    # ======================
    print("\n=== ROI 1X2 by league ===")
    print(roi_df(df_1x2))

    print("\n=== ROI TOTALS by league ===")
    print(roi_df(df_tot))

    print("\n=== ROI DRAWS ONLY ===")
    print(roi_df(df_draw))

    print("\n=== OVERALL ===")
    def overall(x):
        return {
            "bets": len(x),
            "profit": round(x["profit"].sum(), 2),
            "roi": round(x["profit"].sum() / len(x), 4) if len(x) else np.nan
        }

    print("1X2:", overall(df_1x2))
    print("TOTAL:", overall(df_tot))
    print("DRAW:", overall(df_draw))


if __name__ == "__main__":
    main()
