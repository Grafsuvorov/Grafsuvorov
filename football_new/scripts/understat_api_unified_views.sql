CREATE SCHEMA IF NOT EXISTS football;

DROP VIEW IF EXISTS football.vw_unified_team_season_stats;
CREATE VIEW football.vw_unified_team_season_stats AS
WITH league_map AS (
  SELECT *
  FROM (
    VALUES
      ('EPL'::text, 'Premier League'::text, 39::int),
      ('La_liga'::text, 'La Liga'::text, 140::int),
      ('Bundesliga'::text, 'Bundesliga'::text, 78::int),
      ('Serie_A'::text, 'Serie A'::text, 135::int),
      ('Ligue_1'::text, 'Ligue 1'::text, 61::int)
  ) AS t(understat_league_code, league_name, api_league_id)
),
team_map AS (
  SELECT DISTINCT ON (m.season, m.league_name, m.canonical_team_name)
    m.season,
    m.league_name,
    m.canonical_team_name,
    m.api_team_id,
    m.api_team_name,
    m.understat_team_id,
    m.understat_team_name,
    m.mapping_method,
    m.confidence
  FROM football.team_cross_source_map m
  ORDER BY m.season, m.league_name, m.canonical_team_name, m.confidence DESC, m.id DESC
),
understat_match_rows AS (
  SELECT
    lm.league_code,
    lm.season,
    lm.home_team_id AS team_id,
    lm.home_team_name AS team_name,
    1 AS matches_played,
    CASE WHEN COALESCE(lm.home_goals, 0) > COALESCE(lm.away_goals, 0) THEN 1 ELSE 0 END AS wins,
    CASE WHEN COALESCE(lm.home_goals, 0) = COALESCE(lm.away_goals, 0) THEN 1 ELSE 0 END AS draws,
    CASE WHEN COALESCE(lm.home_goals, 0) < COALESCE(lm.away_goals, 0) THEN 1 ELSE 0 END AS losses,
    COALESCE(lm.home_goals, 0) AS goals_for,
    COALESCE(lm.away_goals, 0) AS goals_against,
    COALESCE(lm.home_xg, 0)::numeric AS xg_for,
    COALESCE(lm.away_xg, 0)::numeric AS xg_against
  FROM football.understat_league_matches lm

  UNION ALL

  SELECT
    lm.league_code,
    lm.season,
    lm.away_team_id AS team_id,
    lm.away_team_name AS team_name,
    1 AS matches_played,
    CASE WHEN COALESCE(lm.away_goals, 0) > COALESCE(lm.home_goals, 0) THEN 1 ELSE 0 END AS wins,
    CASE WHEN COALESCE(lm.away_goals, 0) = COALESCE(lm.home_goals, 0) THEN 1 ELSE 0 END AS draws,
    CASE WHEN COALESCE(lm.away_goals, 0) < COALESCE(lm.home_goals, 0) THEN 1 ELSE 0 END AS losses,
    COALESCE(lm.away_goals, 0) AS goals_for,
    COALESCE(lm.home_goals, 0) AS goals_against,
    COALESCE(lm.away_xg, 0)::numeric AS xg_for,
    COALESCE(lm.home_xg, 0)::numeric AS xg_against
  FROM football.understat_league_matches lm
),
understat_team_from_matches AS (
  SELECT
    r.league_code,
    r.season,
    r.team_id,
    MAX(r.team_name) AS team_name,
    SUM(r.matches_played)::int AS matches_played,
    SUM(r.wins)::int AS wins,
    SUM(r.draws)::int AS draws,
    SUM(r.losses)::int AS losses,
    SUM(r.goals_for)::int AS goals_for,
    SUM(r.goals_against)::int AS goals_against,
    SUM(r.xg_for)::numeric AS expected_goals_total,
    SUM(r.xg_against)::numeric AS expected_goals_against_total
  FROM understat_match_rows r
  GROUP BY r.league_code, r.season, r.team_id
),
understat_team_from_history AS (
  SELECT
    h.league_code,
    h.season,
    h.team_id,
    AVG(h.deep)::numeric AS deep_avg,
    AVG(
      CASE
        WHEN NULLIF(h.ppda_def, 0) IS NULL THEN NULL
        ELSE h.ppda_att / NULLIF(h.ppda_def, 0)
      END
    )::numeric AS ppda_avg,
    AVG(
      CASE
        WHEN NULLIF(h.ppda_allowed_def, 0) IS NULL THEN NULL
        ELSE h.ppda_allowed_att / NULLIF(h.ppda_allowed_def, 0)
      END
    )::numeric AS ppda_allowed_avg
  FROM football.understat_league_team_history h
  GROUP BY h.league_code, h.season, h.team_id
),
understat_team AS (
  SELECT
    m.league_code,
    m.season,
    m.team_id,
    m.team_name,
    m.matches_played,
    m.wins,
    m.draws,
    m.losses,
    m.goals_for,
    m.goals_against,
    m.expected_goals_total,
    m.expected_goals_against_total,
    h.deep_avg,
    h.ppda_avg,
    h.ppda_allowed_avg
  FROM understat_team_from_matches m
  LEFT JOIN understat_team_from_history h
    ON h.league_code = m.league_code
   AND h.season = m.season
   AND h.team_id = m.team_id
),
api_team AS (
  SELECT
    t.season,
    t.league_name,
    t.league_id,
    t.team_id,
    t.team_name,
    t.matches_played,
    t.wins,
    t.draws,
    t.losses,
    t.goals_for,
    t.goals_against,
    t.expected_goals_total,
    t.expected_goals_against_total,
    t.clean_sheets,
    t.failed_to_score,
    t.penalties_scored,
    t.penalties_missed,
    t.shots_avg,
    t.possession_avg,
    t.tempo_shots_per_game
  FROM football.api_football_team_stats t
)
SELECT
  tm.season,
  tm.league_name,
  lm.understat_league_code,
  lm.api_league_id,
  tm.canonical_team_name,
  tm.understat_team_id,
  tm.api_team_id,
  COALESCE(u.team_name, a.team_name, tm.understat_team_name, tm.api_team_name) AS team_name,

  COALESCE(u.matches_played, a.matches_played) AS matches_played,
  COALESCE(u.wins, a.wins) AS wins,
  COALESCE(u.draws, a.draws) AS draws,
  COALESCE(u.losses, a.losses) AS losses,
  COALESCE(u.goals_for, a.goals_for) AS goals_for,
  COALESCE(u.goals_against, a.goals_against) AS goals_against,
  COALESCE(u.expected_goals_total, a.expected_goals_total)::numeric AS expected_goals_total,
  COALESCE(u.expected_goals_against_total, a.expected_goals_against_total)::numeric AS expected_goals_against_total,

  a.clean_sheets,
  a.failed_to_score,
  a.penalties_scored,
  a.penalties_missed,
  a.shots_avg,
  a.possession_avg,
  a.tempo_shots_per_game,

  u.deep_avg,
  u.ppda_avg,
  u.ppda_allowed_avg,

  (u.team_id IS NOT NULL) AS has_understat,
  (a.team_id IS NOT NULL) AS has_api_football,
  CASE
    WHEN u.team_id IS NOT NULL THEN 'understat'
    WHEN a.team_id IS NOT NULL THEN 'api_football'
    ELSE 'none'
  END AS priority_source,

  tm.mapping_method,
  tm.confidence,
  NOW()::timestamptz AS refreshed_at
