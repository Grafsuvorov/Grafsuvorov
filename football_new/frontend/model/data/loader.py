# data/loader.py
import pandas as pd
from sqlalchemy import create_engine, text
from config import DB_URL, LEAGUES

engine = create_engine(DB_URL)

def load_schedule():
    q = """
        SELECT fixture_id, date::timestamp AS date_utc,
               season, league_id, home_team_id, away_team_id,
               home_goals, away_goals
        FROM football.api_football_schedule
        WHERE league_id IN :leagues
    """
    return pd.read_sql(text(q), engine, params={"leagues": tuple(LEAGUES)})

def load_stats():
    q = """
        SELECT *
        FROM football.api_football_match_stats
    """
    return pd.read_sql(text(q), engine)

def load_injuries():
    q = """
        SELECT *
        FROM football.api_football_injuries
    """
    return pd.read_sql(text(q), engine)

def load_odds(view_primary="football.v_ml_epl_training"):
    try:
        df = pd.read_sql(f"SELECT * FROM {view_primary}", engine)
        return df
    except:
        return pd.DataFrame()
