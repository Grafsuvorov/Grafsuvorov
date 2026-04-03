import argparse
from itertools import product

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL


def _parse_args():
    p = argparse.ArgumentParser(description="Research profitable draw-only rule zones")
    p.add_argument("--season", type=int, default=2025)
    p.add_argument("--min-bets", type=int, default=12)
    p.add_argument("--topk", type=int, default=5)
    return p.parse_args()


def _profit_draw(row) -> float:
    return (row.avg_odds_draw - 1.0) if row.home_goals == row.away_goals else -1.0


def _load_df(season: int) -> pd.DataFrame:
    engine = create_engine(DB_URL)
    q = text(
        """
        SELECT
            p.fixture_id,
            s.league_id,
            s.league_name,
            s.date::date AS match_date,
            s.home_team,
            s.away_team,
            s.home_goals,
            s.away_goals,
            p.p_home,
            p.p_draw,
            p.p_away,
            m.avg_odds_draw
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s
          ON s.fixture_id = p.fixture_id
        LEFT JOIN football.v_ml_epl_training m
          ON m.fixture_id = p.fixture_id
        WHERE s.season = :season
          AND s.home_goals IS NOT NULL
          AND s.away_goals IS NOT NULL
          AND p.p_draw IS NOT NULL
          AND m.avg_odds_draw IS NOT NULL
        ORDER BY s.date ASC
        """
    )
    df = pd.read_sql(q, engine, params={"season": int(season)})
    if df.empty:
        return df

    for col in ["p_home", "p_draw", "p_away", "avg_odds_draw"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df = df[(df["avg_odds_draw"] > 1.01) & np.isfinite(df["p_draw"])].copy()
    probs = df[["p_home", "p_draw", "p_away"]].astype(float).to_numpy()
    top2 = np.sort(probs, axis=1)[:, -2:]
    df["gap_top2"] = top2[:, 1] - top2[:, 0]
    df["ha_gap"] = (df["p_home"] - df["p_away"]).abs()
    df["ev_draw"] = df["p_draw"] * df["avg_odds_draw"] - 1.0
    df["profit_1u"] = df.apply(_profit_draw, axis=1)
    df["is_draw"] = (df["home_goals"] == df["away_goals"]).astype(int)
    return df


def _scan(df: pd.DataFrame, min_bets: int) -> pd.DataFrame:
    rows = []
    ev_grid = [0.00, 0.02, 0.04, 0.06, 0.08, 0.10, 0.12, 0.15]
    odds_min_grid = [2.40, 2.60, 2.80, 3.00, 3.20]
    odds_max_grid = [3.60, 4.00, 4.50, 5.00, 6.00]
    gap_grid = [0.02, 0.04, 0.06, 0.08, 0.12, 0.20]
    ha_gap_grid = [0.02, 0.04, 0.06, 0.10, 0.20]

    for lid, part in df.groupby("league_id"):
        lname = part["league_name"].iloc[0]
        for ev_min, odds_min, odds_max, gap_max, ha_gap_max in product(
            ev_grid, odds_min_grid, odds_max_grid, gap_grid, ha_gap_grid
        ):
            if odds_min > odds_max:
                continue
            sel = part[
                (part["ev_draw"] >= ev_min)
                & (part["avg_odds_draw"] >= odds_min)
                & (part["avg_odds_draw"] <= odds_max)
                & (part["gap_top2"] <= gap_max)
                & (part["ha_gap"] <= ha_gap_max)
            ].copy()
            if len(sel) < min_bets:
                continue
            roi = sel["profit_1u"].mean()
            rows.append(
                {
                    "league_id": int(lid),
                    "league_name": lname,
                    "ev_min": float(ev_min),
                    "odds_min": float(odds_min),
                    "odds_max": float(odds_max),
                    "gap_top2_max": float(gap_max),
                    "ha_gap_max": float(ha_gap_max),
                    "bets": int(len(sel)),
                    "draw_rate": float(sel["is_draw"].mean()),
                    "avg_p_draw": float(sel["p_draw"].mean()),
                    "avg_odds_draw": float(sel["avg_odds_draw"].mean()),
                    "profit": float(sel["profit_1u"].sum()),
                    "roi": float(roi),
                }
            )
    return pd.DataFrame(rows)


def main():
    args = _parse_args()
    df = _load_df(args.season)
    if df.empty:
        print("No rows")
        return

    print(f"rows={len(df)} season={args.season}")
    print("\n=== Always Draw By League ===")
    by_league = df.groupby(["league_id", "league_name"]).agg(
        matches=("fixture_id", "count"),
        draw_rate=("is_draw", "mean"),
        avg_p_draw=("p_draw", "mean"),
        avg_odds_draw=("avg_odds_draw", "mean"),
        roi=("profit_1u", "mean"),
    ).reset_index()
    print(by_league.to_string(index=False))

    res = _scan(df, min_bets=args.min_bets)
    if res.empty:
        print("\nNo stable draw zones found")
        return

    print("\n=== Top Draw Zones By League ===")
    for lid, part in res.groupby("league_id"):
        print(f"\n{part['league_name'].iloc[0]} ({int(lid)})")
        print(part.sort_values(["roi", "bets"], ascending=[False, False]).head(args.topk).to_string(index=False))


if __name__ == "__main__":
    main()
