import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL
from decision.outcomes_decision import decide_outcome_bet

TEST_FROM = "2025-08-01"
TEST_TO = "2026-01-30"

LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}


def _result_profit(row) -> float:
    if row.outcome == "Home":
        won = row.home_goals > row.away_goals
    elif row.outcome == "Draw":
        won = row.home_goals == row.away_goals
    else:
        won = row.home_goals < row.away_goals
    return row.odds - 1.0 if won else -1.0


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
            m.avg_odds_home,
            m.avg_odds_draw,
            m.avg_odds_away
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

    for col in [
        "p_home",
        "p_draw",
        "p_away",
        "avg_odds_home",
        "avg_odds_draw",
        "avg_odds_away",
    ]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    options = []
    for outcome, p_col, o_col in [
        ("Home", "p_home", "avg_odds_home"),
        ("Draw", "p_draw", "avg_odds_draw"),
        ("Away", "p_away", "avg_odds_away"),
    ]:
        x = df[["fixture_id", "league_id", "home_goals", "away_goals", p_col, o_col]].copy()
        x.columns = ["fixture_id", "league_id", "home_goals", "away_goals", "p", "odds"]
        x["outcome"] = outcome
        x["ev"] = x["p"] * x["odds"] - 1.0
        options.append(x)

    all_opts = pd.concat(options, ignore_index=True)
    all_opts = all_opts.dropna(subset=["p", "odds", "ev"])

    best_idx = all_opts.groupby("fixture_id")["ev"].idxmax()
    picks = all_opts.loc[best_idx].copy()

    picks["bet_decision"] = [
        decide_outcome_bet(ev, odds, int(lid), outcome)
        for ev, odds, lid, outcome in zip(
            picks["ev"], picks["odds"], picks["league_id"], picks["outcome"]
        )
    ]

    bets = picks[picks["bet_decision"].isin(["A", "B"])].copy()
    bets["stake"] = np.where(bets["bet_decision"] == "A", 1.0, 0.4)
    bets["profit_raw"] = bets.apply(_result_profit, axis=1)
    bets["profit"] = bets["profit_raw"] * bets["stake"]

    matches_total = len(picks)
    bets_total = len(bets)
    coverage = bets_total / matches_total if matches_total else 0.0
    overall_roi = bets["profit"].sum() / bets["stake"].sum() if bets_total else np.nan

    by_league = bets.groupby("league_id").agg(
        bets=("fixture_id", "count"),
        stake=("stake", "sum"),
        profit=("profit", "sum"),
    )
    total_by_league = picks.groupby("league_id").agg(
        matches_total=("fixture_id", "count"),
    )
    by_league = by_league.join(total_by_league)
    by_league["coverage"] = by_league["bets"] / by_league["matches_total"]
    by_league["roi"] = by_league["profit"] / by_league["stake"]
    by_league = by_league.reset_index()
    by_league["league"] = by_league["league_id"].map(LEAGUE_NAMES).fillna(by_league["league_id"].astype(str))
    by_league = by_league.set_index("league").drop(columns=["league_id"])

    by_tier = bets.groupby("bet_decision").agg(
        bets=("fixture_id", "count"),
        stake=("stake", "sum"),
        profit=("profit", "sum"),
    )
    by_tier["roi"] = by_tier["profit"] / by_tier["stake"]

    print("\n=== OVERALL (OUTCOMES TEST) ===")
    print(
        {
            "matches": matches_total,
            "bets": bets_total,
            "coverage": coverage,
            "profit": bets["profit"].sum(),
            "roi": overall_roi,
        }
    )

    print("\n=== ROI BY LEAGUE (OUTCOMES TEST) ===")
    print(by_league.sort_values("roi", ascending=False))

    print("\n=== ROI BY TIER (OUTCOMES TEST) ===")
    print(by_tier.sort_values("roi", ascending=False))


if __name__ == "__main__":
    main()
