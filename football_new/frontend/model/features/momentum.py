import numpy as np
import pandas as pd


def build_momentum_features(schedule: pd.DataFrame, short_span: int = 3, long_span: int = 8) -> pd.DataFrame:
    df = schedule.sort_values("date_utc").copy()
    outputs = []

    for side in ["home", "away"]:
        team_col = f"{side}_team_id"
        gf_col = f"{side}_goals"
        ga_col = f"{'away' if side == 'home' else 'home'}_goals"

        base = df[["fixture_id", "date_utc", team_col, gf_col, ga_col]].copy()
        base = base.rename(columns={
            team_col: "team_id",
            gf_col: "goals_for",
            ga_col: "goals_against",
        })
        base["goal_diff"] = base["goals_for"] - base["goals_against"]

        enriched_groups = []
        for team_id, g in base.groupby("team_id"):
            g = g.sort_values("date_utc").copy()
            g["ewm_goals_for_short"] = g["goals_for"].shift(1).ewm(span=short_span, adjust=False).mean()
            g["ewm_goals_against_short"] = g["goals_against"].shift(1).ewm(span=short_span, adjust=False).mean()
            g["ewm_goal_diff_short"] = g["goal_diff"].shift(1).ewm(span=short_span, adjust=False).mean()

            g["ewm_goals_for_long"] = g["goals_for"].shift(1).ewm(span=long_span, adjust=False).mean()
            g["ewm_goals_against_long"] = g["goals_against"].shift(1).ewm(span=long_span, adjust=False).mean()
            g["ewm_goal_diff_long"] = g["goal_diff"].shift(1).ewm(span=long_span, adjust=False).mean()

            g["recent_over_rate"] = (
                (g["goals_for"] + g["goals_against"] >= 3)
                .shift(1)
                .rolling(6, min_periods=1)
                .mean()
            )
            enriched_groups.append(g)
        enriched = pd.concat(enriched_groups, ignore_index=True)
        cols = [
            "fixture_id",
            "ewm_goals_for_short",
            "ewm_goals_against_short",
            "ewm_goal_diff_short",
            "ewm_goals_for_long",
            "ewm_goals_against_long",
            "ewm_goal_diff_long",
            "recent_over_rate",
        ]
        enriched = enriched[cols]
        rename_map = {c: f"{side}_mom_{c}" for c in cols if c != "fixture_id"}
        enriched = enriched.rename(columns=rename_map)
        outputs.append(enriched)

    res = outputs[0].merge(outputs[1], on="fixture_id", how="outer")
    return res
