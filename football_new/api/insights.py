import logging
import math

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import create_engine, text

from api.team_identity import merge_team_rows
from api.ucl_filters import schedule_round_filter_sql, ucl_stage_condition_sql
from api.core.config import settings

logger = logging.getLogger("uvicorn")

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

router = APIRouter(prefix="/api", tags=["Insights"])


def _sanitize(rows):
    out = []
    for r in rows:
        for k, v in list(r.items()):
            if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
                r[k] = None
        out.append(r)
    return out


def _normalize_league(league: str) -> str:
    return (league or "").replace("-", " ").strip()


def _round_filter_sql(league_name: str) -> str:
    if league_name == "UEFA Champions League":
        return schedule_round_filter_sql(league_param=":league_name", stage_param=":ucl_stage", alias="s")
    return ""


def _fetch_match_stats_map(con, league_name: str, season: str, ucl_stage: str):
    q = text(
        f"""
        SELECT
          ms.team_id,
          AVG(ms.shots_on_goal)::double precision AS shots_on_target,
          AVG(ms.shots_insidebox)::double precision AS shots_inside_box,
          AVG(opp.total_shots)::double precision AS shots_conceded,
          AVG(ms.tackles)::double precision AS tackles,
          AVG(ms.attacks)::double precision AS attacks,
          AVG(ms.dangerous_attacks)::double precision AS dangerous_attacks,
          AVG(ms.corners)::double precision AS corners
        FROM football.api_football_match_stats ms
        JOIN football.api_football_schedule s
          ON s.fixture_id = ms.fixture_id
        LEFT JOIN football.api_football_match_stats opp
          ON opp.fixture_id = ms.fixture_id
         AND opp.team_id <> ms.team_id
        WHERE s.league_name = :league_name
          AND s.season = CAST(:season AS int)
          {_round_filter_sql(league_name)}
        GROUP BY ms.team_id
        """
    )
    rows = [dict(r) for r in con.execute(q, {"league_name": league_name, "season": season, "ucl_stage": ucl_stage}).mappings()]
    return {row["team_id"]: row for row in rows if row.get("team_id") is not None}


