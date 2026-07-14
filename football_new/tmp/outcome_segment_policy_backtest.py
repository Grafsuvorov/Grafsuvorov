from __future__ import annotations

import json
import os
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text


POLICY_PATH = Path("tmp/outcome_segment_policy_v1.json")
OUT_PATH = Path("tmp/outcome_segment_policy_backtest.json")


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


def _row_side_metrics(row: pd.Series, side: str) -> dict | None:
    side_map = {
        "Home": ("p_home", "p_home_mkt", "avg_odds_home"),
        "Draw": ("p_draw", "p_draw_mkt", "avg_odds_draw"),
        "Away": ("p_away", "p_away_mkt", "avg_odds_away"),
    }
    p_col, pm_col, o_col = side_map[side]
    p_model = pd.to_numeric(pd.Series([row.get(p_col)]), errors="coerce").iloc[0]
    p_market = pd.to_numeric(pd.Series([row.get(pm_col)]), errors="coerce").iloc[0]
    odds = pd.to_numeric(pd.Series([row.get(o_col)]), errors="coerce").iloc[0]
    if not np.isfinite(p_model) or not np.isfinite(p_market) or not np.isfinite(odds) or odds <= 1.01:
        return None

    if side == "Home":
        won = int(row["home_goals"] > row["away_goals"])
    elif side == "Draw":
        won = int(row["home_goals"] == row["away_goals"])
    else:
        won = int(row["away_goals"] > row["home_goals"])

    return {
        "fixture_id": int(row["fixture_id"]),
        "league": row["league"],
        "outcome": side,
        "odds": float(odds),
        "p_model": float(p_model),
        "p_market": float(p_market),
        "draw_risk": float(row["p_draw"]),
        "edge": float(p_model - p_market),
        "ev": float(p_model * odds - 1.0),
        "won": won,
        "profit": float(odds - 1.0) if won else -1.0,
    }


def main():
    policy = json.loads(POLICY_PATH.read_text())
    allowed = {
        (x["league"], x["outcome"], x["odds_bucket"], x["draw_risk_bin"])
        for x in policy["allowed_segments_v1"]
    }
    blocked = {
        (x["league"], x["outcome"], x["odds_bucket"], x["draw_risk_bin"])
        for x in policy["blocked_segments_v1"]
    }

    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("DATABASE_URL is required")
    engine = create_engine(db_url)
    q = text(
        """
        select
          p.fixture_id,
          s.league_id,
          case s.league_id
            when 39 then 'Premier League'
            when 61 then 'Ligue 1'
            when 78 then 'Bundesliga'
            when 135 then 'Serie A'
            when 140 then 'La Liga'
          end as league,
          s.home_goals,
          s.away_goals,
          p.p_home,
          p.p_draw,
          p.p_away,
          v.avg_odds_home,
          v.avg_odds_draw,
          v.avg_odds_away
        from football.ml_predictions p
        join football.api_football_schedule s on s.fixture_id = p.fixture_id
        join football.v_ml_epl_training v on v.fixture_id = p.fixture_id
        where s.date::date between '2025-08-01' and '2026-05-10'
          and s.home_goals is not null
          and s.away_goals is not null
        order by s.date::date, p.fixture_id
        """
    )
    with engine.connect() as conn:
        base = pd.read_sql(q, conn)

    for col in ["p_home", "p_draw", "p_away", "avg_odds_home", "avg_odds_draw", "avg_odds_away"]:
        base[col] = pd.to_numeric(base[col], errors="coerce")
    base = _implied_probs(base)

    rows = []
    for _, row in base.iterrows():
        for side in ("Home", "Away"):
            rec = _row_side_metrics(row, side)
            if rec is not None:
                rows.append(rec)
    df = pd.DataFrame(rows)
    df["odds_bucket"] = pd.cut(
        df["odds"],
        bins=[0.0, 1.55, 1.70, 2.00, 2.40, 3.20, 4.00, 10.0],
        labels=["<1.55", "1.55-1.70", "1.70-2.00", "2.00-2.40", "2.40-3.20", "3.20-4.00", "4.00+"],
        include_lowest=True,
    ).astype(str)
    df["draw_risk_bin"] = pd.cut(
        df["draw_risk"],
        bins=[0.0, 0.22, 0.26, 0.30, 0.34, 1.0],
        labels=["<=0.22", "0.22-0.26", "0.26-0.30", "0.30-0.34", "0.34+"],
        include_lowest=True,
    ).astype(str)

    def key(row):
        return (row["league"], row["outcome"], row["odds_bucket"], row["draw_risk_bin"])

    df["segment_key"] = df.apply(key, axis=1)

    allowed_df = df[df["segment_key"].isin(allowed)].copy()
    allowed_df = allowed_df[~allowed_df["segment_key"].isin(blocked)].copy()

    report = {
        "bets": int(len(allowed_df)),
        "wins": int(allowed_df["won"].sum()) if len(allowed_df) else 0,
        "profit": float(allowed_df["profit"].sum()) if len(allowed_df) else 0.0,
        "roi": float(allowed_df["profit"].mean()) if len(allowed_df) else None,
        "hit_rate": float(allowed_df["won"].mean()) if len(allowed_df) else None,
        "by_league": (
            allowed_df.groupby("league")
            .agg(bets=("fixture_id", "size"), wins=("won", "sum"), profit=("profit", "sum"))
            .assign(
                roi=lambda x: x["profit"] / x["bets"],
                hit_rate=lambda x: x["wins"] / x["bets"],
            )
            .reset_index()
            .to_dict(orient="records")
            if len(allowed_df)
            else []
        ),
    }

    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
