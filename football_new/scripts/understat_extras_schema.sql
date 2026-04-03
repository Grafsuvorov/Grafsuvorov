CREATE SCHEMA IF NOT EXISTS football;

CREATE TABLE IF NOT EXISTS football.understat_league_matches (
  league_code         TEXT NOT NULL,
  season              INT NOT NULL,
  match_id            BIGINT NOT NULL,
  match_dt_utc        TIMESTAMP,
  is_result           BOOLEAN,
  home_team_id        INT,
  home_team_name      TEXT,
  home_team_short     TEXT,
  away_team_id        INT,
  away_team_name      TEXT,
  away_team_short     TEXT,
  home_goals          INT,
  away_goals          INT,
  home_xg             NUMERIC(10,5),
  away_xg             NUMERIC(10,5),
  forecast_home_win   NUMERIC(10,4),
  forecast_draw       NUMERIC(10,4),
  forecast_away_win   NUMERIC(10,4),
  raw_json            JSONB,
  inserted_dttm       TIMESTAMPTZ DEFAULT NOW(),
  updated_dttm        TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (league_code, season, match_id)
);

CREATE TABLE IF NOT EXISTS football.understat_league_team_history (
  league_code         TEXT NOT NULL,
  season              INT NOT NULL,
  team_id             INT NOT NULL,
  team_title          TEXT,
  h_a                 CHAR(1),
  match_dt_utc        TIMESTAMP NOT NULL,
  result              TEXT,
  wins                INT,
  draws               INT,
  loses               INT,
  pts                 INT,
  scored              INT,
  missed              INT,
  xg                  NUMERIC(10,6),
  xga                 NUMERIC(10,6),
  npxg                NUMERIC(10,6),
  npxga               NUMERIC(10,6),
  npxgd               NUMERIC(10,6),
  xpts                NUMERIC(10,6),
  deep                INT,
  deep_allowed        INT,
  ppda_att            NUMERIC(10,3),
  ppda_def            NUMERIC(10,3),
  ppda_allowed_att    NUMERIC(10,3),
  ppda_allowed_def    NUMERIC(10,3),
  raw_json            JSONB,
  inserted_dttm       TIMESTAMPTZ DEFAULT NOW(),
  updated_dttm        TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (league_code, season, team_id, match_dt_utc)
);

CREATE TABLE IF NOT EXISTS football.understat_league_players (
  league_code         TEXT NOT NULL,
  season              INT NOT NULL,
  player_id           BIGINT NOT NULL,
  player_name         TEXT,
  team_title          TEXT,
  position            TEXT,
  games               INT,
  minutes             INT,
  goals               INT,
  assists             INT,
  shots               INT,
  key_passes          INT,
  yellow_cards        INT,
  red_cards           INT,
  xg                  NUMERIC(12,6),
  xa                  NUMERIC(12,6),
  npg                 INT,
  npxg                NUMERIC(12,6),
  xg_chain            NUMERIC(12,6),
  xg_buildup          NUMERIC(12,6),
  raw_json            JSONB,
  inserted_dttm       TIMESTAMPTZ DEFAULT NOW(),
  updated_dttm        TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (league_code, season, player_id)
);

CREATE INDEX IF NOT EXISTS ix_understat_lm_dt
  ON football.understat_league_matches(match_dt_utc);

CREATE INDEX IF NOT EXISTS ix_understat_lth_team_dt
  ON football.understat_league_team_history(team_id, match_dt_utc);

CREATE INDEX IF NOT EXISTS ix_understat_lp_team
  ON football.understat_league_players(team_title);
