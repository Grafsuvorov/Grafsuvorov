# Python 3.9
# FULL pre-match dataset builder (TRAIN = INFERENCE)
# NO LEAKAGE

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text
from typing import List

from config import DB_URL, LEAGUE_ID_TO_UNDERSTAT, UNDERSTAT_MIN_SEASON
from features.injuries import compute_injury_features
from features.lineup_strength import build_lineup_strength_features
from features.player_contribution import (
    add_player_contribution_system_features,
    build_player_contribution_features,
)
LEAGUE_IDS = [39, 61, 78, 135, 140]
STAT_COLS = [
    "tackles",
    "goals_prevented",
    "expected_goals",
    "total_shots",
    "passes_accurate",
    "shots_off_goal",
    "shots_insidebox",
    "passes",
    "fouls",
    "red_cards",
    "possession",
    "dangerous_attacks",
    "yellow_cards",
    "offsides",
    "corners",
    "shots_on_goal",
    "saves",
    "blocked_shots",
    "passes_percentage",
    "shots_outsidebox",
    "attacks",
]

UNDERSTAT_METRICS = [
    "pts",
    "scored",
    "missed",
    "xg",
    "xga",
    "npxg",
    "npxga",
    "npxgd",
    "xpts",
    "deep",
    "deep_allowed",
    "ppda",
    "ppda_allowed",
]

UNDERSTAT_OVERPERF_METRICS = [
    "goal_minus_xg",
    "goal_minus_npxg",
    "goal_against_minus_xga",
    "goal_against_minus_npxga",
]


# =========================================================
# BASE SCHEDULE
# =========================================================
def load_schedule(engine):
    return pd.read_sql(
        text("""
            SELECT
                fixture_id,
                date::timestamp AS date_utc,
                season,
                league_id,
                home_team_id,
                away_team_id,
                home_goals,
                away_goals
            FROM football.api_football_schedule
            WHERE league_id IN :lids
            ORDER BY date
        """),
        engine,
        params={"lids": tuple(LEAGUE_IDS)},
    )


def load_match_stats(engine, fixture_ids: List[int]):
    if not fixture_ids:
        return pd.DataFrame()

    cols_sql = ",".join(STAT_COLS)
    return pd.read_sql(
        text(f"""
            SELECT
                fixture_id,
                team_id,
                {cols_sql}
            FROM football.api_football_match_stats
            WHERE fixture_id = ANY(:ids)
        """),
        engine,
        params={"ids": fixture_ids},
    )


def load_odds(engine, fixture_ids: List[int]):
    if not fixture_ids:
        return pd.DataFrame()

    cols = [
        "fixture_id",
        "n_bookmakers",
        "avg_odds_home",
        "avg_odds_draw",
        "avg_odds_away",
        "avg_odds_over25",
        "avg_odds_under25",
        "p_home_norm",
        "p_draw_norm",
        "p_away_norm",
        "overround_1x2",
    ]
    df = pd.read_sql(
        text(f"""
            SELECT {",".join(cols)}
            FROM football.v_ml_epl_training
            WHERE fixture_id = ANY(:ids)
        """),
        engine,
        params={"ids": fixture_ids},
    )

    if "avg_odds_over25" in df.columns and "avg_odds_under25" in df.columns:
        imp_over = 1.0 / df["avg_odds_over25"].replace(0, np.nan)
        imp_under = 1.0 / df["avg_odds_under25"].replace(0, np.nan)
        overround = imp_over + imp_under
        df["p_over_mkt"] = np.where(overround > 0, imp_over / overround, np.nan)

    return df


def load_injuries(engine):
    try:
        return pd.read_sql(
            text(
                """
                SELECT *
                FROM football.api_football_injuries
                """
            ),
            engine,
        )
    except Exception:
        return pd.DataFrame()


