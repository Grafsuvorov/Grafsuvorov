from sqlalchemy import create_engine, text
import os
import csv
import sys


DB_URL = os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:0506@edgescore-db:5432/dwh")
engine = create_engine(DB_URL)

q = text(
    """
    select
      s.season::text as season,
      s.league_name as league,
      p.best_bet_type,
      p.best_bet_outcome,
      p.bet_rating,
      p.best_bet_odds,
      p.best_bet_ev,
      s.home_goals,
      s.away_goals
    from football.ml_predictions p
    join football.api_football_schedule s on s.fixture_id = p.fixture_id
    where s.season = :season
      and s.home_goals is not null
      and s.away_goals is not null
      and p.best_bet_type is not null
      and p.best_bet_type <> :none_value
    """
)

with engine.connect() as conn:
    rows = conn.execute(q, {"season": 2026, "none_value": "NONE"}).fetchall()

w = csv.writer(sys.stdout)
w.writerow(
    [
        "season",
        "league",
        "best_bet_type",
        "best_bet_outcome",
        "bet_rating",
        "best_bet_odds",
        "best_bet_ev",
        "home_goals",
        "away_goals",
    ]
)
for row in rows:
    w.writerow(list(row))
