CREATE TABLE IF NOT EXISTS football.odds_snapshots_v1 (
    fixture_id bigint NOT NULL,
    snapshot_time_utc timestamptz NOT NULL,
    bookmaker_count integer,
    avg_odds_home double precision,
    avg_odds_draw double precision,
    avg_odds_away double precision,
    avg_odds_over25 double precision,
    avg_odds_under25 double precision,
    source_name text,
    ingest_time_utc timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (fixture_id, snapshot_time_utc)
);

CREATE INDEX IF NOT EXISTS idx_odds_snapshots_v1_fixture_time
    ON football.odds_snapshots_v1 (fixture_id, snapshot_time_utc DESC);

CREATE INDEX IF NOT EXISTS idx_odds_snapshots_v1_time
    ON football.odds_snapshots_v1 (snapshot_time_utc DESC);