def load_understat_team_history(engine, min_season: int = UNDERSTAT_MIN_SEASON):
    history = pd.read_sql(
        text(
            """
            SELECT
                league_code,
                season,
                team_id AS understat_team_id,
                match_dt_utc::timestamp AS date_utc,
                h_a,
                pts,
                scored,
                missed,
                xg::double precision AS xg,
                xga::double precision AS xga,
                npxg::double precision AS npxg,
                npxga::double precision AS npxga,
                npxgd::double precision AS npxgd,
                xpts::double precision AS xpts,
                deep::double precision AS deep,
                deep_allowed::double precision AS deep_allowed,
                CASE
                    WHEN COALESCE(ppda_def, 0) = 0 THEN NULL
                    ELSE ppda_att::double precision / NULLIF(ppda_def, 0)
                END AS ppda,
                CASE
                    WHEN COALESCE(ppda_allowed_def, 0) = 0 THEN NULL
                    ELSE ppda_allowed_att::double precision / NULLIF(ppda_allowed_def, 0)
                END AS ppda_allowed
            FROM football.understat_league_team_history
            WHERE season >= :min_season
            """
        ),
        engine,
        params={"min_season": int(min_season)},
    )
    if history.empty:
        return history

    team_map = pd.read_sql(
        text(
            """
            SELECT
                season,
                league_name,
                api_team_id,
                understat_team_id
            FROM football.team_cross_source_map
            WHERE season >= :min_season
              AND api_team_id IS NOT NULL
              AND understat_team_id IS NOT NULL
            """
        ),
        engine,
        params={"min_season": int(min_season)},
    )
    if team_map.empty:
        return pd.DataFrame()

    league_name_map = {
        code: name
        for name, code in {
            "Premier League": "EPL",
            "Ligue 1": "Ligue_1",
            "Bundesliga": "Bundesliga",
            "Serie A": "Serie_A",
            "La Liga": "La_liga",
        }.items()
    }

    history["league_name"] = history["league_code"].map(league_name_map)
    history = history.dropna(subset=["league_name"]).copy()
    history["date_utc"] = pd.to_datetime(history["date_utc"], utc=True, errors="coerce")

    team_map = (
        team_map.sort_values(["season", "league_name", "api_team_id", "understat_team_id"])
        .drop_duplicates(subset=["season", "league_name", "understat_team_id"], keep="first")
        .copy()
    )

    merged = history.merge(
        team_map,
        on=["season", "league_name", "understat_team_id"],
        how="inner",
    )
    if merged.empty:
        return merged

    merged = merged.rename(columns={"api_team_id": "team_id"})
    merged["goal_minus_xg"] = pd.to_numeric(merged["scored"], errors="coerce") - pd.to_numeric(merged["xg"], errors="coerce")
    merged["goal_minus_npxg"] = pd.to_numeric(merged["scored"], errors="coerce") - pd.to_numeric(merged["npxg"], errors="coerce")
    merged["goal_against_minus_xga"] = pd.to_numeric(merged["missed"], errors="coerce") - pd.to_numeric(merged["xga"], errors="coerce")
    merged["goal_against_minus_npxga"] = pd.to_numeric(merged["missed"], errors="coerce") - pd.to_numeric(merged["npxga"], errors="coerce")
    return merged.sort_values(["team_id", "date_utc"]).reset_index(drop=True)


# =========================================================
# TARGETS
# =========================================================
def build_targets(df):
    known = df["home_goals"].notna() & df["away_goals"].notna()
    df["has_result"] = known

    df["target_result"] = np.where(
        known,
        np.sign(df["home_goals"] - df["away_goals"]),
        np.nan,
    )

    df["target_over25"] = np.where(
        known,
        (df["home_goals"] + df["away_goals"] >= 3).astype(int),
        np.nan,
    )

    return df


