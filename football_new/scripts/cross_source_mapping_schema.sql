CREATE SCHEMA IF NOT EXISTS football;

CREATE TABLE IF NOT EXISTS football.team_cross_source_map (
  id                  BIGSERIAL PRIMARY KEY,
  season              INT NOT NULL,
  league_name         TEXT NOT NULL,
  canonical_team_name TEXT NOT NULL,
  api_team_id         INT,
  api_team_name       TEXT,
  understat_team_id   INT,
  understat_team_name TEXT,
  mapping_method      TEXT,
  confidence          NUMERIC(5,4),
  notes               TEXT,
  updated_dttm        TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_team_cross_source_map_key
  ON football.team_cross_source_map(season, league_name, canonical_team_name);

CREATE INDEX IF NOT EXISTS ix_team_cross_source_map_api
  ON football.team_cross_source_map(api_team_id);

CREATE INDEX IF NOT EXISTS ix_team_cross_source_map_understat
  ON football.team_cross_source_map(understat_team_id);


CREATE TABLE IF NOT EXISTS football.player_cross_source_map (
  id                    BIGSERIAL PRIMARY KEY,
  season                INT NOT NULL,
  league_name           TEXT NOT NULL,
  canonical_team_name   TEXT NOT NULL,
  canonical_player_name TEXT NOT NULL,
  api_player_id         BIGINT,
  api_player_name       TEXT,
  api_team_id           INT,
  api_team_name         TEXT,
  understat_player_id   BIGINT,
  understat_player_name TEXT,
  understat_team_id     INT,
  understat_team_name   TEXT,
  mapping_method        TEXT,
  confidence            NUMERIC(5,4),
  notes                 TEXT,
  updated_dttm          TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_player_cross_source_map_key
  ON football.player_cross_source_map(season, league_name, canonical_team_name, canonical_player_name);

CREATE INDEX IF NOT EXISTS ix_player_cross_source_map_api
  ON football.player_cross_source_map(api_player_id);

CREATE INDEX IF NOT EXISTS ix_player_cross_source_map_understat
  ON football.player_cross_source_map(understat_player_id);
