# api/match_stats.py
from fastapi import APIRouter, HTTPException
from sqlalchemy import create_engine, text
import pandas as pd

router = APIRouter(
    prefix="/api",
    tags=["Статистика матчей"],
    responses={404: {"description": "Not found"}}
)
engine = create_engine('postgresql+psycopg2://postgres:0506@localhost:5432/dwh')

@router.get("/match-details")
def get_match_details(home_team: str, away_team: str, date: str):
    try:
        with engine.connect() as conn:
            # Личные встречи
            h2h_query = """
            SELECT date, home_team, away_team, score, result
            FROM football.stats_match_fbref_v2
            WHERE ((home_team = :home AND away_team = :away)
                OR (home_team = :away AND away_team = :home))
                AND score IS NOT NULL
            ORDER BY date DESC LIMIT 5
            """
            h2h = pd.read_sql(text(h2h_query), conn, params={"home": home_team, "away": away_team})

            # Последние матчи команды — любые, не важно где
            def fetch_recent(team: str):
                query = """
                SELECT *
                FROM football.stats_match_fbref_v2
                WHERE (home_team = :team OR away_team = :team)
                  AND date < :match_date
                  AND score IS NOT NULL
                ORDER BY date DESC LIMIT 5
                """
                return pd.read_sql(text(query), conn, params={"team": team, "match_date": date})

            home_recent = fetch_recent(home_team)
            away_recent = fetch_recent(away_team)

            # Средняя статистика
            def compute_avg(df, prefix):
                if df.empty:
                    return {}

                df = df.copy()
                stats = {}

                def avg(field_home, field_away, key):
                    vals = []
                    for _, row in df.iterrows():
                        if row['home_team'] == prefix:
                            val = row.get(field_home)
                        else:
                            val = row.get(field_away)
                        if val is not None:
                            vals.append(val)
                    return {f"{prefix}_{key}": pd.Series(vals).mean() if vals else None}

                stat_fields = [
                    ("home_goals", "away_goals", "avg_goals_for"),
                    ("away_goals", "home_goals", "avg_goals_against"),
                    ("home_possession", "away_possession", "avg_possession"),
                    ("home_shots", "away_shots", "avg_shots"),
                    ("home_shots_on_target", "away_shots_on_target", "avg_shots_on_target"),
                    ("home_expected_xg", "away_expected_xg", "avg_xg"),
                    ("home_tackles_tkl", "away_tackles_tkl", "avg_tackles"),
                    ("home_interceptions", "away_interceptions", "avg_interceptions"),
                    ("home_clearances", "away_clearances", "avg_clearances"),
                    ("home_total_cmp", "away_total_cmp", "avg_passes_completed"),
                    ("home_total_att", "away_total_att", "avg_passes_attempted"),
                    ("home_total_cmpp", "away_total_cmpp", "avg_pass_accuracy"),
                    ("home_touches", "away_touches", "avg_touches"),
                ]

                for f_home, f_away, k in stat_fields:
                    stats.update(avg(f_home, f_away, k))

                return stats

            averages = {}
            averages.update(compute_avg(home_recent, 'home'))
            averages.update(compute_avg(away_recent, 'away'))

        return {
            "head_to_head": h2h.to_dict(orient="records"),
            "recent_matches_home": home_recent.to_dict(orient="records"),
            "recent_matches_away": away_recent.to_dict(orient="records"),
            "averages": averages
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