# =========================================================
# TEAM GOALS FORM
# =========================================================
def build_team_form(df, window=5):
    rows = []

    for side in ["home", "away"]:
        t = (
            df[[
                "fixture_id",
                "date_utc",
                f"{side}_team_id",
                "home_goals",
                "away_goals",
            ]]
            .rename(columns={f"{side}_team_id": "team_id"})
            .copy()
        )

        t["goals_for"] = np.where(side == "home", t["home_goals"], t["away_goals"])
        t["goals_against"] = np.where(side == "home", t["away_goals"], t["home_goals"])

        t = t.sort_values("date_utc")

        t["avg_goals_for"] = (
            t.groupby("team_id")["goals_for"]
            .apply(lambda s: s.shift(1).rolling(window).mean())
            .reset_index(level=0, drop=True)
        )

        t["avg_goals_against"] = (
            t.groupby("team_id")["goals_against"]
            .apply(lambda s: s.shift(1).rolling(window).mean())
            .reset_index(level=0, drop=True)
        )

        t = t[["fixture_id", "avg_goals_for", "avg_goals_against"]]
        t.columns = [
            "fixture_id",
            f"{side}_avg_goals_for",
            f"{side}_avg_goals_against",
        ]

        rows.append(t)

    return rows[0].merge(rows[1], on="fixture_id", how="left")


def build_match_stats_features(sched: pd.DataFrame, engine, short_window: int = 3, long_window: int = 8) -> pd.DataFrame:
    stats = load_match_stats(engine, sched["fixture_id"].tolist())
    if stats.empty:
        return pd.DataFrame({"fixture_id": []})

    stats = stats.merge(
        sched[["fixture_id", "date_utc"]],
        on="fixture_id",
        how="left",
    )

    feature_cols = []
    for col in STAT_COLS:
        feature_cols.append(f"{col}_ma_short")
        feature_cols.append(f"{col}_ma_long")

    grouped = []
    for team_id, g in stats.groupby("team_id"):
        g = g.sort_values("date_utc").copy()
        for col in STAT_COLS:
            g[f"{col}_ma_short"] = g[col].shift(1).rolling(short_window, min_periods=1).mean()
            g[f"{col}_ma_long"] = g[col].shift(1).rolling(long_window, min_periods=1).mean()
        grouped.append(g[["fixture_id", "team_id"] + feature_cols])

    feats = pd.concat(grouped, ignore_index=True)

    def _merge_side(prefix: str, team_col: str):
        tmp = sched[["fixture_id", team_col]].merge(
            feats,
            left_on=["fixture_id", team_col],
            right_on=["fixture_id", "team_id"],
            how="left",
        )
        tmp = tmp.drop(columns=[team_col, "team_id"])
        tmp = tmp.rename(columns=lambda c: c if c == "fixture_id" else f"{prefix}_{c}")
        return tmp

    home_feats = _merge_side("home_stat", "home_team_id")
    away_feats = _merge_side("away_stat", "away_team_id")
    return home_feats.merge(away_feats, on="fixture_id", how="left")


