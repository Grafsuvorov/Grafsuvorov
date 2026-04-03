# tune_league_rules.py

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL
from decision.league_rules import LEAGUE_RULES, DEFAULT_RULE

TRAIN_FROM = "2025-08-01"
TRAIN_TO = "2025-12-15"

EDGE_GRID = [0.01, 0.015, 0.02, 0.025, 0.03, 0.035, 0.04, 0.045, 0.05]
TARGET_COVERAGE = 0.20
MIN_BETS = 30


def _compute_p_market(df: pd.DataFrame) -> pd.Series:
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")

    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    return imp_over / overround


def _profit(row) -> float:
    goals = row.home_goals + row.away_goals
    if row.p_over25 >= 0.5:
        return row.avg_odds_over25 - 1 if goals > 2.5 else -1
    return row.avg_odds_under25 - 1 if goals <= 2.5 else -1


def main():
    engine = create_engine(DB_URL)

    q = text(
        """
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
        """
    )

    df = pd.read_sql(q, engine, params={"dfrom": TRAIN_FROM, "dto": TRAIN_TO})
    if df.empty:
        print("No data in TRAIN period")
        return

    df["p_market"] = _compute_p_market(df)
    df["edge"] = df["p_over25"] - df["p_market"]
    df["odds_side"] = np.where(
        df["p_over25"] >= 0.5,
        df["avg_odds_over25"],
        df["avg_odds_under25"],
    )

    missing_odds = df["odds_side"].isna().sum()
    if missing_odds:
        print(f"[WARN] Missing odds_side for {missing_odds} rows")
    df = df[df["odds_side"].notna()].copy()

    results = []
    generated = {}

    for lid, g in df.groupby("league_id"):
        rule = LEAGUE_RULES.get(int(lid), DEFAULT_RULE)
        odds_min = rule["odds_min"]
        odds_max = rule["odds_max"]
        best = None

        for edge_min in EDGE_GRID:
            mask = (
                (g["edge"] >= edge_min)
                & (g["odds_side"] >= odds_min)
                & (g["odds_side"] <= odds_max)
            )
            bets = g[mask].copy()
            bets_count = len(bets)
            if bets_count < MIN_BETS:
                continue

            coverage = bets_count / len(g)
            bets["profit"] = bets.apply(_profit, axis=1)
            roi = bets["profit"].sum() / bets_count if bets_count else np.nan

            score = (abs(coverage - TARGET_COVERAGE), -roi)
            if best is None or score < best[0]:
                best = (score, edge_min, coverage, bets_count, roi)

        if best is None:
            edge_min = DEFAULT_RULE["edge_min"]
            coverage = 0.0
            bets_count = 0
            roi = np.nan
        else:
            _, edge_min, coverage, bets_count, roi = best

        generated[int(lid)] = {
            "edge_min": float(edge_min),
            "odds_min": float(odds_min),
            "odds_max": float(odds_max),
        }
        results.append(
            {
                "league_id": int(lid),
                "edge_min": float(edge_min),
                "coverage_train": float(coverage),
                "bets_train": int(bets_count),
                "roi_train": float(roi) if np.isfinite(roi) else np.nan,
            }
        )

    res_df = pd.DataFrame(results).sort_values("league_id")
    print("\n=== TRAIN RULES (tuned) ===")
    print(res_df)

    out_path = "decision/league_rules_generated.py"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("LEAGUE_RULES = ")
        f.write(repr(generated))
        f.write("\n\n")
        f.write("DEFAULT_RULE = ")
        f.write(repr(DEFAULT_RULE))
        f.write("\n")

    print(f"\nSaved generated rules -> {out_path}")


if __name__ == "__main__":
    main()
