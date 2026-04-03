# features/form_xg.py

import numpy as np
import pandas as pd


def _rolling_with_fallback(series: pd.Series, window: int, min_periods: int = 3) -> pd.Series:
    roll = series.shift(1).rolling(window, min_periods=min_periods).mean()
    exp = series.shift(1).expanding(min_periods=min_periods).mean()
    return roll.fillna(exp)


def build_form_xg_features(
    schedule: pd.DataFrame,
    stats: pd.DataFrame,
    window: int = 5,
) -> pd.DataFrame:
    """
    Team form based on xG and tempo (no leakage):
    - xG for / against
    - shots inside box
    - dangerous attacks
    """

    if stats is None or stats.empty:
        base = pd.DataFrame({"fixture_id": schedule["fixture_id"]})
        for col in [
            "home_xg_for_mean",
            "home_xg_against_mean",
            "home_shots_ib_mean",
            "home_danger_attacks_mean",
            "away_xg_for_mean",
            "away_xg_against_mean",
            "away_shots_ib_mean",
            "away_danger_attacks_mean",
            "xg_for_diff",
            "xg_against_diff",
            "tempo_diff",
        ]:
            base[col] = np.nan
        return base

    required_cols = [
        "fixture_id",
        "team_id",
        "expected_goals",
        "shots_insidebox",
        "dangerous_attacks",
    ]
    if any(col not in stats.columns for col in required_cols):
        stats = stats.copy()
        for col in required_cols:
            if col not in stats.columns:
                stats[col] = np.nan

    # Join schedule + stats (two rows per fixture expected)
    df = schedule.merge(
        stats,
        on="fixture_id",
        how="left",
    ).sort_values("date_utc")

    # Keep only home/away team rows
    df = df[
        (df["team_id"] == df["home_team_id"]) | (df["team_id"] == df["away_team_id"])
    ].copy()

    df["xg_for"] = df["expected_goals"]
    total_xg = df.groupby("fixture_id")["expected_goals"].transform(
        lambda s: s.sum(min_count=1)
    )
    count_xg = df.groupby("fixture_id")["expected_goals"].transform("count")
    df["xg_against"] = np.where(count_xg >= 2, total_xg - df["xg_for"], np.nan)

    outputs = []

    for side in ["home", "away"]:
        team_col = f"{side}_team_id"

        base = df[df["team_id"] == df[team_col]].copy()
        base = base.sort_values("date_utc")

        base[f"{side}_xg_for_mean"] = _rolling_with_fallback(base["xg_for"], window)
        base[f"{side}_xg_against_mean"] = _rolling_with_fallback(base["xg_against"], window)

        base[f"{side}_shots_ib_mean"] = _rolling_with_fallback(
            base["shots_insidebox"], window
        )
        base[f"{side}_danger_attacks_mean"] = _rolling_with_fallback(
            base["dangerous_attacks"], window
        )

        out_cols = [
            "fixture_id",
            f"{side}_xg_for_mean",
            f"{side}_xg_against_mean",
            f"{side}_shots_ib_mean",
            f"{side}_danger_attacks_mean",
        ]

        outputs.append(base[out_cols])

    if not outputs:
        base = pd.DataFrame({"fixture_id": schedule["fixture_id"]})
        for col in [
            "home_xg_for_mean",
            "home_xg_against_mean",
            "home_shots_ib_mean",
            "home_danger_attacks_mean",
            "away_xg_for_mean",
            "away_xg_against_mean",
            "away_shots_ib_mean",
            "away_danger_attacks_mean",
            "xg_for_diff",
            "xg_against_diff",
            "tempo_diff",
        ]:
            base[col] = np.nan
        return base

    res = outputs[0].merge(outputs[1], on="fixture_id", how="outer")

    # Differentials
    res["xg_for_diff"] = res["home_xg_for_mean"] - res["away_xg_for_mean"]
    res["xg_against_diff"] = res["away_xg_against_mean"] - res["home_xg_against_mean"]
    res["form_xg_tempo_diff"] = (
        res["home_danger_attacks_mean"] - res["away_danger_attacks_mean"]
    )

    return res
