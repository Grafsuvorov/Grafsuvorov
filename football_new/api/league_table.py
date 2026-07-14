from fastapi import APIRouter, Query
from sqlalchemy import create_engine, text
import pandas as pd
from api.core.config import settings

router = APIRouter(
    prefix="/api",
    tags=["Турнирные таблицы"],
    responses={404: {"description": "Not found"}}
)
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)


def _restore_missing_group_third_places(df: pd.DataFrame, conn, league: str, season: str) -> pd.DataFrame:
    if df.empty or "group_name" not in df.columns:
        return df

    base_groups = df[
        df["group_name"].fillna("").str.match(r"^Group [A-Z0-9]+$", na=False)
    ].copy()
    aggregate_rows = df[df["group_name"].fillna("") == "Group Stage"].copy()

    if base_groups.empty or aggregate_rows.empty:
        return df

    group_sizes = base_groups.groupby("group_name").size()
    if group_sizes.empty or not group_sizes.eq(3).all():
        return df

    fixtures_query = text("""
        WITH target_leagues AS (
            SELECT DISTINCT s2.league_id
            FROM football.api_football_schedule s2
            WHERE s2.season = :season AND s2.league_name = :league
            UNION
            SELECT l.league_id
            FROM football.api_football_league l
            WHERE l.league_name = :league
        )
        SELECT home_team, away_team
        FROM football.api_football_schedule
        WHERE season = :season
          AND league_id IN (SELECT league_id FROM target_leagues)
          AND COALESCE(round, '') ILIKE 'Group Stage - %'
    """)
    fixtures = pd.read_sql(fixtures_query, conn, params={"league": league, "season": season})
    if fixtures.empty:
        return df

    team_opponents = {}
    for match in fixtures.to_dict(orient="records"):
        home = match.get("home_team")
        away = match.get("away_team")
        if not home or not away:
            continue
        team_opponents.setdefault(home, set()).add(away)
        team_opponents.setdefault(away, set()).add(home)

    if not team_opponents:
        return df

    group_teams = {
        group_name: set(group_df["team"].dropna().astype(str))
        for group_name, group_df in base_groups.groupby("group_name")
    }
    existing_group_teams = {
        (str(row.team), str(row.group_name))
        for row in base_groups.itertuples(index=False)
    }

    synthetic_rows = []
    for row in aggregate_rows.itertuples(index=False):
        team = getattr(row, "team", None)
        if not team:
            continue
        team = str(team)
        if any(existing_team == team for existing_team, _ in existing_group_teams):
            continue

        opponents = team_opponents.get(team, set())
        if not opponents:
            continue

        ranked_candidates = sorted(
            (
                (len(opponents & teams), group_name)
                for group_name, teams in group_teams.items()
            ),
            reverse=True,
        )
        if not ranked_candidates or ranked_candidates[0][0] < 2:
            continue

        _, target_group = ranked_candidates[0]
        if (team, target_group) in existing_group_teams:
            continue

        synthetic = row._asdict()
        synthetic["group_name"] = target_group
        synthetic["rank"] = 3
        synthetic_rows.append(synthetic)
        existing_group_teams.add((team, target_group))

    if not synthetic_rows:
        return df

    restored = pd.concat([df, pd.DataFrame(synthetic_rows)], ignore_index=True)
    return restored.sort_values(["group_name", "rank", "team_id"], ascending=[True, True, True])

@router.get("/league-table",
    summary="Получить турнирную таблицу",
    description="Возвращает турнирную таблицу указанной лиги и сезона с возможностью просмотра общей, домашней или гостевой статистики"
)
def league_table(
    league: str = Query(..., description="Название лиги (Premier League, La Liga, Bundesliga, Serie A, Ligue 1)"),
    season: str = Query(..., description="Сезон в формате YYYY"),
    view: str = Query("total", description="Тип таблицы: total (общая), home (домашняя), away (гостевая)")
):
    query = text("""
        WITH target_leagues AS (
            SELECT DISTINCT s2.league_id
            FROM football.api_football_schedule s2
            WHERE s2.season = :season AND s2.league_name = :league
            UNION
            SELECT l.league_id
            FROM football.api_football_league l
            WHERE l.league_name = :league
        )
        SELECT 
            s.team_name AS team,
            s.rank,
            COALESCE(s.group_name, '') AS group_name,
            s.points,
            s.goals_diff,
            s.form,
            s.status,
            s.description,
            s.all_played,
            s.all_win,
            s.all_draw,
            s.all_lose,
            s.all_goals_for,
            s.all_goals_against,
            s.home_played, s.home_win, s.home_draw, s.home_lose,
            s.home_goals_for, s.home_goals_against,
            s.away_played, s.away_win, s.away_draw, s.away_lose,
            s.away_goals_for, s.away_goals_against,
            s.team_id, s.league_id, s.season,
            :league AS league_name
        FROM football.api_football_standings s
        WHERE s.season = :season
          AND s.league_id IN (SELECT league_id FROM target_leagues)
        ORDER BY COALESCE(s.group_name, ''), s.rank ASC;
    """)

    with engine.connect() as conn:
        df = pd.read_sql(query, conn, params={"league": league, "season": season})

        if view == "home":
            df["games_played"] = df["home_played"]
            df["wins"] = df["home_win"]
            df["draws"] = df["home_draw"]
            df["losses"] = df["home_lose"]
            df["goals_for"] = df["home_goals_for"]
            df["goals_against"] = df["home_goals_against"]
        elif view == "away":
            df["games_played"] = df["away_played"]
            df["wins"] = df["away_win"]
            df["draws"] = df["away_draw"]
            df["losses"] = df["away_lose"]
            df["goals_for"] = df["away_goals_for"]
            df["goals_against"] = df["away_goals_against"]
        else:
            df["games_played"] = df["all_played"]
            df["wins"] = df["all_win"]
            df["draws"] = df["all_draw"]
            df["losses"] = df["all_lose"]
            df["goals_for"] = df["all_goals_for"]
            df["goals_against"] = df["all_goals_against"]

        df["goals_diff"] = df["goals_for"] - df["goals_against"]

        # Keep per-group standings rows separate from aggregate rows like
        # "Group Stage" best third-placed teams.
        df = df.sort_values(["group_name", "rank", "team_id"], ascending=[True, True, True])
        team_key = df["team_id"].where(df["team_id"].notna(), df["team"]).astype(str)
        group_key = df["group_name"].fillna("").astype(str)
        df["_dedupe_key"] = team_key + "::" + group_key
        df = df.drop_duplicates(subset=["_dedupe_key"], keep="first").drop(
            columns=["_dedupe_key"]
        )
        df = _restore_missing_group_third_places(df, conn, league, season)

        drop_cols = [col for col in df.columns if col.startswith("home_") or col.startswith("away_") or col.startswith("all_")]
        df = df.drop(columns=drop_cols)

        return df.to_dict(orient="records")