def _fetch_windowed_team_rows(
    con,
    league_name: str,
    season: str,
    min_matches: int,
    limit: int,
    ucl_stage: str,
    window: int | None,
):
    q = text(
        f"""
        WITH played AS (
          SELECT
            s.fixture_id,
            s.league_name,
            s.league_id,
            s.date,
            ms.team_id,
            ms.team_name AS team,
            ms.total_shots::double precision AS shots,
            ms.shots_on_goal::double precision AS shots_on_target,
            ms.shots_insidebox::double precision AS shots_inside_box,
            ms.expected_goals::double precision AS xg,
            opp.expected_goals::double precision AS xga,
            CASE
              WHEN ms.team_id = s.home_team_id THEN COALESCE(s.home_goals, s.score_fulltime_home)
              ELSE COALESCE(s.away_goals, s.score_fulltime_away)
            END::double precision AS goals,
            CASE
              WHEN ms.team_id = s.home_team_id THEN COALESCE(s.away_goals, s.score_fulltime_away)
              ELSE COALESCE(s.home_goals, s.score_fulltime_home)
            END::double precision AS goals_conceded,
            ms.possession::double precision AS possession,
            ms.tackles::double precision AS tackles,
            ms.attacks::double precision AS attacks,
            ms.dangerous_attacks::double precision AS dangerous_attacks,
            ms.corners::double precision AS corners,
            opp.total_shots::double precision AS shots_conceded,
            ROW_NUMBER() OVER (
              PARTITION BY ms.team_id
              ORDER BY COALESCE(s.date, NOW()) DESC, s.fixture_id DESC
            ) AS rn
          FROM football.api_football_match_stats ms
          JOIN football.api_football_schedule s
            ON s.fixture_id = ms.fixture_id
          LEFT JOIN football.api_football_match_stats opp
            ON opp.fixture_id = ms.fixture_id
           AND opp.team_id <> ms.team_id
          WHERE s.league_name = :league_name
            AND s.season = CAST(:season AS int)
            AND COALESCE(s.status, '') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded')
            {_round_filter_sql(league_name)}
        ),
        scoped AS (
          SELECT *
          FROM played
          WHERE :window IS NULL OR rn <= :window
        )
        SELECT
          team_id,
          team,
          league_name,
          MAX(league_id) AS league_id,
          COUNT(*)::int AS matches,
          AVG(shots)::double precision AS shots,
          AVG(shots_on_target)::double precision AS shots_on_target,
          AVG(shots_inside_box)::double precision AS shots_inside_box,
          NULL::double precision AS shots_outside_box,
          AVG(shots_conceded)::double precision AS shots_conceded,
          AVG(xg)::double precision AS xg,
          AVG(xga)::double precision AS xga,
          AVG(goals)::double precision AS goals,
          AVG(goals_conceded)::double precision AS goals_conceded,
          AVG(possession)::double precision AS possession,
          AVG(tackles)::double precision AS tackles,
          AVG(attacks)::double precision AS attacks,
          AVG(dangerous_attacks)::double precision AS dangerous_attacks,
          AVG(corners)::double precision AS corners,
          SUM(CASE WHEN goals_conceded = 0 THEN 1 ELSE 0 END)::int AS clean_sheets,
          SUM(CASE WHEN goals = 0 THEN 1 ELSE 0 END)::int AS failed_to_score,
          AVG(shots)::double precision AS tempo_shots_per_game,
          NULL::double precision AS deep_avg,
          NULL::double precision AS ppda_avg,
          NULL::double precision AS ppda_allowed_avg,
          'api_match_window' AS priority_source
        FROM scoped
        GROUP BY team_id, team, league_name
        HAVING COUNT(*) >= :min_matches
        ORDER BY matches DESC, team
        LIMIT :limit
        """
    )
    return [
        dict(r)
        for r in con.execute(
            q,
            {
                "league_name": league_name,
                "season": season,
                "ucl_stage": ucl_stage,
                "window": window,
                "min_matches": min_matches,
                "limit": limit,
            },
        ).mappings()
    ]


def _apply_match_stats(rows, match_stats_map):
    for row in rows:
        team_id = row.get("team_id")
        stats = match_stats_map.get(team_id)
        if not stats:
            continue
        for key in (
            "shots_on_target",
            "shots_inside_box",
            "shots_conceded",
            "tackles",
            "attacks",
            "dangerous_attacks",
            "corners",
        ):
            if row.get(key) is None and stats.get(key) is not None:
                row[key] = stats.get(key)
    return rows


