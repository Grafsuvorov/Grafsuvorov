CREATE SCHEMA IF NOT EXISTS football;

CREATE TABLE IF NOT EXISTS football.understat_matches (
  match_id            BIGINT PRIMARY KEY,
  source              TEXT NOT NULL DEFAULT 'understat',
  fixture_ext_id      BIGINT,
  league              TEXT,
  league_id           INT,
  season              INT,
  match_dt_utc        TIMESTAMP,
  home_team_id        INT,
  home_team_name      TEXT,
  away_team_id        INT,
  away_team_name      TEXT,
  home_goals          INT,
  away_goals          INT,
  home_xg             NUMERIC(10,5),
  away_xg             NUMERIC(10,5),
  home_shots          INT,
  away_shots          INT,
  home_sot            INT,
  away_sot            INT,
  home_deep           INT,
  away_deep           INT,
  home_ppda           NUMERIC(10,4),
  away_ppda           NUMERIC(10,4),
  prob_home_win       NUMERIC(10,4),
  prob_draw           NUMERIC(10,4),
  prob_home_loss      NUMERIC(10,4),
  is_data             BOOLEAN,
  raw_json            JSONB,
  inserted_dttm       TIMESTAMPTZ DEFAULT NOW(),
  updated_dttm        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS football.understat_match_players (
  match_id            BIGINT NOT NULL REFERENCES football.understat_matches(match_id),
  side                CHAR(1) NOT NULL,
  row_id              BIGINT,
  player_id           BIGINT NOT NULL,
  player_name         TEXT,
  team_id             INT,
  position            TEXT,
  position_order      INT,
  minutes             INT,
  goals               INT,
  assists             INT,
  shots               INT,
  key_passes          INT,
  xg                  NUMERIC(10,6),
  xa                  NUMERIC(10,6),
  xg_chain            NUMERIC(10,6),
  xg_buildup          NUMERIC(10,6),
  yellow_cards        INT,
  red_cards           INT,
  own_goals           INT,
  roster_in           BIGINT,
  roster_out          BIGINT,
  raw_json            JSONB,
  inserted_dttm       TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (match_id, player_id, side)
);

CREATE TABLE IF NOT EXISTS football.understat_match_shots (
  shot_id             BIGINT PRIMARY KEY,
  match_id            BIGINT NOT NULL REFERENCES football.understat_matches(match_id),
  side                CHAR(1) NOT NULL,
  minute              INT,
  player_id           BIGINT,
  player_name         TEXT,
  assisted_by         TEXT,
  result              TEXT,
  situation           TEXT,
  shot_type           TEXT,
  last_action         TEXT,
  x                   NUMERIC(10,6),
  y                   NUMERIC(10,6),
  xg                  NUMERIC(10,6),
  score_home_after    INT,
  score_away_after    INT,
  shot_dt_utc         TIMESTAMP,
  raw_json            JSONB,
  inserted_dttm       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_understat_players_match
  ON football.understat_match_players(match_id);

CREATE INDEX IF NOT EXISTS ix_understat_shots_match
  ON football.understat_match_shots(match_id);
