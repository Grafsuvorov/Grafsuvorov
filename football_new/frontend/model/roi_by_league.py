# roi_by_league.py
import pandas as pd
import numpy as np
from sqlalchemy import create_engine, text

from config import DB_URL
from decision.totals_decision import decide_total_bet
from decision.league_rules import LEAGUE_RULES, DEFAULT_RULE

# ======================
# CONFIG
# ======================
DATE_FROM = "2025-08-01"
DATE_TO   = "2026-01-30"

SCHEMA = "football"

# ======================
# HELPERS
# ======================
def profit_total(row):
    goals = row.home_goals + row.away_goals
    if row.bet_decision not in {"A", "B"}:
        return 0.0

    bet_is_over = row.p_model > 0.5
    if bet_is_over:
        return row.avg_odds_over25 - 1 if goals > 2.5 else -1
    return row.avg_odds_under25 - 1 if goals <= 2.5 else -1


def _get_columns(engine, schema: str, table: str) -> set[str]:
    q = text("""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = :schema
          AND table_name = :table
    """)
    with engine.connect() as conn:
        rows = conn.execute(q, {"schema": schema, "table": table}).fetchall()
    return {r[0] for r in rows}


def _compute_p_over_mkt(df: pd.DataFrame) -> pd.Series:
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")

    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under

    return imp_over / overround


def roi_by_league(df: pd.DataFrame, totals: pd.Series) -> pd.DataFrame:
    if df.empty:
        return pd.DataFrame(columns=["matches_total", "bets", "coverage", "stake", "profit", "roi"])

    g = df.groupby("league_id").agg(
        bets=("profit", "count"),
        stake=("stake", "sum"),
        profit=("profit", "sum"),
    )
    g["matches_total"] = totals
    g["coverage"] = g["bets"] / g["matches_total"]
    g["roi"] = g["profit"] / g["stake"]
    return g.sort_values("roi", ascending=False)


def calc_roi(df: pd.DataFrame, matches_total: int):
    if df.empty:
        return {"matches_total": matches_total, "bets": 0, "coverage": 0.0, "stake": 0.0, "profit": 0.0, "roi": np.nan}
    stake_sum = df["stake"].sum()
    return {
        "matches_total": matches_total,
        "bets": len(df),
        "coverage": len(df) / matches_total if matches_total else 0.0,
        "stake": stake_sum,
        "profit": df["profit"].sum(),
        "roi": df["profit"].sum() / stake_sum if stake_sum > 0 else np.nan,
    }


def stake_by_tier(tier: str) -> float:
    if tier == "A":
        return 1.0
    if tier == "B":
        return 0.4
    return 0.0


# ======================
# MAIN
# ======================
def main():
    engine = create_engine(DB_URL)

    print("Loading data...")

    preds_cols = _get_columns(engine, SCHEMA, "ml_predictions")

    has_new_decision = {"bet_decision", "edge", "p_model"}.issubset(preds_cols)

    if has_new_decision:
        print("Mode: NEW (decision layer already stored)")
        q = text("""
            SELECT
                p.fixture_id,
                s.league_id,
                s.home_goals,
                s.away_goals,
                p.bet_decision,
                p.edge,
                p.p_model,
                p.stake,
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
        mode = "new"
    else:
        print("Mode: FALLBACK (reconstruct decision)")
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
        mode = "fallback"

    df = pd.read_sql(q, engine, params={"dfrom": DATE_FROM, "dto": DATE_TO})
    print(f"Loaded rows (played matches): {len(df)}")

    if df.empty:
        print("❌ No data in period")
        return
    df_all = df.copy()

    # ======================
    # FALLBACK DECISION
    # ======================
    if mode == "fallback":
        df["p_over_mkt"] = _compute_p_over_mkt(df)
        df["edge"] = df["p_over25"] - df["p_over_mkt"]
        df["p_model"] = df["p_over25"]
        df.loc[df["league_id"] == 140, "p_model"] = (
            0.9 * df.loc[df["league_id"] == 140, "p_over25"]
            + 0.1 * df.loc[df["league_id"] == 140, "p_over_mkt"]
        )

        odds_side = np.where(
            df["p_model"] > 0.5,
            df["avg_odds_over25"],
            df["avg_odds_under25"],
        )

        df["bet_decision"] = [
            decide_total_bet(edge, odds, lid, p)
            if np.isfinite(edge) and np.isfinite(odds)
            else "NO BET"
            for edge, odds, lid, p in zip(df.edge, odds_side, df.league_id, df.p_model)
        ]

    # ======================
    # FILTERS
    # ======================
    df["p_model"] = df["p_over25"]
    df.loc[df["league_id"] == 140, "p_model"] = (
        0.9 * df.loc[df["league_id"] == 140, "p_over25"]
        + 0.1 * df.loc[df["league_id"] == 140, "p_over_mkt"]
    )
    odds_side = np.where(
        df["p_model"] > 0.5,
        df["avg_odds_over25"],
        df["avg_odds_under25"],
    )
    df["bet_decision"] = [
        decide_total_bet(edge, odds, lid, p)
        for edge, odds, lid, p in zip(df["edge"], odds_side, df["league_id"], df["p_model"])
    ]

    df = df[df.bet_decision.isin(["A", "B"])].copy()
    if df.empty:
        print("❌ No bets after decision filter")
        return

    # ======================
    # CALCULATIONS
    # ======================
    df["profit_raw"] = df.apply(profit_total, axis=1)
    df["stake"] = df["bet_decision"].apply(stake_by_tier)
    df["profit"] = df["profit_raw"] * df["stake"]

    # ======================
    # OUTPUT
    # ======================
    totals_by_league = df_all.groupby("league_id")["fixture_id"].count()

    print("\n=== OVERALL ===")
    print(calc_roi(df, len(df_all)))

    print("\n=== BY LEAGUE ===")
    print(roi_by_league(df, totals_by_league))

    print("\n=== BY TIER ===")
    g_tier = df.groupby("bet_decision").agg(
        bets=("profit", "count"),
        stake=("stake", "sum"),
        profit=("profit", "sum"),
    )
    g_tier["roi"] = g_tier["profit"] / g_tier["stake"]
    print(g_tier)

    print("\n=== EDGE BINS (diagnostic) ===")
    df["edge_bin"] = pd.cut(
        df["edge"],
        bins=[0.08, 0.10, 0.15, 1],
        labels=["8–10%", "10–15%", "15%+"],
        include_lowest=True,
    )
    g_bins = df.groupby("edge_bin").agg(
        bets=("profit", "count"),
        stake=("stake", "sum"),
        profit=("profit", "sum"),
    )
    g_bins["roi"] = g_bins["profit"] / g_bins["stake"]
    print(g_bins)


if __name__ == "__main__":
    main()