def build_understat_features(
    sched: pd.DataFrame,
    engine,
    windows=(3, 5, 10),
    min_season: int = UNDERSTAT_MIN_SEASON,
) -> pd.DataFrame:
    sched = sched.copy()
    sched["date_utc"] = pd.to_datetime(sched["date_utc"], utc=True, errors="coerce")

    hist = load_understat_team_history(engine, min_season=min_season)
    if hist.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    hist = hist.sort_values(["team_id", "date_utc"]).reset_index(drop=True)

    one_all = pd.Series(1.0, index=hist.index)
    one_home = np.where(hist["h_a"].eq("h"), 1.0, np.nan)
    one_away = np.where(hist["h_a"].eq("a"), 1.0, np.nan)

    grouped_team = hist.groupby("team_id")
    home_mask = hist["h_a"].eq("h")
    away_mask = hist["h_a"].eq("a")
    home_series = pd.Series(one_home, index=hist.index)
    away_series = pd.Series(one_away, index=hist.index)
    new_cols = {}

    for window in windows:
        new_cols[f"us_hist_matches_all_{window}"] = (
            one_all.groupby(hist["team_id"])
            .transform(lambda s: s.shift(1).rolling(window, min_periods=1).sum())
        )
        new_cols[f"us_hist_matches_home_{window}"] = (
            home_series.groupby(hist["team_id"])
            .transform(lambda s: s.shift(1).rolling(window, min_periods=1).sum())
        )
        new_cols[f"us_hist_matches_away_{window}"] = (
            away_series.groupby(hist["team_id"])
            .transform(lambda s: s.shift(1).rolling(window, min_periods=1).sum())
        )

        for metric in UNDERSTAT_METRICS:
            metric_series = hist[metric]
            new_cols[f"us_{metric}_all_{window}"] = (
                grouped_team[metric]
                .transform(lambda s: s.shift(1).rolling(window, min_periods=1).mean())
            )
            new_cols[f"us_{metric}_home_{window}"] = (
                metric_series.where(home_mask)
                .groupby(hist["team_id"])
                .transform(lambda s: s.shift(1).rolling(window, min_periods=1).mean())
            )
            new_cols[f"us_{metric}_away_{window}"] = (
                metric_series.where(away_mask)
                .groupby(hist["team_id"])
                .transform(lambda s: s.shift(1).rolling(window, min_periods=1).mean())
            )

        for metric in UNDERSTAT_OVERPERF_METRICS:
            metric_series = hist[metric]
            new_cols[f"us_{metric}_all_{window}"] = (
                grouped_team[metric]
                .transform(lambda s: s.shift(1).rolling(window, min_periods=1).mean())
            )
            new_cols[f"us_{metric}_home_{window}"] = (
                metric_series.where(home_mask)
                .groupby(hist["team_id"])
                .transform(lambda s: s.shift(1).rolling(window, min_periods=1).mean())
            )
            new_cols[f"us_{metric}_away_{window}"] = (
                metric_series.where(away_mask)
                .groupby(hist["team_id"])
                .transform(lambda s: s.shift(1).rolling(window, min_periods=1).mean())
            )
            new_cols[f"us_{metric}_std_all_{window}"] = (
                grouped_team[metric]
                .transform(lambda s: s.shift(1).rolling(window, min_periods=2).std())
            )
            new_cols[f"us_{metric}_std_home_{window}"] = (
                metric_series.where(home_mask)
                .groupby(hist["team_id"])
                .transform(lambda s: s.shift(1).rolling(window, min_periods=2).std())
            )
            new_cols[f"us_{metric}_std_away_{window}"] = (
                metric_series.where(away_mask)
                .groupby(hist["team_id"])
                .transform(lambda s: s.shift(1).rolling(window, min_periods=2).std())
            )

    hist = pd.concat([hist, pd.DataFrame(new_cols, index=hist.index)], axis=1)

    hist_feature_cols = [
        c
        for c in hist.columns
        if c.startswith("us_") or c.startswith("us_hist_matches_")
    ]
    history_snapshot = hist[["team_id", "date_utc"] + hist_feature_cols].sort_values(["date_utc", "team_id"])

    def _merge_side(team_col: str, prefix: str, side_scope: str) -> pd.DataFrame:
        left = (
            sched[["fixture_id", "date_utc", team_col]]
            .rename(columns={team_col: "team_id"})
            .sort_values(["date_utc", "team_id"])
        )

        merged = pd.merge_asof(
            left,
            history_snapshot,
            on="date_utc",
            by="team_id",
            direction="backward",
            allow_exact_matches=False,
        )

        keep = ["fixture_id"]
        rename_map = {}
        for col in hist_feature_cols:
            if "_all_" in col or f"_{side_scope}_" in col:
                keep.append(col)
                rename_map[col] = f"{prefix}_{col}"

        merged = merged[keep].rename(columns=rename_map)
        return merged

    home_feats = _merge_side("home_team_id", "home", "home")
    away_feats = _merge_side("away_team_id", "away", "away")
    return home_feats.merge(away_feats, on="fixture_id", how="left")