def _fetch_team_rows(con, league_name: str, season: str, min_matches: int, limit: int, ucl_stage: str, window: int | None):
    window_rows = _fetch_windowed_team_rows(con, league_name, season, min_matches, limit, ucl_stage, window)
    if window_rows:
        return window_rows, True

    unified_q = text(
        """
        SELECT
          t.api_team_id AS team_id,
          t.team_name AS team,
          t.league_name,
          t.api_league_id AS league_id,
          t.matches_played AS matches,
          t.shots_avg AS shots,
          NULL::double precision AS shots_on_target,
          NULL::double precision AS shots_inside_box,
          NULL::double precision AS shots_outside_box,
          NULL::double precision AS shots_conceded,
          t.expected_goals_total::double precision / NULLIF(t.matches_played, 0) AS xg,
          t.expected_goals_against_total::double precision / NULLIF(t.matches_played, 0) AS xga,
          t.goals_for::double precision / NULLIF(t.matches_played, 0) AS goals,
          t.goals_against::double precision / NULLIF(t.matches_played, 0) AS goals_conceded,
          t.possession_avg AS possession,
          NULL::double precision AS tackles,
          NULL::double precision AS attacks,
          NULL::double precision AS dangerous_attacks,
          NULL::double precision AS corners,
          t.clean_sheets,
          t.failed_to_score,
          t.tempo_shots_per_game,
          t.deep_avg,
          t.ppda_avg,
          t.ppda_allowed_avg,
          t.priority_source
        FROM football.vw_unified_team_season_stats t
        WHERE t.league_name = :league_name
          AND t.season = CAST(:season AS int)
          AND t.matches_played >= :min_matches
        ORDER BY t.matches_played DESC, t.team_name
        LIMIT :limit
        """
    )
    rows = [dict(r) for r in con.execute(unified_q, {"league_name": league_name, "season": season, "min_matches": min_matches, "limit": limit}).mappings()]
    if rows:
        return rows, False

    if league_name == "UEFA Champions League":
        stage_q = text(
            """
            WITH team_rows AS (
              SELECT
                ms.team_id,
                ms.team_name AS team,
                s.league_name,
                s.league_id,
                COUNT(*)::int AS matches,
                AVG(ms.total_shots)::double precision AS shots,
                AVG(ms.shots_on_goal)::double precision AS shots_on_target,
                AVG(ms.shots_insidebox)::double precision AS shots_inside_box,
                NULL::double precision AS shots_outside_box,
                AVG(opp.total_shots)::double precision AS shots_conceded,
                AVG(ms.expected_goals)::double precision AS xg,
                AVG(opp.expected_goals)::double precision AS xga,
                AVG(
                  CASE
                    WHEN ms.team_id = s.home_team_id THEN COALESCE(s.home_goals, s.score_fulltime_home)
                    ELSE COALESCE(s.away_goals, s.score_fulltime_away)
                  END
                )::double precision AS goals,
                AVG(
                  CASE
                    WHEN ms.team_id = s.home_team_id THEN COALESCE(s.away_goals, s.score_fulltime_away)
                    ELSE COALESCE(s.home_goals, s.score_fulltime_home)
                  END
                )::double precision AS goals_conceded,
                AVG(ms.possession)::double precision AS possession,
                AVG(ms.tackles)::double precision AS tackles,
                AVG(ms.attacks)::double precision AS attacks,
                AVG(ms.dangerous_attacks)::double precision AS dangerous_attacks,
                AVG(ms.corners)::double precision AS corners,
                SUM(
                  CASE
                    WHEN ms.team_id = s.home_team_id AND COALESCE(s.away_goals, s.score_fulltime_away, 0) = 0 THEN 1
                    WHEN ms.team_id = s.away_team_id AND COALESCE(s.home_goals, s.score_fulltime_home, 0) = 0 THEN 1
                    ELSE 0
                  END
                )::int AS clean_sheets,
                SUM(
                  CASE
                    WHEN ms.team_id = s.home_team_id AND COALESCE(s.home_goals, s.score_fulltime_home, 0) = 0 THEN 1
                    WHEN ms.team_id = s.away_team_id AND COALESCE(s.away_goals, s.score_fulltime_away, 0) = 0 THEN 1
                    ELSE 0
                  END
                )::int AS failed_to_score,
                AVG(ms.total_shots)::double precision AS tempo_shots_per_game,
                NULL::double precision AS deep_avg,
                NULL::double precision AS ppda_avg,
                NULL::double precision AS ppda_allowed_avg,
                'api_match_stats_fallback' AS priority_source
              FROM football.api_football_match_stats ms
              JOIN football.api_football_schedule s
                ON s.fixture_id = ms.fixture_id
              LEFT JOIN football.api_football_match_stats opp
                ON opp.fixture_id = ms.fixture_id
               AND opp.team_id <> ms.team_id
              WHERE s.league_name = :league_name
                AND s.season = CAST(:season AS int)
                AND """ + ucl_stage_condition_sql(stage_param=":ucl_stage", alias="s") + """
              GROUP BY ms.team_id, ms.team_name, s.league_name, s.league_id
            )
            SELECT *
            FROM team_rows
            WHERE matches >= :min_matches
            ORDER BY matches DESC, team
            LIMIT :limit
            """
        )
        rows = [
            dict(r)
            for r in con.execute(
                stage_q,
                {
                    "league_name": league_name,
                    "season": season,
                    "min_matches": min_matches,
                    "limit": limit,
                    "ucl_stage": ucl_stage,
                },
            ).mappings()
        ]
        return rows, True

    fallback_q = text(
        """
        SELECT
          t.team_id,
          t.team_name AS team,
          t.league_name,
          t.league_id,
          t.matches_played AS matches,
          t.shots_avg AS shots,
          NULL::double precision AS shots_on_target,
          NULL::double precision AS shots_inside_box,
          NULL::double precision AS shots_outside_box,
          NULL::double precision AS shots_conceded,
          t.expected_goals_total::double precision / NULLIF(t.matches_played, 0) AS xg,
          t.expected_goals_against_total::double precision / NULLIF(t.matches_played, 0) AS xga,
          t.goals_for::double precision / NULLIF(t.matches_played, 0) AS goals,
          t.goals_against::double precision / NULLIF(t.matches_played, 0) AS goals_conceded,
          t.possession_avg AS possession,
          NULL::double precision AS tackles,
          NULL::double precision AS attacks,
          NULL::double precision AS dangerous_attacks,
          NULL::double precision AS corners,
          t.clean_sheets,
          t.failed_to_score,
          t.tempo_shots_per_game,
          NULL::double precision AS deep_avg,
          NULL::double precision AS ppda_avg,
          NULL::double precision AS ppda_allowed_avg,
          'api_fallback' AS priority_source
        FROM football.api_football_team_stats t
        WHERE t.league_name = :league_name
          AND t.season = CAST(:season AS int)
          AND t.matches_played >= :min_matches
        ORDER BY t.matches_played DESC, t.team_name
        LIMIT :limit
        """
    )
    rows = [dict(r) for r in con.execute(fallback_q, {"league_name": league_name, "season": season, "min_matches": min_matches, "limit": limit}).mappings()]
    return rows, True


