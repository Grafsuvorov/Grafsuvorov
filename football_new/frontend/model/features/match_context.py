import numpy as np
import pandas as pd


def _team_match_context(schedule: pd.DataFrame, lookback: int = 5) -> pd.DataFrame:
    base = schedule.sort_values("date_utc").copy()
    rows = []

    for team_col, opp_col, is_home in [
        ("home_team_id", "away_team_id", 1),
        ("away_team_id", "home_team_id", 0),
    ]:
        side = base[["fixture_id", "date_utc", "season", "league_id", team_col, opp_col, "home_goals", "away_goals"]].copy()
        side = side.rename(columns={team_col: "team_id", opp_col: "opp_team_id"})
        side["is_home"] = is_home
        side["goals_for"] = np.where(is_home == 1, side["home_goals"], side["away_goals"])
        side["goals_against"] = np.where(is_home == 1, side["away_goals"], side["home_goals"])
        side["points"] = np.where(
            side["goals_for"].isna() | side["goals_against"].isna(),
            np.nan,
            np.where(side["goals_for"] > side["goals_against"], 3.0, np.where(side["goals_for"] == side["goals_against"], 1.0, 0.0)),
        )
        rows.append(side)

    team_matches = pd.concat(rows, ignore_index=True).sort_values(["team_id", "date_utc", "fixture_id"]).reset_index(drop=True)

    def _build_group(g: pd.DataFrame) -> pd.DataFrame:
        g = g.sort_values("date_utc").copy()
        prev_dt = g["date_utc"].shift(1)
        g["mc_rest_days"] = (g["date_utc"] - prev_dt).dt.days.astype(float)
        dates = pd.to_datetime(g["date_utc"]).tolist()
        last8 = []
        last14 = []
        for i, current in enumerate(dates):
            prev_dates = dates[max(0, i - lookback):i]
            if not prev_dates:
                last8.append(0.0)
                last14.append(0.0)
                continue
            deltas = np.array([(current - d).days for d in prev_dates], dtype=float)
            last8.append(float(np.sum(deltas <= 8)))
            last14.append(float(np.sum(deltas <= 14)))
        g["mc_matches_last8d"] = last8
        g["mc_matches_last14d"] = last14
        g["mc_points_last5"] = g["points"].shift(1).rolling(lookback, min_periods=1).mean()
        g["mc_goal_diff_last5"] = (g["goals_for"] - g["goals_against"]).shift(1).rolling(lookback, min_periods=1).mean()
        g["mc_points_season_avg"] = g["points"].shift(1).expanding(min_periods=3).mean()
        g["mc_home_share_last5"] = g["is_home"].shift(1).rolling(lookback, min_periods=1).mean()
        return g

    team_matches = (
        team_matches.groupby(["season", "league_id", "team_id"], group_keys=False)[team_matches.columns]
        .apply(_build_group)
        .reset_index(drop=True)
    )
    return team_matches


def build_match_context_features(schedule: pd.DataFrame, lookback: int = 5) -> pd.DataFrame:
    """
    Context features for v2:
    - rest / congestion
    - recent points and goal-diff form
    - season strength proxy through pre-match rolling points
    - recent home/away balance
    - recent H2H freshness / balance
    """
    df = schedule.sort_values("date_utc").copy()
    team_ctx = _team_match_context(df, lookback=lookback)

    home = team_ctx[team_ctx["is_home"] == 1][
        [
            "fixture_id",
            "mc_rest_days",
            "mc_matches_last8d",
            "mc_matches_last14d",
            "mc_points_last5",
            "mc_goal_diff_last5",
            "mc_points_season_avg",
            "mc_home_share_last5",
        ]
    ].rename(
        columns={
            "mc_rest_days": "home_rest_days",
            "mc_matches_last8d": "home_matches_last8d",
            "mc_matches_last14d": "home_matches_last14d",
            "mc_points_last5": "home_points_last5",
            "mc_goal_diff_last5": "home_goal_diff_last5",
            "mc_points_season_avg": "home_points_season_avg",
            "mc_home_share_last5": "home_home_share_last5",
        }
    )

    away = team_ctx[team_ctx["is_home"] == 0][
        [
            "fixture_id",
            "mc_rest_days",
            "mc_matches_last8d",
            "mc_matches_last14d",
            "mc_points_last5",
            "mc_goal_diff_last5",
            "mc_points_season_avg",
            "mc_home_share_last5",
        ]
    ].rename(
        columns={
            "mc_rest_days": "away_rest_days",
            "mc_matches_last8d": "away_matches_last8d",
            "mc_matches_last14d": "away_matches_last14d",
            "mc_points_last5": "away_points_last5",
            "mc_goal_diff_last5": "away_goal_diff_last5",
            "mc_points_season_avg": "away_points_season_avg",
            "mc_home_share_last5": "away_home_share_last5",
        }
    )

    out = df[["fixture_id", "date_utc", "home_team_id", "away_team_id"]].copy()
    out = out.merge(home, on="fixture_id", how="left")
    out = out.merge(away, on="fixture_id", how="left")

    recent_h2h = []
    for row in df.itertuples():
        h, a, t = row.home_team_id, row.away_team_id, row.date_utc
        past = df[
            (
                ((df.home_team_id == h) & (df.away_team_id == a))
                | ((df.home_team_id == a) & (df.away_team_id == h))
            )
            & (df.date_utc < t)
        ].tail(5)

        if past.empty:
            recent_h2h.append((row.fixture_id, np.nan, np.nan, 0.0))
            continue

        aligned_diff = np.where(
            past.home_team_id.values == h,
            past.home_goals.values - past.away_goals.values,
            past.away_goals.values - past.home_goals.values,
        )
        h2h_days = float((t - past.iloc[-1].date_utc).days)
        recent_h2h.append(
            (
                row.fixture_id,
                float(np.nanmean(aligned_diff)),
                h2h_days,
                float(len(past)),
            )
        )

    h2h_df = pd.DataFrame(
        recent_h2h,
        columns=["fixture_id", "mc_h2h_goal_diff_last5", "mc_h2h_days_since", "mc_h2h_sample"],
    )
    out = out.merge(h2h_df, on="fixture_id", how="left")

    diff_pairs = [
        ("rest_days", "rest_days"),
        ("matches_last8d", "matches_last8d"),
        ("matches_last14d", "matches_last14d"),
        ("points_last5", "points_last5"),
        ("goal_diff_last5", "goal_diff_last5"),
        ("points_season_avg", "points_season_avg"),
    ]
    for base_name, _ in diff_pairs:
        out[f"mc_{base_name}_diff"] = out[f"home_{base_name}"] - out[f"away_{base_name}"]

    out["mc_schedule_pressure_home"] = out["home_matches_last8d"].fillna(0.0) + 0.5 * out["home_matches_last14d"].fillna(0.0)
    out["mc_schedule_pressure_away"] = out["away_matches_last8d"].fillna(0.0) + 0.5 * out["away_matches_last14d"].fillna(0.0)
    out["mc_schedule_pressure_diff"] = out["mc_schedule_pressure_home"] - out["mc_schedule_pressure_away"]
    out["mc_strength_gap"] = out["home_points_season_avg"] - out["away_points_season_avg"]

    return out.drop(columns=["date_utc", "home_team_id", "away_team_id"])
