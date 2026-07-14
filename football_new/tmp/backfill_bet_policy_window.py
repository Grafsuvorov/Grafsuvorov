from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import MetaData, Table, create_engine, text
from sqlalchemy.dialects.postgresql import insert as pg_insert


ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "frontend" / "model"
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(MODEL_DIR))

from fill_match_predictions import pick_best  # noqa: E402


SCHEMA = "football"
TABLE = "ml_predictions"
MODEL_VERSION = "xgb_v6_policy_backfill"


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--date-from", required=True)
    p.add_argument("--date-to", required=True)
    return p.parse_args()


def _load_rows(engine, date_from: str, date_to: str) -> pd.DataFrame:
    q = text(
        """
        select
          p.fixture_id,
          s.league_id,
          s.league_name as league,
          s.date::date as match_date,
          p.p_home,
          p.p_draw,
          p.p_away,
          p.p_over25,
          p.avg_odds_home,
          p.avg_odds_draw,
          p.avg_odds_away,
          p.avg_odds_over25,
          p.avg_odds_under25,
          p.best_bet_type as existing_best_bet_type,
          p.best_bet_outcome as existing_best_bet_outcome,
          p.best_bet_odds as existing_best_bet_odds,
          p.best_bet_ev as existing_best_bet_ev,
          p.bet_reason as existing_bet_reason,
          p.bet_rating as existing_bet_rating
        from football.ml_predictions p
        join football.api_football_schedule s on s.fixture_id = p.fixture_id
        where s.date::date between :date_from and :date_to
        order by s.date::date, p.fixture_id
        """
    )
    with engine.connect() as conn:
        df = pd.read_sql(q, conn, params={"date_from": date_from, "date_to": date_to})
    return df


def _best_bet_prob(row: pd.Series) -> float | None:
    bet_type = row.get("best_bet_type")
    outcome = row.get("best_bet_outcome")
    if bet_type == "1X2":
        return {
            "Home": row.get("p_home"),
            "Draw": row.get("p_draw"),
            "Away": row.get("p_away"),
        }.get(outcome)
    if bet_type == "TOTAL":
        if outcome == "Over2.5":
            return row.get("p_over25")
        if outcome == "Under2.5":
            return row.get("p_under25")
    return None


def main():
    args = parse_args()
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("DATABASE_URL is required")
    engine = create_engine(db_url)
    df = _load_rows(engine, args.date_from, args.date_to)
    if df.empty:
        print({"date_from": args.date_from, "date_to": args.date_to, "fixtures": 0, "updated": 0})
        return

    num_cols = [
        "p_home",
        "p_draw",
        "p_away",
        "p_over25",
        "avg_odds_home",
        "avg_odds_draw",
        "avg_odds_away",
        "avg_odds_over25",
        "avg_odds_under25",
    ]
    for col in num_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df["p_under25"] = 1.0 - df["p_over25"]
    df["_outcome_aux_bundle"] = [None] * len(df)

    best = df.apply(pick_best, axis=1)
    df = pd.concat([df.reset_index(drop=True), best.reset_index(drop=True)], axis=1)
    df["best_bet_p"] = df.apply(_best_bet_prob, axis=1)
    df["bet_reason"] = df.apply(
        lambda r: (
            f"p={float(r.best_bet_p):.2f} | odds={float(r.best_bet_odds):.2f} | EV={float(r.best_bet_ev):.3f}"
            if pd.notna(r.best_bet_p) and pd.notna(r.best_bet_odds) and pd.notna(r.best_bet_ev)
            else "No qualified edge under current policy"
        ),
        axis=1,
    )
    df["bet_rating"] = np.where(
        df["best_bet_type"].eq("NONE") | df["best_bet_type"].isna(),
        None,
        np.where(
            df["best_bet_ev"] >= 0.10,
            "Strong",
            np.where(df["best_bet_ev"] >= 0.04, "Medium", "Weak"),
        ),
    )
    df["model_version"] = MODEL_VERSION

    meta = MetaData()
    updated = 0
    with engine.begin() as conn:
        table = Table(TABLE, meta, schema=SCHEMA, autoload_with=conn)
        cols = [
            "fixture_id",
            "best_bet_type",
            "best_bet_outcome",
            "best_bet_odds",
            "best_bet_ev",
            "bet_reason",
            "bet_rating",
            "model_version",
        ]
        for _, row in df.iterrows():
            data = {"fixture_id": int(row["fixture_id"])}
            for col in cols[1:]:
                value = row.get(col)
                if pd.isna(value):
                    value = None
                data[col] = value
            stmt = pg_insert(table).values(**data)
            stmt = stmt.on_conflict_do_update(
                index_elements=[table.c.fixture_id],
                set_={k: stmt.excluded[k] for k in data if k != "fixture_id"},
            )
            conn.execute(stmt)
            updated += 1

    print(
        {
            "date_from": args.date_from,
            "date_to": args.date_to,
            "fixtures": int(len(df)),
            "updated": int(updated),
            "best_bet_type_counts": df["best_bet_type"].fillna("NONE").value_counts().to_dict(),
            "best_bet_outcome_counts": df["best_bet_outcome"].fillna("NONE").value_counts().to_dict(),
        }
    )


if __name__ == "__main__":
    main()
