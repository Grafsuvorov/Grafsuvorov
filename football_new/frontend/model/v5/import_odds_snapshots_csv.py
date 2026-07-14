from __future__ import annotations

import os
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text

from .settings import DB_URL


REQUIRED_COLS = {
    "fixture_id",
    "snapshot_time_utc",
    "avg_odds_home",
    "avg_odds_draw",
    "avg_odds_away",
}


def load_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    missing = sorted(REQUIRED_COLS - set(df.columns))
    if missing:
        raise ValueError(f"missing required columns: {missing}")

    out = df.copy()
    out["fixture_id"] = pd.to_numeric(out["fixture_id"], errors="coerce").astype("Int64")
    out["snapshot_time_utc"] = pd.to_datetime(out["snapshot_time_utc"], utc=True, errors="coerce")
    for col in [
        "bookmaker_count",
        "avg_odds_home",
        "avg_odds_draw",
        "avg_odds_away",
        "avg_odds_over25",
        "avg_odds_under25",
    ]:
        if col in out.columns:
            out[col] = pd.to_numeric(out[col], errors="coerce")
    if "source_name" not in out.columns:
        out["source_name"] = Path(path).stem
    out = out.dropna(subset=["fixture_id", "snapshot_time_utc", "avg_odds_home", "avg_odds_draw", "avg_odds_away"]).copy()
    out["fixture_id"] = out["fixture_id"].astype("int64")
    return out


def upsert(df: pd.DataFrame) -> int:
    engine = create_engine(DB_URL, pool_pre_ping=True)
    rows = df.to_dict(orient="records")
    if not rows:
        return 0

    stmt = text(
        """
        INSERT INTO football.odds_snapshots_v1 (
            fixture_id,
            snapshot_time_utc,
            bookmaker_count,
            avg_odds_home,
            avg_odds_draw,
            avg_odds_away,
            avg_odds_over25,
            avg_odds_under25,
            source_name
        ) VALUES (
            :fixture_id,
            :snapshot_time_utc,
            :bookmaker_count,
            :avg_odds_home,
            :avg_odds_draw,
            :avg_odds_away,
            :avg_odds_over25,
            :avg_odds_under25,
            :source_name
        )
        ON CONFLICT (fixture_id, snapshot_time_utc) DO UPDATE SET
            bookmaker_count = EXCLUDED.bookmaker_count,
            avg_odds_home = EXCLUDED.avg_odds_home,
            avg_odds_draw = EXCLUDED.avg_odds_draw,
            avg_odds_away = EXCLUDED.avg_odds_away,
            avg_odds_over25 = EXCLUDED.avg_odds_over25,
            avg_odds_under25 = EXCLUDED.avg_odds_under25,
            source_name = EXCLUDED.source_name,
            ingest_time_utc = now()
        """
    )
    with engine.begin() as conn:
        conn.execute(stmt, rows)
    return len(rows)


def main() -> None:
    csv_path = os.getenv("ODDS_SNAPSHOTS_CSV")
    if not csv_path:
        raise RuntimeError("set ODDS_SNAPSHOTS_CSV=/path/to/file.csv")
    df = load_csv(csv_path)
    n = upsert(df)
    print(f"upserted {n} odds snapshots from {csv_path}")


if __name__ == "__main__":
    main()
