from __future__ import annotations

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.operators.bash import BashOperator
from airflow.decorators import task

from operators.api_football import FetchFixturesOperator
from operators.api_football_stats import FetchMatchStatsOperator
from operators.api_football_odds import FetchOddsOperator
from operators.api_football_standings import FetchStandingsOperator
from operators.api_football_team_stats import FetchTeamStatsOperator
from operators.api_football_lineups import FetchLineupsOperator
from operators.api_football_player_stats import FetchPlayerStatsOperator
from operators.api_football_topscorers import FetchTopScorersOperator
from operators.api_football_events import FetchMatchEventsOperator
from operators.api_football_topassists import FetchTopAssistsOperator  # <-- NEW

LEAGUES = [144, 61, 78, 203, 2, 3, 88, 140, 135, 39, 94]
SEASONS = [2025]
API_POOL = "api_football_pool"

with DAG(
    dag_id="fixtures_pipeline",
    start_date=datetime(2025, 8, 1),
    schedule_interval="@daily",
    catchup=False,
    max_active_runs=1,
    tags=["football", "fixtures", "lineups", "stats", "odds", "standings", "player_stats", "topscorers", "events", "topassists"],
) as dag:

    start = EmptyOperator(task_id="start")

    fetch_upsert = FetchFixturesOperator(
        task_id="fetch_and_upsert_fixtures",
        leagues=LEAGUES,
        seasons=SEASONS,
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        sleep_sec=0.5,
        retries=2,
        retry_delay=timedelta(minutes=3),
        pool=API_POOL,
    )

    fetch_lineups_missing = FetchLineupsOperator(
        task_id="fetch_lineups_missing_for_finished",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        seasons=SEASONS,
        leagues=LEAGUES,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
        pool=API_POOL,
    )

    fetch_player_stats_missing = FetchPlayerStatsOperator(
        task_id="fetch_player_stats_missing_for_finished",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        seasons=SEASONS,
        leagues=LEAGUES,
        throttle_sec=0.6,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
        pool=API_POOL,
    )

    fetch_topscorers = FetchTopScorersOperator(
        task_id="fetch_topscorers",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        leagues=LEAGUES,
        seasons=SEASONS,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
        pool=API_POOL,
    )

    # NEW: ассистенты
    fetch_topassists = FetchTopAssistsOperator(
        task_id="fetch_topassists_if_schedule_newer",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        api_host="https://v3.football.api-sports.io",
        leagues=LEAGUES,
        seasons=SEASONS,
        finished_only=True,
        min_staleness_minutes=10,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
        pool=API_POOL,
    )

    fetch_odds = FetchOddsOperator(
        task_id="fetch_odds_near_matches",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        season=2025,
        leagues=LEAGUES,
        lookahead_days=7,
        lookback_days=0,
        min_bookmakers=3,
        top_n_bookmakers=5,
        throttle_sec=0.5,
        retries=1,
        retry_delay=timedelta(minutes=2),
        pool=API_POOL,
    )

    fetch_stats = FetchMatchStatsOperator(
        task_id="fetch_match_stats_finished_only",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        throttle_sec=0.5,
        retries=1,
        retry_delay=timedelta(minutes=2),
        pool=API_POOL,
    )

    fetch_events_missing_last_season = FetchMatchEventsOperator(
        task_id="fetch_events_missing_last_season",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        throttle_sec=0.7,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
        pool=API_POOL,
    )

    fetch_standings = FetchStandingsOperator(
        task_id="update_standings_if_schedule_newer",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        leagues=LEAGUES,
        finished_only=True,
        min_staleness_minutes=10,
        throttle_sec=0.4,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
        pool=API_POOL,
    )

    fetch_team_stats = FetchTeamStatsOperator(
        task_id="fetch_team_stats_if_schedule_newer",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        seasons=SEASONS,
        leagues=LEAGUES,
        finished_only=True,
        min_staleness_minutes=10,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
        pool=API_POOL,
    )

    @task
    def fanout_ids(fixtures: list[int]) -> list[int]:
        return fixtures or []

    ids = fanout_ids(fetch_upsert.output)

    end = EmptyOperator(task_id="end")

    predict_models = BashOperator(
        task_id="predict_models_next_3_days",
        bash_command=(
            "python /opt/airflow/model/fill_match_predictions.py "
            "--mode both "
            "--date-from {{ ds }} "
            "--date-to {{ macros.ds_add(ds, 3) }}"
        ),
    )

    start >> fetch_upsert

    fetch_upsert >> [
        fetch_lineups_missing,
        fetch_player_stats_missing,
        fetch_topscorers,
        fetch_topassists,                 # <-- NEW in fanout
        fetch_odds,
        fetch_stats,
        fetch_events_missing_last_season,
        fetch_standings,
        fetch_team_stats,
    ]

    [
        fetch_lineups_missing,
        fetch_player_stats_missing,
        fetch_topscorers,
        fetch_topassists,                 # <-- NEW in join
        fetch_stats,
        fetch_events_missing_last_season,
        fetch_odds,
        fetch_standings,
        fetch_team_stats,
    ] >> ids >> predict_models >> end
