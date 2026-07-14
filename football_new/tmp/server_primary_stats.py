import json

import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL


def settle(bt: str, bo: str, odds: float, hg: int, ag: int) -> tuple[float, bool]:
    hg = int(hg)
    ag = int(ag)
    odds = float(odds)
    if bt == "1X2":
        won = (bo == "Home" and hg > ag) or (bo == "Draw" and hg == ag) or (bo == "Away" and ag > hg)
    else:
        tg = hg + ag
        won = (bo == "Over2.5" and tg > 2.5) or (bo == "Under2.5" and tg < 2.5)
    return (odds - 1.0) if won else -1.0, won


def main() -> None:
    engine = create_engine(DB_URL)
    q = text(
        """
        SELECT
            s.fixture_id,
            s.league_name AS league,
            s.date::date AS match_date,
            s.home_goals,
            s.away_goals,
            p.best_bet_type,
            p.best_bet_outcome,
            p.best_bet_odds
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s ON s.fixture_id = p.fixture_id
        WHERE s.date BETWEEN '2025-07-01' AND '2026-06-30'
          AND s.home_goals IS NOT NULL
          AND s.away_goals IS NOT NULL
          AND p.best_bet_type IS NOT NULL
          AND p.best_bet_type <> 'NONE'
        ORDER BY s.date, s.fixture_id
        """
    )
    df = pd.read_sql(q, engine)
    if df.empty:
        print(json.dumps({"overall": {}, "by_market": {}, "by_outcome_1x2": {}, "by_total_side": {}}, ensure_ascii=False))
        return

    df[["profit", "won"]] = df.apply(
        lambda r: pd.Series(settle(r.best_bet_type, r.best_bet_outcome, r.best_bet_odds, r.home_goals, r.away_goals)),
        axis=1,
    )

    overall = {
        "bets": int(len(df)),
        "wins": int(df["won"].sum()),
        "losses": int((~df["won"]).sum()),
        "hit_rate": float(df["won"].mean()),
        "avg_odds": float(df["best_bet_odds"].mean()),
        "profit": float(df["profit"].sum()),
        "roi": float(df["profit"].sum() / len(df)),
    }
    by_market = (
        df.groupby("best_bet_type")
        .agg(bets=("fixture_id", "count"), wins=("won", "sum"), avg_odds=("best_bet_odds", "mean"), profit=("profit", "sum"))
        .assign(roi=lambda x: x["profit"] / x["bets"])
        .to_dict("index")
    )
    by_outcome = (
        df[df["best_bet_type"] == "1X2"]
        .groupby("best_bet_outcome")
        .agg(bets=("fixture_id", "count"), wins=("won", "sum"), avg_odds=("best_bet_odds", "mean"), profit=("profit", "sum"))
        .assign(roi=lambda x: x["profit"] / x["bets"])
        .to_dict("index")
    )
    by_total = (
        df[df["best_bet_type"] == "TOTAL"]
        .groupby("best_bet_outcome")
        .agg(bets=("fixture_id", "count"), wins=("won", "sum"), avg_odds=("best_bet_odds", "mean"), profit=("profit", "sum"))
        .assign(roi=lambda x: x["profit"] / x["bets"])
        .to_dict("index")
    )
    print(json.dumps({"overall": overall, "by_market": by_market, "by_outcome_1x2": by_outcome, "by_total_side": by_total}, ensure_ascii=False))


if __name__ == "__main__":
    main()
