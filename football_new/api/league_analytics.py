from collections import defaultdict
import logging
import math

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import create_engine, text

from api.team_identity import merge_named_groups, merge_team_rows
from api.ucl_filters import schedule_round_filter_sql, ucl_stage_condition_sql
from api.core.config import settings

logger = logging.getLogger("uvicorn")

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

router = APIRouter(prefix="/api", tags=["League Analytics"])

LEAGUE_MAP = {
    "premier league": {"api_name": "Premier League", "api_id": 39, "understat_code": "EPL"},
    "la liga": {"api_name": "La Liga", "api_id": 140, "understat_code": "La_liga"},
    "bundesliga": {"api_name": "Bundesliga", "api_id": 78, "understat_code": "Bundesliga"},
    "serie a": {"api_name": "Serie A", "api_id": 135, "understat_code": "Serie_A"},
    "ligue 1": {"api_name": "Ligue 1", "api_id": 61, "understat_code": "Ligue_1"},
    "uefa champions league": {"api_name": "UEFA Champions League", "api_id": 2, "understat_code": None},
}


def _sanitize(rows):
    out = []
    for r in rows:
        for k, v in list(r.items()):
            if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
                r[k] = None
        out.append(r)
    return out


def _resolve_league(league: str):
    key = (league or "").replace("-", " ").strip().lower()
    meta = LEAGUE_MAP.get(key)
    if meta:
        return meta
    normalized = (league or "").replace("-", " ").strip()
    return {
        "api_name": normalized,
        "api_id": None,
        "understat_code": None,
    }


def _round_filter_sql(league_name: str) -> str:
    if league_name == "UEFA Champions League":
        return schedule_round_filter_sql(league_param=":league_name", stage_param=":ucl_stage", alias="s")
    return ""


def _fetch_main_stage_team_ids(con, league_name: str, season: str, ucl_stage: str):
    if league_name != "UEFA Champions League":
        return None
    q = text(
        """
        SELECT DISTINCT team_id
        FROM (
          SELECT home_team_id AS team_id
          FROM football.api_football_schedule s
          WHERE s.league_name = :league_name
            AND s.season = CAST(:season AS int)
            AND """ + ucl_stage_condition_sql(stage_param=":ucl_stage", alias="s") + """
          UNION
          SELECT away_team_id AS team_id
          FROM football.api_football_schedule s
          WHERE s.league_name = :league_name
            AND s.season = CAST(:season AS int)
            AND """ + ucl_stage_condition_sql(stage_param=":ucl_stage", alias="s") + """
        ) t
        """
    )
    return [row[0] for row in con.execute(q, {"league_name": league_name, "season": season, "ucl_stage": ucl_stage}).all()]


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


