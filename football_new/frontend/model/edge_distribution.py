# edge_distribution.py
import pandas as pd
import numpy as np
from sqlalchemy import create_engine, text

from config import DB_URL

DATE_FROM = "2025-08-01"
DATE_TO   = "2026-01-30"
SCHEMA = "football"


def _compute_p_over_mkt(df: pd.DataFrame) -> pd.Series:
    """
    Имплицитная вероятность Over2.5 из линии (с учётом overround)
    """
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")

    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)

    overround = imp_over + imp_under
    return imp_over / overround


def main():
    engine = create_engine(DB_URL)

    print("Loading data for EDGE distribution...")

    q = text("""
        SELECT
            p.fixture_id,
            s.league_id,
            p.p_over25,
            m.avg_odds_over25,
            m.avg_odds_under25
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s
          ON s.fixture_id = p.fixture_id
        JOIN football.v_ml_epl_training m
          ON m.fixture_id = p.fixture_id
        WHERE s.date BETWEEN :dfrom AND :dto
          AND p.p_over25 IS NOT NULL
          AND m.avg_odds_over25 IS NOT NULL
          AND m.avg_odds_under25 IS NOT NULL
    """)

    df = pd.read_sql(
        q,
        engine,
        params={"dfrom": DATE_FROM, "dto": DATE_TO}
    )

    print(f"Loaded rows: {len(df)}")

    if df.empty:
        print("❌ No data")
        return

    # ===== EDGE =====
    df["p_over_mkt"] = _compute_p_over_mkt(df)
    df["edge"] = df["p_over25"] - df["p_over_mkt"]

    df = df[np.isfinite(df["edge"])].copy()

    print("\n=== BASIC EDGE STATS ===")
    print(df["edge"].describe(percentiles=[0.01, 0.05, 0.10, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99]))

    # ===== BINS =====
    bins = [-1, -0.10, -0.05, 0, 0.03, 0.05, 0.08, 0.10, 0.15, 0.20, 0.30, 1]
    labels = [
        "< -10%",
        "-10% – -5%",
        "-5% – 0%",
        "0 – 3%",
        "3 – 5%",
        "5 – 8%",
        "8 – 10%",
        "10 – 15%",
        "15 – 20%",
        "20 – 30%",
        "30%+",
    ]

    df["edge_bin"] = pd.cut(df["edge"], bins=bins, labels=labels)

    dist = (
        df.groupby("edge_bin")
        .agg(
            matches=("edge", "count"),
            avg_edge=("edge", "mean"),
        )
        .reset_index()
    )

    dist["share_%"] = 100 * dist["matches"] / dist["matches"].sum()

    print("\n=== EDGE DISTRIBUTION (ALL MATCHES) ===")
    print(dist)

    # ===== BY LEAGUE =====
    print("\n=== EDGE >= 5% BY LEAGUE ===")
    df5 = df[df["edge"] >= 0.05]
    g5 = df5.groupby("league_id").agg(
        matches=("edge", "count"),
        avg_edge=("edge", "mean"),
    ).sort_values("matches", ascending=False)
    print(g5)

    print("\n=== EDGE >= 10% BY LEAGUE ===")
    df10 = df[df["edge"] >= 0.10]
    g10 = df10.groupby("league_id").agg(
        matches=("edge", "count"),
        avg_edge=("edge", "mean"),
    ).sort_values("matches", ascending=False)
    print(g10)


if __name__ == "__main__":
    main()
