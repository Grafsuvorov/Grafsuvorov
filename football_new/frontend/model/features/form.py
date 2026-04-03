# features/form.py
import pandas as pd
import numpy as np
from config import ROLL_N


def _rolling(series, window, prefix):
    return pd.DataFrame({
        f"{prefix}_mean_{window}": series.shift(1).rolling(window).mean(),
        f"{prefix}_std_{window}": series.shift(1).rolling(window).std(),
        f"{prefix}_ema_{window}": series.shift(1).ewm(span=window, adjust=False).mean(),
    })


def compute_form(schedule: pd.DataFrame) -> pd.DataFrame:
    df = schedule.sort_values("date_utc")
    rows = []

    for side in ["home", "away"]:
        team_col = f"{side}_team_id"
        goals_col = f"{side}_goals"

        for tid, g in df.groupby(team_col):
            g = g.sort_values("date_utc")

            stats = _rolling(
                g[goals_col].astype(float),
                ROLL_N,
                f"{side}_goals"
            )

            out = pd.concat([g[["fixture_id"]], stats], axis=1)
            rows.append(out)

    res = pd.concat(rows, axis=0)
    return res.groupby("fixture_id").first().reset_index()


def build_form_features(schedule: pd.DataFrame, mode="train") -> pd.DataFrame:
    return compute_form(schedule)
