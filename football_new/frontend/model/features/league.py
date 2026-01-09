import numpy as np
import pandas as pd


def _rolling_with_fallback(series: pd.Series, window: int, min_periods: int) -> pd.Series:
    """Rolling mean that backs off to expanding mean if history is short."""
    roll = series.shift(1).rolling(window, min_periods=min_periods).mean()
    exp = series.shift(1).expanding(min_periods=min_periods).mean()
    return roll.fillna(exp)


def build_league_context_features(schedule: pd.DataFrame, window: int = 60) -> pd.DataFrame:
    """Adds per-league pace/rate features + one-hot league id for the model."""
    if "league_id" not in schedule.columns:
        raise RuntimeError("build_league_context_features(): league_id column missing")

    df = schedule.sort_values("date_utc").copy()
    has_result = df.get("has_result")
    if has_result is None:
        has_result = df[["home_goals", "away_goals"]].notna().all(axis=1)

    df["total_goals"] = np.where(
        has_result,
        df["home_goals"].astype(float) + df["away_goals"].astype(float),
        np.nan,
    )
    df["is_home_win"] = np.where(
        has_result,
        (df["home_goals"].astype(float) > df["away_goals"].astype(float)).astype(float),
        np.nan,
    )
    df["is_draw"] = np.where(
        has_result,
        (df["home_goals"].astype(float) == df["away_goals"].astype(float)).astype(float),
        np.nan,
    )
    df["is_over25"] = np.where(
        has_result,
        (df["home_goals"].astype(float) + df["away_goals"].astype(float) >= 3).astype(float),
        np.nan,
    )

    feats = []
    overall_defaults = {
        "avg_goals": float(np.nanmean(df["total_goals"])) if np.isfinite(np.nanmean(df["total_goals"])) else 2.5,
        "home_win": float(np.nanmean(df["is_home_win"])) if np.isfinite(np.nanmean(df["is_home_win"])) else 0.45,
        "draw_rate": float(np.nanmean(df["is_draw"])) if np.isfinite(np.nanmean(df["is_draw"])) else 0.25,
        "over25": float(np.nanmean(df["is_over25"])) if np.isfinite(np.nanmean(df["is_over25"])) else 0.55,
    }

    for lid, g in df.groupby("league_id"):
        g = g.sort_values("date_utc").copy()
        agg = pd.DataFrame({"fixture_id": g["fixture_id"].values})

        agg["league_avg_total_goals"] = _rolling_with_fallback(
            g["total_goals"], window=window, min_periods=5
        )
        agg["league_home_win_rate"] = _rolling_with_fallback(
            g["is_home_win"], window=window, min_periods=5
        )
        agg["league_draw_rate"] = _rolling_with_fallback(
            g["is_draw"], window=window, min_periods=5
        )
        agg["league_over25_rate"] = _rolling_with_fallback(
            g["is_over25"], window=window, min_periods=5
        )

        agg = agg.fillna({
            "league_avg_total_goals": overall_defaults["avg_goals"],
            "league_home_win_rate": overall_defaults["home_win"],
            "league_draw_rate": overall_defaults["draw_rate"],
            "league_over25_rate": overall_defaults["over25"],
        })
        feats.append(agg)

    ctx = pd.concat(feats, ignore_index=True)

    dummies = pd.get_dummies(df["league_id"].astype(int), prefix="league", dtype=float)
    dummies["fixture_id"] = df["fixture_id"].values

    ctx = ctx.merge(dummies, on="fixture_id", how="left")
    return ctx
