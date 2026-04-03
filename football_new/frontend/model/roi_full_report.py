import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL
from decision.totals_decision import decide_total_bet
from decision.outcomes_decision import decide_outcome_bet

DATE_FROM = "2025-08-01"
DATE_TO = "2026-01-30"

LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}


def _totals_profit(row) -> float:
    goals = row.home_goals + row.away_goals
    if row.p_model >= 0.5:
        return row.avg_odds_over25 - 1 if goals > 2.5 else -1
    return row.avg_odds_under25 - 1 if goals <= 2.5 else -1


def _outcome_profit(row) -> float:
    if row.outcome == "Home":
        won = row.home_goals > row.away_goals
    elif row.outcome == "Draw":
        won = row.home_goals == row.away_goals
    else:
        won = row.home_goals < row.away_goals
    return row.odds - 1.0 if won else -1.0


def _summary_by_league(matches_df: pd.DataFrame, bets_df: pd.DataFrame) -> pd.DataFrame:
    total = matches_df.groupby("league_id").agg(matches=("fixture_id", "count"))
    bets = bets_df.groupby("league_id").agg(
        bets=("fixture_id", "count"),
        stake=("stake", "sum"),
        profit=("profit", "sum"),
    )
    rep = total.join(bets, how="left").fillna({"bets": 0, "stake": 0.0, "profit": 0.0})
    rep["coverage"] = rep["bets"] / rep["matches"]
    rep["roi"] = np.where(rep["stake"] > 0, rep["profit"] / rep["stake"], np.nan)
    rep = rep.reset_index()
    rep["league"] = rep["league_id"].map(LEAGUE_NAMES).fillna(rep["league_id"].astype(str))
    return rep[["league_id", "league", "matches", "bets", "coverage", "profit", "roi"]].sort_values("league_id")


def main():
    engine = create_engine(DB_URL)
    q = text(
        """
        SELECT
            p.fixture_id,
            s.league_id,
            s.home_goals,
            s.away_goals,
            p.p_home,
            p.p_draw,
            p.p_away,
            p.p_over25,
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
        """
    )
    df = pd.read_sql(q, engine, params={"dfrom": DATE_FROM, "dto": DATE_TO})
    if df.empty:
        print("No data in selected period")
        return

    # ---------- Totals ----------
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")
    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    p_market = imp_over / (imp_over + imp_under)

    df_t = df.copy()
    df_t["p_model"] = df_t["p_over25"]
    df_t.loc[df_t["league_id"] == 140, "p_model"] = (
        0.9 * df_t.loc[df_t["league_id"] == 140, "p_over25"]
        + 0.1 * p_market[df_t["league_id"] == 140]
    )
    df_t["edge"] = df_t["p_model"] - p_market
    df_t["odds_side"] = np.where(df_t["p_model"] >= 0.5, df_t["avg_odds_over25"], df_t["avg_odds_under25"])
    df_t = df_t[df_t["odds_side"].notna()].copy()
    df_t["decision"] = [
        decide_total_bet(edge, odds, int(lid), p_model)
        for edge, odds, lid, p_model in zip(df_t["edge"], df_t["odds_side"], df_t["league_id"], df_t["p_model"])
    ]
    bets_t = df_t[df_t["decision"].isin(["A", "B"])].copy()
    bets_t["stake"] = np.where(bets_t["decision"] == "A", 1.0, 0.4)
    bets_t["profit"] = bets_t.apply(_totals_profit, axis=1) * bets_t["stake"]
    rep_t = _summary_by_league(df_t, bets_t)

    # ---------- Outcomes ----------
    df_o = df.copy()
    for col in ["p_home", "p_draw", "p_away", "avg_odds_home", "avg_odds_draw", "avg_odds_away"]:
        df_o[col] = pd.to_numeric(df_o[col], errors="coerce")

    options = []
    for outcome, p_col, o_col in [
        ("Home", "p_home", "avg_odds_home"),
        ("Draw", "p_draw", "avg_odds_draw"),
        ("Away", "p_away", "avg_odds_away"),
    ]:
        x = df_o[["fixture_id", "league_id", "home_goals", "away_goals", p_col, o_col]].copy()
        x.columns = ["fixture_id", "league_id", "home_goals", "away_goals", "p", "odds"]
        x["outcome"] = outcome
        x["ev"] = x["p"] * x["odds"] - 1.0
        options.append(x)
    all_opts = pd.concat(options, ignore_index=True).dropna(subset=["p", "odds", "ev"])
    picks = all_opts.loc[all_opts.groupby("fixture_id")["ev"].idxmax()].copy()
    picks["decision"] = [
        decide_outcome_bet(ev, odds, int(lid), outcome)
        for ev, odds, lid, outcome in zip(picks["ev"], picks["odds"], picks["league_id"], picks["outcome"])
    ]
    bets_o = picks[picks["decision"].isin(["A", "B"])].copy()
    bets_o["stake"] = np.where(bets_o["decision"] == "A", 1.0, 0.4)
    bets_o["profit"] = bets_o.apply(_outcome_profit, axis=1) * bets_o["stake"]
    rep_o = _summary_by_league(picks, bets_o)

    # ---------- Print ----------
    print(f"\nPeriod: {DATE_FROM} .. {DATE_TO}")

    print("\n=== TOTALS BY LEAGUE ===")
    print(rep_t.to_string(index=False))
    total_profit_t = float(bets_t["profit"].sum())
    total_stake_t = float(bets_t["stake"].sum())
    print(
        "TOTALS OVERALL:",
        {
            "matches": int(len(df_t)),
            "bets": int(len(bets_t)),
            "coverage": float(len(bets_t) / len(df_t)) if len(df_t) else 0.0,
            "profit": round(total_profit_t, 4),
            "roi": round(total_profit_t / total_stake_t, 4) if total_stake_t else None,
        },
    )

    print("\n=== 1X2 BY LEAGUE ===")
    print(rep_o.to_string(index=False))
    total_profit_o = float(bets_o["profit"].sum())
    total_stake_o = float(bets_o["stake"].sum())
    print(
        "1X2 OVERALL:",
        {
            "matches": int(len(picks)),
            "bets": int(len(bets_o)),
            "coverage": float(len(bets_o) / len(picks)) if len(picks) else 0.0,
            "profit": round(total_profit_o, 4),
            "roi": round(total_profit_o / total_stake_o, 4) if total_stake_o else None,
        },
    )


if __name__ == "__main__":
    main()
