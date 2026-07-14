from __future__ import annotations

import json
import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from frontend.model.config import DB_URL


CANDIDATE_PATH = Path("tmp/outcome_v3_candidate_dataset.csv")
OUT_JSON = Path("tmp/outcome_error_case_studies_epl.json")
OUT_CSV = Path("tmp/outcome_error_case_studies_epl.csv")

LEAGUE_ID = 39
LEAGUE_NAME = "Premier League"
TOP_N = 30


def _load_candidates() -> pd.DataFrame:
    df = pd.read_csv(CANDIDATE_PATH, parse_dates=["date_utc"])
    df = df[df["league_id"] == LEAGUE_ID].copy()
    df = df[(df["outcome"] == "Home") & (df["odds"].between(1.55, 4.00))]
    df = df.sort_values(["ev", "edge"], ascending=False).reset_index(drop=True)
    return df


def _query_schedule_and_lineups(fixture_ids: list[int], min_date: pd.Timestamp, max_date: pd.Timestamp) -> tuple[pd.DataFrame, pd.DataFrame]:
    eng = create_engine(DB_URL)
    with eng.connect() as conn:
        fixtures_df = pd.read_sql(
            text(
                """
                select
                    fixture_id,
                    date,
                    round,
                    season,
                    home_team_id,
                    home_team,
                    away_team_id,
                    away_team,
                    home_goals,
                    away_goals
                from football.api_football_schedule
                where league_id = :league_id
                  and fixture_id = any(:fixture_ids)
                """
            ),
            conn,
            params={"league_id": LEAGUE_ID, "fixture_ids": fixture_ids},
        )

        lineup_hist_df = pd.read_sql(
            text(
                """
                with lineups as (
                    select
                        l.fixture_id,
                        l.team_id,
                        max(l.team_name) as team_name,
                        max(l.coach_name) as coach_name,
                        max(l.formation) as formation
                    from football.api_football_lineups l
                    group by 1, 2
                )
                select
                    s.fixture_id,
                    s.date,
                    l.team_id,
                    l.team_name,
                    l.coach_name,
                    l.formation
                from football.api_football_schedule s
                join lineups l on l.fixture_id = s.fixture_id
                where s.league_id = :league_id
                  and s.date between :min_date and :max_date
                order by l.team_id, s.date, s.fixture_id
                """
            ),
            conn,
            params={
                "league_id": LEAGUE_ID,
                "min_date": min_date - pd.Timedelta(days=120),
                "max_date": max_date + pd.Timedelta(days=1),
            },
        )

    return fixtures_df, lineup_hist_df


def _build_team_context(lineup_hist_df: pd.DataFrame) -> pd.DataFrame:
    df = lineup_hist_df.copy()
    df["date"] = pd.to_datetime(df["date"])
    df = df.sort_values(["team_id", "date", "fixture_id"]).reset_index(drop=True)

    grp = df.groupby("team_id", sort=False)
    df["prev_coach"] = grp["coach_name"].shift(1)
    df["prev_formation"] = grp["formation"].shift(1)
    df["prev_date"] = grp["date"].shift(1)
    df["coach_changed_now"] = (df["coach_name"] != df["prev_coach"]) & df["prev_coach"].notna()
    df["formation_changed_now"] = (df["formation"] != df["prev_formation"]) & df["prev_formation"].notna()
    df["days_since_prev"] = (df["date"] - df["prev_date"]).dt.days

    df["coach_change_date"] = df["date"].where(df["coach_changed_now"])
    df["last_coach_change_date"] = grp["coach_change_date"].ffill()
    df["days_since_coach_change"] = (df["date"] - df["last_coach_change_date"]).dt.days
    df["recent_coach_change_30d"] = df["days_since_coach_change"].between(0, 30, inclusive="both")
    df["recent_coach_change_60d"] = df["days_since_coach_change"].between(0, 60, inclusive="both")

    stable_prev = []
    for _, g in df.groupby("team_id", sort=False):
        forms = g["formation"].tolist()
        flags = []
        for i in range(len(forms)):
            if i < 3:
                flags.append(False)
                continue
            prev3 = forms[i - 3 : i]
            flags.append(len(set(prev3)) == 1)
        stable_prev.extend(flags)
    df["prev_formation_was_stable"] = stable_prev
    df["formation_surprise"] = df["formation_changed_now"] & df["prev_formation_was_stable"]

    return df[
        [
            "fixture_id",
            "team_id",
            "team_name",
            "coach_name",
            "formation",
            "prev_coach",
            "prev_formation",
            "coach_changed_now",
            "formation_changed_now",
            "recent_coach_change_30d",
            "recent_coach_change_60d",
            "formation_surprise",
            "days_since_coach_change",
        ]
    ].copy()