FROM team_map tm
JOIN league_map lm
  ON lm.league_name = tm.league_name
LEFT JOIN understat_team u
  ON u.season = tm.season
 AND u.league_code = lm.understat_league_code
 AND u.team_id = tm.understat_team_id
LEFT JOIN api_team a
  ON a.season = tm.season
 AND a.league_id = lm.api_league_id
 AND a.team_id = tm.api_team_id;


DROP VIEW IF EXISTS football.vw_unified_player_season_stats;
CREATE VIEW football.vw_unified_player_season_stats AS
WITH league_map AS (
  SELECT *
  FROM (
    VALUES
      ('EPL'::text, 'Premier League'::text, 39::int),
      ('La_liga'::text, 'La Liga'::text, 140::int),
      ('Bundesliga'::text, 'Bundesliga'::text, 78::int),
      ('Serie_A'::text, 'Serie A'::text, 135::int),
      ('Ligue_1'::text, 'Ligue 1'::text, 61::int)
  ) AS t(understat_league_code, league_name, api_league_id)
),
player_map AS (
  SELECT DISTINCT ON (m.season, m.league_name, m.canonical_team_name, m.canonical_player_name)
    m.season,
    m.league_name,
    m.canonical_team_name,
    m.canonical_player_name,
    m.api_player_id,
    m.api_player_name,
    m.api_team_id,
    m.api_team_name,
    m.understat_player_id,
    m.understat_player_name,
    m.understat_team_id,
    m.understat_team_name,
    m.mapping_method,
    m.confidence
  FROM football.player_cross_source_map m
  ORDER BY
    m.season,
    m.league_name,
    m.canonical_team_name,
    m.canonical_player_name,
    m.confidence DESC,
    m.id DESC
),
understat_players AS (
  SELECT
    p.league_code,
    p.season,
    p.player_id,
    p.player_name,
    p.team_title,
    p.position,
    p.games,
    p.minutes,
    p.goals,
    p.assists,
    p.shots,
    p.key_passes,
    p.yellow_cards,
    p.red_cards,
    p.xg,
    p.xa,
    p.npg,
    p.npxg,
    p.xg_chain,
    p.xg_buildup
  FROM football.understat_league_players p
),
api_players AS (
  WITH comp_rows AS (
    SELECT
      p.season,
      p.league_id,
      p.league_name,
      p.team_id,
      p.team_name,
      p.player_id,
      p.player_name,
      p.position,
      p.appearences,
      p.lineups,
      p.minutes,
      p.rating_avg,
      p.goals_total,
      p.goals_assists,
      p.shots_total,
      p.shots_on,
      p.passes_total,
      p.passes_key,
      p.passes_accuracy,
      p.tackles_total,
      p.tackles_blocks,
      p.tackles_interceptions,
      p.duels_total,
      p.duels_won,
      p.dribbles_attempts,
      p.dribbles_success,
      p.fouls_drawn,
      p.fouls_committed,
      p.cards_yellow,
      p.cards_red,
      p.penalty_won,
      p.penalty_committed,
      p.penalty_scored,
      p.penalty_missed,
      p.penalty_saved,
      1 AS src_rank
    FROM football.api_football_player_comp_season_stats p
  ),
  season_fallback AS (
    SELECT
      p.season,
      lm.api_league_id AS league_id,
      lm.league_name,
      p.team_id,
      p.team_name,
      p.player_id,
      p.player_name,
      p.position,
      p.appearences,
      p.lineups,
      p.minutes,
      p.rating_avg,
      p.goals_total,
      p.goals_assists,
      p.shots_total,
      p.shots_on,
      p.passes_total,
      p.passes_key,
      p.passes_accuracy,
      p.tackles_total,
      p.tackles_blocks,
      p.tackles_interceptions,
      p.duels_total,
      p.duels_won,
      p.dribbles_attempts,
      p.dribbles_success,
      p.fouls_drawn,
      p.fouls_committed,
      p.cards_yellow,
      p.cards_red,
      p.penalty_won,
      p.penalty_committed,
      p.penalty_scored,
      p.penalty_missed,
      p.penalty_saved,
      2 AS src_rank
    FROM football.api_football_player_season_stats p
    JOIN league_map lm
      ON EXISTS (
        SELECT 1
        FROM football.api_football_schedule s
        WHERE s.season = p.season
          AND s.league_id = lm.api_league_id
          AND (s.home_team_id = p.team_id OR s.away_team_id = p.team_id)
      )
  ),
  unioned AS (
    SELECT * FROM comp_rows
    UNION ALL
    SELECT * FROM season_fallback
  )
  SELECT DISTINCT ON (u.season, u.league_id, u.team_id, u.player_id)
    u.season,
    u.league_id,
    u.league_name,
    u.team_id,
    u.team_name,
    u.player_id,
    u.player_name,
    u.position,
    u.appearences,
    u.lineups,
    u.minutes,
    u.rating_avg,
    u.goals_total,
    u.goals_assists,
    u.shots_total,
    u.shots_on,
    u.passes_total,
    u.passes_key,
    u.passes_accuracy,
    u.tackles_total,
    u.tackles_blocks,
    u.tackles_interceptions,
    u.duels_total,
    u.duels_won,
    u.dribbles_attempts,
    u.dribbles_success,
    u.fouls_drawn,
    u.fouls_committed,
    u.cards_yellow,
    u.cards_red,
    u.penalty_won,
    u.penalty_committed,
    u.penalty_scored,
    u.penalty_missed,
    u.penalty_saved
  FROM unioned u
  ORDER BY u.season, u.league_id, u.team_id, u.player_id, u.src_rank
)
SELECT
  pm.season,
  pm.league_name,
  lm.understat_league_code,
  lm.api_league_id,

  pm.canonical_team_name,
  pm.canonical_player_name,
  pm.understat_team_id,
  pm.api_team_id,
  pm.understat_player_id,
  pm.api_player_id,
  COALESCE(u.player_name, a.player_name, pm.understat_player_name, pm.api_player_name) AS player_name,
  COALESCE(u.team_title, a.team_name, pm.understat_team_name, pm.api_team_name) AS team_name,

  COALESCE(u.position, a.position) AS position,
  COALESCE(u.games, a.appearences) AS appearances,
  a.lineups,
  COALESCE(u.minutes, a.minutes) AS minutes,

  COALESCE(u.goals, a.goals_total) AS goals,
  COALESCE(u.assists, a.goals_assists) AS assists,
  COALESCE(u.shots, a.shots_total) AS shots,
  a.shots_on,
  COALESCE(u.key_passes, a.passes_key) AS key_passes,
  a.passes_total,
  a.passes_accuracy,

  COALESCE(u.yellow_cards, a.cards_yellow) AS yellow_cards,
  COALESCE(u.red_cards, a.cards_red) AS red_cards,

  u.xg,
  u.xa,
  u.npg,
  u.npxg,
  u.xg_chain,
  u.xg_buildup,

  a.rating_avg,
  a.tackles_total,
  a.tackles_blocks,
  a.tackles_interceptions,
  a.duels_total,
  a.duels_won,
  a.dribbles_attempts,
  a.dribbles_success,
  a.fouls_drawn,
  a.fouls_committed,
  a.penalty_won,
  a.penalty_committed,
  a.penalty_scored,
  a.penalty_missed,
  a.penalty_saved,

  (u.player_id IS NOT NULL) AS has_understat,
  (a.player_id IS NOT NULL) AS has_api_football,
  CASE
    WHEN u.player_id IS NOT NULL THEN 'understat'
    WHEN a.player_id IS NOT NULL THEN 'api_football'
    ELSE 'none'
  END AS priority_source,

  pm.mapping_method,
  pm.confidence,
  NOW()::timestamptz AS refreshed_at
FROM player_map pm
JOIN league_map lm
  ON lm.league_name = pm.league_name
LEFT JOIN understat_players u
  ON u.season = pm.season
 AND u.league_code = lm.understat_league_code
 AND u.player_id = pm.understat_player_id
LEFT JOIN api_players a
  ON a.season = pm.season
 AND a.league_id = lm.api_league_id
 AND a.player_id = pm.api_player_id
 AND (pm.api_team_id IS NULL OR a.team_id = pm.api_team_id);