def _fetch_windowed_team_analytics(con, league_name: str, season: str, ucl_stage: str, window: int | None):
    round_filter = _round_filter_sql(league_name)
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
            opp.total_shots::double precision AS shots_conceded,
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
            {round_filter}
        ),
        scoped AS (
          SELECT *
          FROM played
          WHERE :window IS NULL OR rn <= :window
        )
        SELECT
          team_id,
          team,
          COUNT(*)::int AS matches,
          AVG(shots)::double precision AS shots,
          AVG(shots_on_target)::double precision AS shots_on_target,
          AVG(shots_inside_box)::double precision AS shots_inside_box,
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
          :league_name AS league_name,
          MAX(league_id) AS league_id,
          'api_match_window' AS priority_source
        FROM scoped
        GROUP BY team_id, team
        ORDER BY matches DESC, team
        """
    )
    return [dict(r) for r in con.execute(q, {"league_name": league_name, "season": season, "ucl_stage": ucl_stage, "window": window}).mappings()]


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


def _fetch_team_analytics(con, league_name: str, season: str, ucl_stage: str, window: int | None):
    window_rows = _fetch_windowed_team_analytics(con, league_name, season, ucl_stage, window)
    if window_rows:
        return window_rows, True

    unified_sql = text(
        """
        SELECT
          t.api_team_id AS team_id,
          t.team_name AS team,
          t.matches_played AS matches,
          t.shots_avg AS shots,
          NULL::double precision AS shots_on_target,
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
          t.league_name,
          t.api_league_id AS league_id,
          t.priority_source
        FROM football.vw_unified_team_season_stats t
        WHERE t.league_name = :league_name
          AND t.season = CAST(:season AS int)
        ORDER BY t.shots_avg DESC NULLS LAST, t.team_name
        """
    )
    rows = [dict(r) for r in con.execute(unified_sql, {"league_name": league_name, "season": season}).mappings()]
    if rows:
        return rows, False

    if league_name == "UEFA Champions League":
        stage_sql = text(
            """
            WITH team_rows AS (
              SELECT
                ms.team_id,
                ms.team_name AS team,
                COUNT(*)::int AS matches,
                AVG(ms.total_shots)::double precision AS shots,
                AVG(ms.shots_on_goal)::double precision AS shots_on_target,
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
                s.league_name,
                s.league_id,
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
            ORDER BY matches DESC, team
            """
        )
        rows = [dict(r) for r in con.execute(stage_sql, {"league_name": league_name, "season": season, "ucl_stage": ucl_stage}).mappings()]
        return rows, True

    team_ids = _fetch_main_stage_team_ids(con, league_name, season, ucl_stage)
    fallback_sql = text(
        """
        SELECT
          t.team_id,
          t.team_name AS team,
          t.matches_played AS matches,
          t.shots_avg AS shots,
          NULL::double precision AS shots_on_target,
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
          t.league_name,
          t.league_id,
          'api_fallback' AS priority_source
        FROM football.api_football_team_stats t
        WHERE t.league_name = :league_name
          AND t.season = CAST(:season AS int)
          AND (:team_ids IS NULL OR t.team_id = ANY(:team_ids))
        ORDER BY t.shots_avg DESC NULLS LAST, t.team_name
        """
    )
    rows = [dict(r) for r in con.execute(fallback_sql, {"league_name": league_name, "season": season, "team_ids": team_ids}).mappings()]
    return rows, True


def _fetch_player_analytics(con, league_name: str, season: str, min_minutes: int, min_shots: int, ucl_stage: str):
    unified_sql = text(
        """
        SELECT
          COALESCE(map.api_player_id, p.api_player_id, -p.understat_player_id) AS player_id,
          COALESCE(map.api_player_id, p.api_player_id) AS api_player_id,
          p.understat_player_id,
          COALESCE(map.api_player_name, p.player_name) AS player,
          COALESCE(map.api_player_name, p.player_name) AS player_name,
          COALESCE(map.api_team_id, p.api_team_id) AS team_id,
          p.team_name AS team,
          p.team_name,
          p.minutes,
          p.goals,
          p.assists,
          p.shots,
          p.key_passes,
          p.xg::double precision AS xg,
          p.xa::double precision AS xa,
          p.npg::double precision AS npg,
          p.npxg::double precision AS npxg,
          p.xg_chain::double precision AS xg_chain,
          p.xg_buildup::double precision AS xg_buildup,
          p.priority_source,
          p.league_name,
          p.api_league_id AS league_id
        FROM football.vw_unified_player_season_stats p
        LEFT JOIN LATERAL (
          SELECT m.api_player_id, m.api_player_name, m.api_team_id
          FROM football.player_cross_source_map m
          WHERE m.season = CAST(:season AS int)
            AND m.league_name = :league_name
            AND (
              (p.api_player_id IS NOT NULL AND m.api_player_id = p.api_player_id)
              OR (p.understat_player_id IS NOT NULL AND m.understat_player_id = p.understat_player_id)
            )
          ORDER BY
            CASE WHEN m.api_player_id IS NOT NULL AND m.understat_player_id IS NOT NULL THEN 0 ELSE 1 END,
            COALESCE(m.confidence, 0) DESC
          LIMIT 1
        ) map ON TRUE
        WHERE p.league_name = :league_name
          AND p.season = CAST(:season AS int)
          AND COALESCE(p.minutes, 0) >= :min_minutes
          AND (
                COALESCE(p.shots, 0) >= :min_shots
                OR COALESCE(p.goals, 0) > 0
                OR COALESCE(p.assists, 0) > 0
                OR COALESCE(p.key_passes, 0) > 0
                OR COALESCE(p.xg, 0) >= 5
              )
        ORDER BY COALESCE(p.xg, 0) DESC, COALESCE(p.goals, 0) DESC, COALESCE(p.shots, 0) DESC
        LIMIT 400
        """
    )
    rows = [
        dict(r)
        for r in con.execute(
            unified_sql,
            {
                "league_name": league_name,
                "season": season,
                "min_minutes": min_minutes,
                "min_shots": min_shots,
            },
        ).mappings()
    ]
    if rows:
        return rows

    team_ids = _fetch_main_stage_team_ids(con, league_name, season, ucl_stage)
    fallback_sql = text(
        """
        SELECT
          p.player_id,
          p.player_id AS api_player_id,
          NULL::int AS understat_player_id,
          p.player_name AS player,
          p.player_name,
          p.team_id,
          p.team_name AS team,
          p.team_name,
          p.minutes,
          p.goals_total AS goals,
          GREATEST(COALESCE(p.goals_assists, 0) - COALESCE(p.goals_total, 0), 0) AS assists,
          p.shots_total AS shots,
          p.passes_key AS key_passes,
          NULL::double precision AS xg,
          NULL::double precision AS xa,
          NULL::double precision AS npg,
          NULL::double precision AS npxg,
          NULL::double precision AS xg_chain,
          NULL::double precision AS xg_buildup,
          'api_fallback' AS priority_source,
          :league_name AS league_name,
          NULL::int AS league_id
        FROM football.api_football_player_season_stats p
        WHERE p.season = CAST(:season AS int)
          AND (:team_ids IS NULL OR p.team_id = ANY(:team_ids))
          AND COALESCE(p.minutes, 0) >= :min_minutes
          AND (
                COALESCE(p.shots_total, 0) >= :min_shots
                OR COALESCE(p.goals_total, 0) > 0
                OR COALESCE(p.goals_assists, 0) > 0
                OR COALESCE(p.passes_key, 0) > 0
              )
        ORDER BY COALESCE(p.goals_total, 0) DESC, COALESCE(p.shots_total, 0) DESC, COALESCE(p.passes_key, 0) DESC
        LIMIT 400
        """
    )
    return [
        dict(r)
        for r in con.execute(
            fallback_sql,
            {
                "league_name": league_name,
                "season": season,
                "team_ids": team_ids,
                "min_minutes": min_minutes,
                "min_shots": min_shots,
            },
        ).mappings()
    ]


@router.get("/league-analytics")
def league_analytics(
    league: str = Query(...),
    season: str = Query(...),
    window: int = Query(None, ge=1, le=38),
    trend_window: int = Query(10, ge=5, le=20),
    min_minutes: int = Query(0, ge=0, le=3000),
    min_shots: int = Query(0, ge=0, le=200),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    """
    Unified analytics (Understat priority on overlapping metrics).
    League identifiers are taken from API-Football mapping.
    """
    try:
        meta = _resolve_league(league)
        api_league_name = meta["api_name"]
        api_league_id = meta["api_id"]
        understat_code = meta["understat_code"]

        with engine.begin() as con:
            teams, fallback_mode = _fetch_team_analytics(con, api_league_name, season, ucl_stage, window)
            match_stats_map = _fetch_match_stats_map(con, api_league_name, season, ucl_stage)
            players = _fetch_player_analytics(con, api_league_name, season, min_minutes, min_shots, ucl_stage)

            trends = []
            if understat_code:
                trends_sql = text(
                    """
                    WITH team_rows AS (
                      SELECT
                        lm.match_dt_utc::date AS dt,
                        lm.home_team_id AS team_id,
                        lm.home_team_name AS team,
                        lm.away_team_name AS opponent,
                        lm.home_xg::double precision AS xg
                      FROM football.understat_league_matches lm
                      WHERE lm.league_code = :league_code
                        AND lm.season = CAST(:season AS int)

                      UNION ALL

                      SELECT
                        lm.match_dt_utc::date AS dt,
                        lm.away_team_id AS team_id,
                        lm.away_team_name AS team,
                        lm.home_team_name AS opponent,
                        lm.away_xg::double precision AS xg
                      FROM football.understat_league_matches lm
                      WHERE lm.league_code = :league_code
                        AND lm.season = CAST(:season AS int)
                    ),
                    ranked AS (
                      SELECT
                        tr.*,
                        ROW_NUMBER() OVER (PARTITION BY tr.team_id ORDER BY tr.dt DESC) AS rn
                      FROM team_rows tr
                    )
                    SELECT *
                    FROM ranked
                    WHERE rn <= :trend_window
                    ORDER BY team_id, dt;
                    """
                )
                trend_rows = [
                    dict(r)
                    for r in con.execute(
                        trends_sql,
                        {
                            "league_code": understat_code,
                            "season": season,
                            "trend_window": trend_window,
                        },
                    ).mappings()
                ]
                trends_map = defaultdict(list)
                for r in trend_rows:
                    trends_map[r["team"]].append(
                        {
                            "xg": r.get("xg"),
                            "opponent": r.get("opponent"),
                            "date": r.get("dt").isoformat() if r.get("dt") else None,
                        }
                    )
                trends = [{"team": team_name, "last_matches": rows} for team_name, rows in trends_map.items()]

            leaders_sql = text(
                """
                WITH base AS (
                  SELECT
                    t.season,
                    t.team_name,
                    t.api_team_id AS team_id,
                    t.shots_avg,
                    t.expected_goals_total::double precision / NULLIF(t.matches_played, 0) AS xg_avg,
                    t.goals_for::double precision / NULLIF(t.matches_played, 0) AS goals_avg
                  FROM football.vw_unified_team_season_stats t
                  WHERE t.league_name = :league_name
                ),
                ranked AS (
                  SELECT *,
                         ROW_NUMBER() OVER (PARTITION BY season ORDER BY shots_avg DESC NULLS LAST) AS rn_shots,
                         ROW_NUMBER() OVER (PARTITION BY season ORDER BY xg_avg DESC NULLS LAST) AS rn_xg,
                         ROW_NUMBER() OVER (PARTITION BY season ORDER BY goals_avg DESC NULLS LAST) AS rn_goals
                  FROM base
                ),
                s AS (
                  SELECT season, team_id AS shots_team_id, team_name AS shots_team, shots_avg
                  FROM ranked
                  WHERE rn_shots = 1
                ),
                x AS (
                  SELECT season, team_id AS xg_team_id, team_name AS xg_team, xg_avg
                  FROM ranked
                  WHERE rn_xg = 1
                ),
                g AS (
                  SELECT season, team_id AS goals_team_id, team_name AS goals_team, goals_avg
                  FROM ranked
                  WHERE rn_goals = 1
                )
                SELECT
                  z.season::text AS season,
                  s.shots_team_id, s.shots_team, s.shots_avg,
                  x.xg_team_id, x.xg_team, x.xg_avg,
                  g.goals_team_id, g.goals_team, g.goals_avg
                FROM (SELECT DISTINCT season FROM ranked) z
                LEFT JOIN s ON s.season = z.season
                LEFT JOIN x ON x.season = z.season
                LEFT JOIN g ON g.season = z.season
                ORDER BY z.season DESC
                LIMIT 12;
                """
            )
            leaders = [
                dict(r)
                for r in con.execute(leaders_sql, {"league_name": api_league_name}).mappings()
            ]

        teams = merge_team_rows(_sanitize(_apply_match_stats(teams, match_stats_map)))
        trends = merge_named_groups(trends)

        has_understat = bool(understat_code)
        teams = merge_team_rows(_sanitize(teams))
        trends = merge_named_groups(trends)

        return {
            "league_name": api_league_name,
            "league_id": api_league_id,
            "understat_code": understat_code,
            "has_understat": has_understat,
            "fallback_mode": fallback_mode,
            "ucl_stage": ucl_stage,
            "teams": teams,
            "players": _sanitize(players),
            "trends": trends,
            "leaders": _sanitize(leaders),
        }
    except Exception as e:
        logger.exception("league_analytics failed")
        raise HTTPException(status_code=500, detail=str(e))
