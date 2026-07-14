from __future__ import annotations

import json
import os
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text


POLICY_PATH = Path("tmp/outcome_segment_policy_v1.json")
OUT_PATH = Path("tmp/combined_contour_v1_backtest.json")


def settle_total(outcome: str, odds: float, home_goals: int, away_goals: int) -> tuple[int, float]:
    total_goals = int(home_goals) + int(away_goals)
    won = int((outcome == "Over2.5" and total_goals > 2.5) or (outcome == "Under2.5" and total_goals < 2.5))
    return won, (float(odds - 1.0) if won else -1.0)


def settle_1x2(outcome: str, odds: float, home_goals: int, away_goals: int) -> tuple[int, float]:
    won = int(
        (outcome == "Home" and home_goals > away_goals)
        or (outcome == "Draw" and home_goals == away_goals)
        or (outcome == "Away" and away_goals > home_goals)
    )
    return won, (float(odds - 1.0) if won else -1.0)


def _implied_probs(df: pd.DataFrame) -> pd.DataFrame:
    home = pd.to_numeric(df["avg_odds_home"], errors="coerce")
    draw = pd.to_numeric(df["avg_odds_draw"], errors="coerce")
    away = pd.to_numeric(df["avg_odds_away"], errors="coerce")
    imp_home = 1.0 / home.replace(0, np.nan)
    imp_draw = 1.0 / draw.replace(0, np.nan)
    imp_away = 1.0 / away.replace(0, np.nan)
    overround = imp_home + imp_draw + imp_away
    df["p_home_mkt"] = imp_home / overround
    df["p_draw_mkt"] = imp_draw / overround
    df["p_away_mkt"] = imp_away / overround
    return df


def main():
    policy = json.loads(POLICY_PATH.read_text())
    allowed = {
        (x["league"], x["outcome"], x["odds_bucket"], x["draw_risk_bin"])
        for x in policy["allowed_segments_v1"]
    }

    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("DATABASE_URL is required")
    engine = create_engine(db_url)
    q = text(
        """
        select
          s.fixture_id,
          s.date::date as match_date,
          date_trunc('week', s.date)::date as week_start,
          s.league_name as league,
          s.home_goals,
          s.away_goals,
          p.p_home,
          p.p_draw,
          p.p_away,
          p.best_bet_type,
          p.best_bet_outcome,
          p.best_bet_odds,
          p.best_bet_ev,
          v.avg_odds_home,
          v.avg_odds_draw,
          v.avg_odds_away
        from football.ml_predictions p
        join football.api_football_schedule s on s.fixture_id = p.fixture_id
        join football.v_ml_epl_training v on v.fixture_id = p.fixture_id
        where s.date::date between '2025-08-01' and '2026-05-10'
          and s.home_goals is not null
          and s.away_goals is not null
        order by s.date::date, s.fixture_id
        """
    )
    with engine.connect() as conn:
        base = pd.read_sql(q, conn)

    for col in ["p_home", "p_draw", "p_away", "best_bet_odds", "best_bet_ev", "avg_odds_home", "avg_odds_draw", "avg_odds_away"]:
        base[col] = pd.to_numeric(base[col], errors="coerce")
    base = _implied_probs(base)

    picks = []
    for _, row in base.iterrows():
        candidates = []

        if row["best_bet_type"] == "TOTAL" and pd.notna(row["best_bet_outcome"]) and pd.notna(row["best_bet_odds"]):
            won, profit = settle_total(str(row["best_bet_outcome"]), float(row["best_bet_odds"]), int(row["home_goals"]), int(row["away_goals"]))
            candidates.append(
                {
                    "fixture_id": int(row["fixture_id"]),
                    "match_date": str(row["match_date"]),
                    "week_start": str(row["week_start"]),
                    "league": row["league"],
                    "market": "TOTAL",
                    "outcome": str(row["best_bet_outcome"]),
                    "odds": float(row["best_bet_odds"]),
                    "ev": float(row["best_bet_ev"]) if pd.notna(row["best_bet_ev"]) else None,
                    "won": won,
                    "profit": profit,
                }
            )

        draw_risk = float(row["p_draw"]) if pd.notna(row["p_draw"]) else np.nan
        draw_risk_bin = pd.cut(
            pd.Series([draw_risk]),
            bins=[0.0, 0.22, 0.26, 0.30, 0.34, 1.0],
            labels=["<=0.22", "0.22-0.26", "0.26-0.30", "0.30-0.34", "0.34+"],
            include_lowest=True,
        ).astype(str).iloc[0]

        for outcome, p_model, p_market, odds in [
            ("Home", row["p_home"], row["p_home_mkt"], row["avg_odds_home"]),
            ("Away", row["p_away"], row["p_away_mkt"], row["avg_odds_away"]),
        ]:
            if pd.isna(p_model) or pd.isna(p_market) or pd.isna(odds) or float(odds) <= 1.01:
                continue
            odds_bucket = pd.cut(
                pd.Series([float(odds)]),
                bins=[0.0, 1.55, 1.70, 2.00, 2.40, 3.20, 4.00, 10.0],
                labels=["<1.55", "1.55-1.70", "1.70-2.00", "2.00-2.40", "2.40-3.20", "3.20-4.00", "4.00+"],
                include_lowest=True,
            ).astype(str).iloc[0]
            key = (row["league"], outcome, odds_bucket, draw_risk_bin)
            if key not in allowed:
                continue
            ev = float(p_model * odds - 1.0)
            won, profit = settle_1x2(outcome, float(odds), int(row["home_goals"]), int(row["away_goals"]))
            candidates.append(
                {
                    "fixture_id": int(row["fixture_id"]),
                    "match_date": str(row["match_date"]),
                    "week_start": str(row["week_start"]),
                    "league": row["league"],
                    "market": "1X2",
                    "outcome": outcome,
                    "odds": float(odds),
                    "ev": ev,
                    "won": won,
                    "profit": profit,
                }
            )

        if candidates:
            best = max(candidates, key=lambda x: (-999 if x["ev"] is None else x["ev"]))
            picks.append(best)

    picks_df = pd.DataFrame(picks)
    overall = {
        "bets": int(len(picks_df)),
        "wins": int(picks_df["won"].sum()) if len(picks_df) else 0,
        "profit": float(picks_df["profit"].sum()) if len(picks_df) else 0.0,
        "roi": float(picks_df["profit"].mean()) if len(picks_df) else None,
        "hit_rate": float(picks_df["won"].mean()) if len(picks_df) else None,
    }

    by_market = (
        picks_df.groupby("market")
        .agg(bets=("fixture_id", "size"), wins=("won", "sum"), profit=("profit", "sum"))
        .assign(roi=lambda x: x["profit"] / x["bets"], hit_rate=lambda x: x["wins"] / x["bets"])
        .reset_index()
        .to_dict(orient="records")
        if len(picks_df)
        else []
    )

    report = {"overall": overall, "by_market": by_market}
    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
