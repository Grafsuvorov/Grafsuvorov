from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.operators.bash import BashOperator
from airflow.decorators import task

from operators.api_football import FetchFixturesOperator
from operators.api_football_stats import FetchMatchStatsOperator
from operators.api_football_standings import FetchStandingsOperator
from operators.api_football_lineups import FetchLineupsOperator
from operators.api_football_player_stats import FetchPlayerStatsOperator
from operators.api_football_topscorers import FetchTopScorersOperator
from operators.api_football_events import FetchMatchEventsOperator
from operators.api_football_topassists import FetchTopAssistsOperator


LEAGUES = [1, 4, 960, 29, 30, 31, 32, 33, 34, 37]
ACTIVE_SEASONS = [2024, 2026]
HISTORICAL_SEASONS = [2020, 2022, 2023]


def build_assets_task(task_id: str) -> BashOperator:
    return BashOperator(
        task_id=task_id,
        bash_command=(
            "export API_FOOTBALL_KEY='{{ var.value.API_FOOTBALL_KEY }}' && "
            "export DATABASE_URL='postgresql+psycopg2://postgres:0506@host.docker.internal:5432/dwh' && "
            "python /opt/airflow/scripts/fetch_international_assets.py --only all"
        ),
    )


with DAG(
    dag_id="national_teams_pipeline",
    start_date=datetime(2026, 3, 1),
    schedule_interval="@daily",
    catchup=False,
    max_active_runs=1,
    tags=["football", "national-teams", "world-cup", "euro"],
) as dag:
    start = EmptyOperator(task_id="start")

    fetch_upsert = FetchFixturesOperator(
        task_id="fetch_and_upsert_national_team_fixtures",
        leagues=LEAGUES,
        seasons=ACTIVE_SEASONS,
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        sleep_sec=0.5,
        retries=2,
        retry_delay=timedelta(minutes=3),
    )

    fetch_lineups_missing = FetchLineupsOperator(
        task_id="fetch_lineups_missing_for_national_team_matches",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        seasons=ACTIVE_SEASONS,
        leagues=LEAGUES,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    fetch_player_stats_missing = FetchPlayerStatsOperator(
        task_id="fetch_player_stats_missing_for_national_team_matches",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        seasons=ACTIVE_SEASONS,
        leagues=LEAGUES,
        throttle_sec=0.6,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    fetch_topscorers = FetchTopScorersOperator(
        task_id="fetch_national_team_topscorers",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        leagues=LEAGUES,
        seasons=ACTIVE_SEASONS,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    fetch_topassists = FetchTopAssistsOperator(
        task_id="fetch_national_team_topassists",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        api_host="https://v3.football.api-sports.io",
        leagues=LEAGUES,
        seasons=ACTIVE_SEASONS,
        finished_only=True,
        min_staleness_minutes=10,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    fetch_stats = FetchMatchStatsOperator(
        task_id="fetch_national_team_match_stats_finished_only",
        seasons=ACTIVE_SEASONS,
        leagues=LEAGUES,
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        throttle_sec=0.5,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    fetch_events_missing = FetchMatchEventsOperator(
        task_id="fetch_national_team_events_missing",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        seasons=ACTIVE_SEASONS,
        leagues=LEAGUES,
        throttle_sec=0.7,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    fetch_standings = FetchStandingsOperator(
        task_id="update_national_team_standings_if_schedule_newer",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        leagues=LEAGUES,
        finished_only=True,
        min_staleness_minutes=10,
        throttle_sec=0.4,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    fetch_assets = build_assets_task("fetch_national_team_assets")

    @task
    def fanout_ids(fixtures: list[int]) -> list[int]:
        return fixtures or []

    ids = fanout_ids(fetch_upsert.output)
    end = EmptyOperator(task_id="end")

    start >> fetch_upsert

    fetch_upsert >> [
        fetch_lineups_missing,
        fetch_player_stats_missing,
        fetch_topscorers,
        fetch_topassists,
        fetch_stats,
        fetch_events_missing,
        fetch_standings,
    ]

    [
        fetch_lineups_missing,
        fetch_player_stats_missing,
        fetch_topscorers,
        fetch_topassists,
        fetch_stats,
        fetch_events_missing,
        fetch_standings,
    ] >> ids >> fetch_assets >> end


with DAG(
    dag_id="national_teams_backfill",
    start_date=datetime(2026, 3, 1),
    schedule_interval=None,
    catchup=False,
    max_active_runs=1,
    tags=["football", "national-teams", "backfill"],
) as backfill_dag:
    backfill_start = EmptyOperator(task_id="start")

    backfill_fetch_upsert = FetchFixturesOperator(
        task_id="fetch_and_upsert_historical_national_team_fixtures",
        leagues=LEAGUES,
        seasons=HISTORICAL_SEASONS,
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        sleep_sec=0.5,
        retries=2,
        retry_delay=timedelta(minutes=3),
    )

    backfill_lineups = FetchLineupsOperator(
        task_id="fetch_lineups_missing_for_historical_national_team_matches",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        seasons=HISTORICAL_SEASONS,
        leagues=LEAGUES,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    backfill_player_stats = FetchPlayerStatsOperator(
        task_id="fetch_player_stats_missing_for_historical_national_team_matches",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        seasons=HISTORICAL_SEASONS,
        leagues=LEAGUES,
        throttle_sec=0.6,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    backfill_topscorers = FetchTopScorersOperator(
        task_id="fetch_historical_national_team_topscorers",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        leagues=LEAGUES,
        seasons=HISTORICAL_SEASONS,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    backfill_topassists = FetchTopAssistsOperator(
        task_id="fetch_historical_national_team_topassists",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        api_host="https://v3.football.api-sports.io",
        leagues=LEAGUES,
        seasons=HISTORICAL_SEASONS,
        finished_only=True,
        min_staleness_minutes=10,
        throttle_sec=0.5,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    backfill_stats = FetchMatchStatsOperator(
        task_id="fetch_historical_national_team_match_stats_finished_only",
        seasons=HISTORICAL_SEASONS,
        leagues=LEAGUES,
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        throttle_sec=0.5,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    backfill_events = FetchMatchEventsOperator(
        task_id="fetch_historical_national_team_events_missing",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        seasons=HISTORICAL_SEASONS,
        leagues=LEAGUES,
        throttle_sec=0.7,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    backfill_standings = FetchStandingsOperator(
        task_id="update_historical_national_team_standings_if_schedule_newer",
        postgres_conn_id="dwh_postgres",
        api_variable_key="API_FOOTBALL_KEY",
        leagues=LEAGUES,
        finished_only=True,
        min_staleness_minutes=10,
        throttle_sec=0.4,
        per_call_retries=3,
        retries=1,
        retry_delay=timedelta(minutes=2),
    )

    backfill_assets = build_assets_task("fetch_historical_national_team_assets")
    backfill_end = EmptyOperator(task_id="end")

    backfill_start >> backfill_fetch_upsert
    backfill_fetch_upsert >> [
        backfill_lineups,
        backfill_player_stats,
        backfill_topscorers,
        backfill_topassists,
        backfill_stats,
        backfill_events,
        backfill_standings,
    ] >> backfill_assets >> backfill_end