def add_understat_system_features(df_all: pd.DataFrame) -> pd.DataFrame:
    df = df_all.copy()
    new_cols = {}

    def _num(col: str) -> pd.Series:
        return pd.to_numeric(df[col], errors="coerce")

    def _diff(out_col: str, left: str, right: str):
        if left in df.columns and right in df.columns:
            new_cols[out_col] = _num(left) - _num(right)

    def _ratio(out_col: str, num_col: str, den_col: str):
        if num_col in df.columns and den_col in df.columns:
            den = _num(den_col).replace(0, np.nan)
            new_cols[out_col] = _num(num_col) / den

    matchup_specs = {
        "usys_home_npxg_matchup_3": ("home_us_npxg_all_3", "away_us_npxga_all_3"),
        "usys_away_npxg_matchup_3": ("away_us_npxg_all_3", "home_us_npxga_all_3"),
        "usys_home_npxg_matchup_5": ("home_us_npxg_all_5", "away_us_npxga_all_5"),
        "usys_away_npxg_matchup_5": ("away_us_npxg_all_5", "home_us_npxga_all_5"),
        "usys_home_npxg_matchup_10": ("home_us_npxg_all_10", "away_us_npxga_all_10"),
        "usys_away_npxg_matchup_10": ("away_us_npxg_all_10", "home_us_npxga_all_10"),
        "usys_home_xg_matchup_5": ("home_us_xg_all_5", "away_us_xga_all_5"),
        "usys_away_xg_matchup_5": ("away_us_xg_all_5", "home_us_xga_all_5"),
        "usys_home_control_matchup_5": ("home_us_deep_all_5", "away_us_deep_allowed_all_5"),
        "usys_away_control_matchup_5": ("away_us_deep_all_5", "home_us_deep_allowed_all_5"),
        "usys_home_press_matchup_5": ("away_us_ppda_allowed_all_5", "home_us_ppda_all_5"),
        "usys_away_press_matchup_5": ("home_us_ppda_allowed_all_5", "away_us_ppda_all_5"),
        "usys_home_control_matchup_10": ("home_us_deep_all_10", "away_us_deep_allowed_all_10"),
        "usys_away_control_matchup_10": ("away_us_deep_all_10", "home_us_deep_allowed_all_10"),
    }
    for out_col, (left, right) in matchup_specs.items():
        _diff(out_col, left, right)

    trend_specs = {
        "usys_home_npxg_trend_3v10": ("home_us_npxg_all_3", "home_us_npxg_all_10"),
        "usys_away_npxg_trend_3v10": ("away_us_npxg_all_3", "away_us_npxg_all_10"),
        "usys_home_npxga_trend_3v10": ("home_us_npxga_all_3", "home_us_npxga_all_10"),
        "usys_away_npxga_trend_3v10": ("away_us_npxga_all_3", "away_us_npxga_all_10"),
        "usys_home_xg_trend_3v10": ("home_us_xg_all_3", "home_us_xg_all_10"),
        "usys_away_xg_trend_3v10": ("away_us_xg_all_3", "away_us_xg_all_10"),
        "usys_home_xga_trend_3v10": ("home_us_xga_all_3", "home_us_xga_all_10"),
        "usys_away_xga_trend_3v10": ("away_us_xga_all_3", "away_us_xga_all_10"),
        "usys_home_deep_trend_3v10": ("home_us_deep_all_3", "home_us_deep_all_10"),
        "usys_away_deep_trend_3v10": ("away_us_deep_all_3", "away_us_deep_all_10"),
        "usys_home_ppda_trend_3v10": ("home_us_ppda_all_3", "home_us_ppda_all_10"),
        "usys_away_ppda_trend_3v10": ("away_us_ppda_all_3", "away_us_ppda_all_10"),
        "usys_home_finish_trend_3v10": ("home_us_goal_minus_npxg_all_3", "home_us_goal_minus_npxg_all_10"),
        "usys_away_finish_trend_3v10": ("away_us_goal_minus_npxg_all_3", "away_us_goal_minus_npxg_all_10"),
        "usys_home_def_finish_trend_3v10": ("home_us_goal_against_minus_npxga_all_3", "home_us_goal_against_minus_npxga_all_10"),
        "usys_away_def_finish_trend_3v10": ("away_us_goal_against_minus_npxga_all_3", "away_us_goal_against_minus_npxga_all_10"),
    }
    for out_col, (left, right) in trend_specs.items():
        _diff(out_col, left, right)

    venue_specs = {
        "usys_home_venue_strength_5": ("home_us_npxg_home_5", "home_us_npxga_home_5"),
        "usys_away_venue_strength_5": ("away_us_npxg_away_5", "away_us_npxga_away_5"),
        "usys_home_venue_strength_10": ("home_us_npxg_home_10", "home_us_npxga_home_10"),
        "usys_away_venue_strength_10": ("away_us_npxg_away_10", "away_us_npxga_away_10"),
        "usys_home_finish_edge_5": ("home_us_goal_minus_npxg_home_5", "away_us_goal_against_minus_npxga_away_5"),
        "usys_away_finish_edge_5": ("away_us_goal_minus_npxg_away_5", "home_us_goal_against_minus_npxga_home_5"),
    }
    for out_col, (left, right) in venue_specs.items():
        _diff(out_col, left, right)

    _diff("usys_matchup_venue_edge_5", "usys_home_venue_strength_5", "usys_away_venue_strength_5")
    _diff("usys_matchup_venue_edge_10", "usys_home_venue_strength_10", "usys_away_venue_strength_10")

    _ratio("usys_home_npxg_per_deep_5", "home_us_npxg_all_5", "home_us_deep_all_5")
    _ratio("usys_away_npxg_per_deep_5", "away_us_npxg_all_5", "away_us_deep_all_5")
    _ratio("usys_home_xga_per_deep_allowed_5", "home_us_xga_all_5", "home_us_deep_allowed_all_5")
    _ratio("usys_away_xga_per_deep_allowed_5", "away_us_xga_all_5", "away_us_deep_allowed_all_5")
    _diff("usys_home_efficiency_matchup_5", "usys_home_npxg_per_deep_5", "usys_away_xga_per_deep_allowed_5")
    _diff("usys_away_efficiency_matchup_5", "usys_away_npxg_per_deep_5", "usys_home_xga_per_deep_allowed_5")

    _diff("usys_home_regression_noise_5", "home_us_goal_minus_npxg_std_all_5", "away_us_goal_against_minus_npxga_std_all_5")
    _diff("usys_away_regression_noise_5", "away_us_goal_minus_npxg_std_all_5", "home_us_goal_against_minus_npxga_std_all_5")
    _diff("usys_home_regression_edge_5", "home_us_goal_minus_npxg_all_5", "away_us_goal_against_minus_npxga_all_5")
    _diff("usys_away_regression_edge_5", "away_us_goal_minus_npxg_all_5", "home_us_goal_against_minus_npxga_all_5")

    if new_cols:
        df = pd.concat([df, pd.DataFrame(new_cols, index=df.index)], axis=1)
    return df


