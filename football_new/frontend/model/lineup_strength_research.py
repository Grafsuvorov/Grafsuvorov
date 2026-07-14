import json
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import create_engine

from config import DB_URL, UNDERSTAT_MIN_SEASON
from data.loader import load_schedule
from features.lineup_strength import build_lineup_strength_features


def main():
    engine = create_engine(DB_URL)
    sched = load_schedule()
    sched["date_utc"] = pd.to_datetime(sched["date_utc"], utc=True, errors="coerce")

    feats = build_lineup_strength_features(
        sched,
        engine,
        min_season=UNDERSTAT_MIN_SEASON,
    )
    df = sched[["fixture_id", "date_utc", "league_id", "season"]].merge(feats, on="fixture_id", how="left")

    lineup_cols = [c for c in df.columns if c.startswith(("home_ls_", "away_ls_", "ls_"))]
    coverage = {
        "overall_rows": int(len(df)),
        "feature_count": int(len(lineup_cols)),
        "non_null_rate_overall": {
            c: float(pd.to_numeric(df[c], errors="coerce").notna().mean())
            for c in lineup_cols[:40]
        },
        "season_coverage": {},
        "league_coverage": {},
    }

    key_cols = [
        "home_ls_xi_rating_long",
        "away_ls_xi_rating_long",
        "home_ls_xi_rating_all_5",
        "away_ls_xi_rating_all_5",
        "home_ls_xi_rating_home_10",
        "away_ls_xi_rating_away_10",
        "ls_xi_rating_all_10_diff",
        "ls_matchup_venue_xi_edge_10",
    ]
    for season, g in df.groupby("season"):
        coverage["season_coverage"][str(season)] = {
            c: float(pd.to_numeric(g[c], errors="coerce").notna().mean())
            for c in key_cols
            if c in g.columns
        }
    for league_id, g in df.groupby("league_id"):
        coverage["league_coverage"][str(int(league_id))] = {
            c: float(pd.to_numeric(g[c], errors="coerce").notna().mean())
            for c in key_cols
            if c in g.columns
        }

    out = Path("tmp/lineup_strength_research.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(coverage, ensure_ascii=False, indent=2))
    print(json.dumps(coverage, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