def _merge_case_data(candidates: pd.DataFrame, fixtures_df: pd.DataFrame, team_ctx: pd.DataFrame) -> pd.DataFrame:
    cases = candidates.head(TOP_N).copy()
    fixtures_df["date"] = pd.to_datetime(fixtures_df["date"])
    cases = cases.merge(fixtures_df, left_on="fixture_id", right_on="fixture_id", how="left")

    home_ctx = team_ctx.add_prefix("home_")
    away_ctx = team_ctx.add_prefix("away_")
    cases = cases.merge(
        home_ctx,
        left_on=["fixture_id", "home_team_id"],
        right_on=["home_fixture_id", "home_team_id"],
        how="left",
    )
    cases = cases.merge(
        away_ctx,
        left_on=["fixture_id", "away_team_id"],
        right_on=["away_fixture_id", "away_team_id"],
        how="left",
    )

    cases["score"] = cases["home_goals"].astype("Int64").astype(str) + ":" + cases["away_goals"].astype("Int64").astype(str)
    cases["won_flag"] = cases["actual_win"].map({1: "WIN", 0: "LOSS"})

    cases["context_shock"] = (
        cases["home_recent_coach_change_30d"].fillna(False)
        | cases["away_recent_coach_change_30d"].fillna(False)
        | cases["home_formation_surprise"].fillna(False)
        | cases["away_formation_surprise"].fillna(False)
    )
    cases["shock_reason"] = ""
    for prefix, side in [("home_", "home"), ("away_", "away")]:
        mask = cases[f"{prefix}recent_coach_change_30d"].fillna(False)
        cases.loc[mask, "shock_reason"] += f"{side}:recent coach change; "
        mask = cases[f"{prefix}formation_surprise"].fillna(False)
        cases.loc[mask, "shock_reason"] += f"{side}:formation surprise; "
    cases["shock_reason"] = cases["shock_reason"].str.strip()
    cases["case_type"] = cases.apply(
        lambda r: "context_shock" if (r["won_flag"] == "LOSS" and r["context_shock"]) else (
            "clean_model_error" if r["won_flag"] == "LOSS" else "correct_call"
        ),
        axis=1,
    )

    keep = [
        "date_utc",
        "round",
        "season",
        "home_team",
        "away_team",
        "score",
        "outcome",
        "odds",
        "p_model",
        "p_market",
        "edge",
        "ev",
        "draw_risk_score",
        "won_flag",
        "case_type",
        "shock_reason",
        "home_coach_name",
        "away_coach_name",
        "home_formation",
        "away_formation",
        "home_prev_coach",
        "away_prev_coach",
        "home_prev_formation",
        "away_prev_formation",
    ]
    return cases[keep].sort_values(["ev", "edge"], ascending=False).reset_index(drop=True)


def _build_summary(cases: pd.DataFrame) -> dict:
    losses = cases[cases["won_flag"] == "LOSS"].copy()
    context_losses = losses[losses["case_type"] == "context_shock"]
    clean_losses = losses[losses["case_type"] == "clean_model_error"]

    return {
        "league": LEAGUE_NAME,
        "top_n": int(len(cases)),
        "wins": int((cases["won_flag"] == "WIN").sum()),
        "losses": int((cases["won_flag"] == "LOSS").sum()),
        "losses_with_context_shock": int(len(context_losses)),
        "losses_without_context_shock": int(len(clean_losses)),
        "examples_context_shock": context_losses.head(8)[
            ["date_utc", "home_team", "away_team", "score", "odds", "p_model", "p_market", "edge", "ev", "shock_reason"]
        ].to_dict(orient="records"),
        "examples_clean_model_error": clean_losses.head(8)[
            ["date_utc", "home_team", "away_team", "score", "odds", "p_model", "p_market", "edge", "ev"]
        ].to_dict(orient="records"),
    }


def main() -> None:
    candidates = _load_candidates()
    min_date = pd.to_datetime(candidates["date_utc"].min())
    max_date = pd.to_datetime(candidates["date_utc"].max())
    fixtures_df, lineup_hist_df = _query_schedule_and_lineups(
        fixture_ids=candidates["fixture_id"].astype(int).unique().tolist(),
        min_date=min_date,
        max_date=max_date,
    )
    team_ctx = _build_team_context(lineup_hist_df)
    cases = _merge_case_data(candidates, fixtures_df, team_ctx)
    summary = _build_summary(cases)

    OUT_CSV.write_text(cases.to_csv(index=False), encoding="utf-8")
    OUT_JSON.write_text(json.dumps(summary, ensure_ascii=False, indent=2, default=str), encoding="utf-8")

    print(json.dumps(summary, ensure_ascii=False, indent=2, default=str))


if __name__ == "__main__":
    main()