# =========================================================
# MAIN DATASET (PUBLIC API)
# =========================================================
def build_dataset(return_all=True):
    engine = create_engine(DB_URL)

    sched = load_schedule(engine)
    sched["date_utc"] = pd.to_datetime(sched["date_utc"], utc=True)
    sched = build_targets(sched)

    form = build_team_form(sched, window=5)
    match_stats = build_match_stats_features(sched, engine)
    understat = build_understat_features(sched, engine)
    player_contrib = build_player_contribution_features(
        sched,
        engine,
        min_season=UNDERSTAT_MIN_SEASON,
    )
    lineup_strength = build_lineup_strength_features(
        sched,
        engine,
        min_season=UNDERSTAT_MIN_SEASON,
    )
    injuries_raw = load_injuries(engine)
    injuries = compute_injury_features(sched, injuries_raw) if not injuries_raw.empty else pd.DataFrame({"fixture_id": sched["fixture_id"]})
    odds = load_odds(engine, sched["fixture_id"].tolist())

    df = (
        sched
        .merge(form, on="fixture_id", how="left")
        .merge(match_stats, on="fixture_id", how="left")
        .merge(understat, on="fixture_id", how="left")
        .merge(player_contrib, on="fixture_id", how="left")
        .merge(lineup_strength, on="fixture_id", how="left")
        .merge(injuries, on="fixture_id", how="left")
        .merge(odds, on="fixture_id", how="left")
        .sort_values("date_utc")
        .reset_index(drop=True)
    )
    df = add_understat_system_features(df)
    df = add_player_contribution_system_features(df)

    return df if return_all else df[df["has_result"]]
