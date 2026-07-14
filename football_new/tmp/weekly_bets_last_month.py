from __future__ import annotations

import os
from dataclasses import dataclass

import pandas as pd
from sqlalchemy import create_engine, text


DB_URL = os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:0506@edgescore-db:5432/dwh")
DATE_FROM = "2026-04-10"
DATE_TO = "2026-05-10"
OUT_PATH = "tmp/weekly_bets_2026-04-10_to_2026-05-10.txt"


@dataclass
class BetResult:
    won: bool
    profit: float
    stake: float


def settle_bet(bet_type: str, outcome: str, odds: float, home_goals: int, away_goals: int) -> BetResult:
    total_goals = int(home_goals) + int(away_goals)
    stake = 1.0

    if bet_type == "1X2":
        won = (
            (outcome == "Home" and home_goals > away_goals)
            or (outcome == "Draw" and home_goals == away_goals)
            or (outcome == "Away" and away_goals > home_goals)
        )
    elif bet_type == "TOTAL":
        won = (
            (outcome == "Over2.5" and total_goals > 2.5)
            or (outcome == "Under2.5" and total_goals < 2.5)
        )
    else:
        return BetResult(False, 0.0, 0.0)

    profit = float(odds - 1.0) if won else -1.0
    return BetResult(won, profit, stake)


def main() -> None:
    engine = create_engine(DB_URL)
    q = text(
        """
        select
          s.date::date as match_date,
          date_trunc('week', s.date)::date as week_start,
          s.league_name as league,
          p.best_bet_type,
          p.best_bet_outcome,
          p.best_bet_odds,
          s.home_goals,
          s.away_goals
        from football.ml_predictions p
        join football.api_football_schedule s on s.fixture_id = p.fixture_id
        where s.date::date between :date_from and :date_to
          and s.home_goals is not null
          and s.away_goals is not null
          and p.best_bet_type is not null
          and p.best_bet_type <> 'NONE'
        order by s.date::date, s.league_name, p.best_bet_type
        """
    )

    with engine.connect() as conn:
        df = pd.read_sql(q, conn, params={"date_from": DATE_FROM, "date_to": DATE_TO})

    if df.empty:
        report = (
            f"WINDOW\n{DATE_FROM} -> {DATE_TO}\n\n"
            "No settled bets in this window.\n"
        )
        with open(OUT_PATH, "w", encoding="utf-8") as fh:
            fh.write(report)
        print(report)
        return

    settled = df.apply(
        lambda row: settle_bet(
            row["best_bet_type"],
            row["best_bet_outcome"],
            float(row["best_bet_odds"]),
            int(row["home_goals"]),
            int(row["away_goals"]),
        ),
        axis=1,
    )

    df["wins"] = [1 if x.won else 0 for x in settled]
    df["losses"] = [0 if x.won else 1 for x in settled]
    df["stake"] = [x.stake for x in settled]
    df["profit"] = [x.profit for x in settled]

    def summarize(frame: pd.DataFrame, by: list[str]) -> pd.DataFrame:
        out = (
            frame.groupby(by, dropna=False)
            .agg(
                bets=("best_bet_type", "size"),
                wins=("wins", "sum"),
                losses=("losses", "sum"),
                stake=("stake", "sum"),
                profit=("profit", "sum"),
            )
            .reset_index()
        )
        out["hit_rate"] = (out["wins"] / out["bets"]).round(4)
        out["roi"] = (out["profit"] / out["stake"]).round(4)
        return out

    weekly_by_league_type = summarize(df, ["week_start", "league", "best_bet_type"])
    weekly_totals = summarize(df, ["week_start"])
    overall_by_league_type = summarize(df, ["league", "best_bet_type"])

    parts = [
        "WINDOW",
        f"{DATE_FROM} -> {DATE_TO}",
        "",
        "WEEKLY_BY_LEAGUE_TYPE",
        weekly_by_league_type.to_string(index=False),
        "",
        "WEEKLY_TOTALS",
        weekly_totals.to_string(index=False),
        "",
        "OVERALL_BY_LEAGUE_TYPE",
        overall_by_league_type.to_string(index=False),
        "",
    ]
    report = "\n".join(parts)

    with open(OUT_PATH, "w", encoding="utf-8") as fh:
        fh.write(report)

    print(report)


if __name__ == "__main__":
    main()