@router.get("/insights")
def league_insights(
    league: str = Query(..., description="League name"),
    season: str = Query(..., description="Season year"),
    metric: str = Query("shots", description="Metric key for default sorting"),
    min_matches: int = Query(1, ge=1, le=60),
    window: int = Query(None, ge=1, le=38, description="Rolling window over played matches"),
    limit: int = Query(200, ge=10, le=500),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    """
    Aggregated team statistics with league metadata from API-Football
    and metric priority: Understat > API-Football for overlapping fields.
    """
    try:
        league_name = _normalize_league(league)
        with engine.begin() as con:
            rows, fallback_mode = _fetch_team_rows(con, league_name, season, min_matches, limit, ucl_stage, window)
            match_stats_map = _fetch_match_stats_map(con, league_name, season, ucl_stage)

        rows = _sanitize(merge_team_rows(_apply_match_stats(rows, match_stats_map)))

        def pick_top(key, reverse=True):
            valid = [r for r in rows if r.get(key) is not None]
            if not valid:
                return None
            valid.sort(key=lambda r: r.get(key) or 0, reverse=reverse)
            return valid[0]

        cards = {
            "most_attacking": pick_top("shots", True),
            "weakest_defense": pick_top("goals_conceded", True),
            "highest_xg": pick_top("xg", True),
            "most_shots_conceded": pick_top("shots_conceded", True),
        }

        return {
            "league": league_name,
            "season": season,
            "metric": metric,
            "min_matches": min_matches,
            "window": window,
            "ucl_stage": ucl_stage,
            "fallback_mode": fallback_mode,
            "teams": rows,
            "cards": cards,
        }
    except Exception as e:
        logger.exception("league_insights failed")
        raise HTTPException(status_code=500, detail=str(e))
