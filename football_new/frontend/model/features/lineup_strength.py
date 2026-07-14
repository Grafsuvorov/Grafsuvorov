import numpy as np
import pandas as pd
from sqlalchemy import text

from config import LEAGUES


def load_lineup_history(engine, min_season: int = 2024) -> pd.DataFrame:
    return pd.read_sql(
        text(
            """
            SELECT
                s.fixture_id,
                s.date::timestamp AS date_utc,
                s.season,
                s.league_id,
                s.home_team_id,
                s.away_team_id,
                l.team_id,
                l.player_id,
                l.position,
                l.grid,
                l.is_starting,
                NULLIF(
                    regexp_replace(COALESCE(ps.player_rating::text, ''), '[^0-9\\.]', '', 'g'),
                    ''
                )::double precision AS player_rating,
                COALESCE(ps.minutes, 0) AS minutes
            FROM football.api_football_schedule s
            JOIN football.api_football_lineups l
              ON l.fixture_id = s.fixture_id
            LEFT JOIN football.api_football_player_stats ps
              ON ps.fixture_id = l.fixture_id
             AND ps.team_id = l.team_id
             AND ps.player_id = l.player_id
            WHERE s.league_id IN :leagues
              AND s.season >= :min_season
            """
        ),
        engine,
        params={"leagues": tuple(LEAGUES), "min_season": int(min_season)},
    )


def _normalize_position(position: str, grid: str) -> str:
    pos = (position or "").strip().upper()
    grid_txt = str(grid or "").strip()
    if pos.startswith("G"):
        return "GK"
    if pos.startswith("D") or pos in {"CB", "LB", "RB", "WB"}:
        return "DEF"
    if pos.startswith("M") or pos in {"DM", "CM", "AM"}:
        return "MID"
    if pos.startswith("A") or pos.startswith("F") or pos in {"RW", "LW", "SS", "CF", "ST"}:
        return "ATT"
    if grid_txt:
        try:
            row_idx = int(grid_txt.split(":")[0])
            if row_idx <= 1:
                return "DEF"
            if row_idx == 2:
                return "MID"
            return "ATT"
        except Exception:
            pass
    return "MID"


def _rolling_player_priors(players: pd.DataFrame, windows=(5, 10, 15)) -> pd.DataFrame:
    df = players.sort_values(["player_id", "date_utc", "fixture_id"]).copy()
    raw_rating = pd.to_numeric(df["player_rating"], errors="coerce")
    minutes = pd.to_numeric(df["minutes"], errors="coerce").fillna(0.0).clip(lower=0.0)
    # Heavier trust in full-match ratings while keeping partial appearances usable.
    minute_weight = np.clip(minutes / 90.0, 0.20, 1.0)
    df["ls_weighted_rating"] = raw_rating * minute_weight

    fallback_by_pos = (
        df.groupby("pos_group")["player_rating"]
        .mean()
        .replace([np.inf, -np.inf], np.nan)
        .fillna(6.5)
        .to_dict()
    )

    for window in windows:
        num = (
            df.groupby("player_id")["ls_weighted_rating"]
            .transform(lambda s: s.shift(1).rolling(window, min_periods=2).sum())
        )
        den = (
            df.groupby("player_id")[minutes.name]
            .transform(lambda s: (s.shift(1).clip(lower=18.0, upper=90.0) / 90.0).rolling(window, min_periods=2).sum())
        )
        pri = num / den.replace(0.0, np.nan)
        df[f"ls_player_prior_{window}"] = pri

    df["ls_player_prior"] = (
        pd.to_numeric(df.get("ls_player_prior_10"), errors="coerce")
        .fillna(pd.to_numeric(df.get("ls_player_prior_15"), errors="coerce"))
        .fillna(pd.to_numeric(df.get("ls_player_prior_5"), errors="coerce"))
    )
    df["ls_player_prior"] = df["ls_player_prior"].fillna(df["pos_group"].map(fallback_by_pos)).fillna(6.5)
    return df


def _aggregate_match_lineup_strength(players: pd.DataFrame) -> pd.DataFrame:
    rows = []

    starters = players[players["is_starting"].fillna(False)].copy()
    if starters.empty:
        return pd.DataFrame()

    for keys, g in starters.groupby(["fixture_id", "date_utc", "team_id", "home_team_id", "away_team_id"], sort=False):
        fixture_id, date_utc, team_id, home_team_id, away_team_id = keys
        ratings = pd.to_numeric(g["ls_player_prior"], errors="coerce").dropna().to_numpy(dtype=float)
        if ratings.size == 0:
            continue

        line_means = {}
        for pos_group in ("GK", "DEF", "MID", "ATT"):
            vals = pd.to_numeric(
                g.loc[g["pos_group"] == pos_group, "ls_player_prior"],
                errors="coerce",
            ).dropna().to_numpy(dtype=float)
            line_means[pos_group] = float(np.nanmean(vals)) if vals.size else np.nan

        finite_lines = [line_means[p] for p in ("DEF", "MID", "ATT") if np.isfinite(line_means[p])]
        rows.append(
            {
                "fixture_id": int(fixture_id),
                "date_utc": pd.to_datetime(date_utc, utc=True, errors="coerce"),
                "team_id": int(team_id),
                "is_home": int(team_id == home_team_id),
                "ls_xi_rating": float(np.nanmean(ratings)),
                "ls_weakest_starter": float(np.nanmin(ratings)),
                "ls_rating_std": float(np.nanstd(ratings)) if ratings.size > 1 else 0.0,
                "ls_gk_rating": line_means["GK"],
                "ls_def_rating": line_means["DEF"],
                "ls_mid_rating": line_means["MID"],
                "ls_att_rating": line_means["ATT"],
                "ls_line_balance": float(np.nanstd(finite_lines)) if len(finite_lines) > 1 else 0.0,
                "ls_known_starters": int(np.isfinite(ratings).sum()),
            }
        )

    return pd.DataFrame(rows)


def _add_team_rollups(team_match: pd.DataFrame, windows=(5, 10, 15)) -> pd.DataFrame:
    base_metrics = [
        "ls_xi_rating",
        "ls_weakest_starter",
        "ls_rating_std",
        "ls_gk_rating",
        "ls_def_rating",
        "ls_mid_rating",
        "ls_att_rating",
        "ls_line_balance",
        "ls_known_starters",
    ]

    df = team_match.sort_values(["team_id", "date_utc", "fixture_id"]).copy()

    for metric in base_metrics:
        df[f"{metric}_long"] = (
            df.groupby("team_id")[metric]
            .transform(lambda s: s.shift(1).expanding(min_periods=3).mean())
        )

    for window in windows:
        for metric in base_metrics:
            df[f"{metric}_all_{window}"] = (
                df.groupby("team_id")[metric]
                .transform(lambda s: s.shift(1).rolling(window, min_periods=2).mean())
            )

    home_only = df[df["is_home"] == 1][["team_id", "date_utc"] + base_metrics].copy()
    away_only = df[df["is_home"] == 0][["team_id", "date_utc"] + base_metrics].copy()

    for window in windows:
        for metric in base_metrics:
            home_only[f"{metric}_home_{window}"] = (
                home_only.groupby("team_id")[metric]
                .transform(lambda s: s.shift(1).rolling(window, min_periods=2).mean())
            )
            away_only[f"{metric}_away_{window}"] = (
                away_only.groupby("team_id")[metric]
                .transform(lambda s: s.shift(1).rolling(window, min_periods=2).mean())
            )

    home_keep = ["team_id", "date_utc"] + [c for c in home_only.columns if c.endswith(tuple(f"_home_{w}" for w in windows))]
    away_keep = ["team_id", "date_utc"] + [c for c in away_only.columns if c.endswith(tuple(f"_away_{w}" for w in windows))]
    df = df.merge(home_only[home_keep], on=["team_id", "date_utc"], how="left")
    df = df.merge(away_only[away_keep], on=["team_id", "date_utc"], how="left")
    return df


def build_lineup_strength_features(
    schedule: pd.DataFrame,
    engine,
    windows=(5, 10, 15),
    min_season: int = 2024,
) -> pd.DataFrame:
    sched = schedule.copy()
    if sched.empty:
        return pd.DataFrame({"fixture_id": []})
    sched["date_utc"] = pd.to_datetime(sched["date_utc"], utc=True, errors="coerce")

    raw = load_lineup_history(engine, min_season=min_season)
    if raw.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    raw["date_utc"] = pd.to_datetime(raw["date_utc"], utc=True, errors="coerce")
    raw["pos_group"] = [
        _normalize_position(pos, grid)
        for pos, grid in zip(raw.get("position"), raw.get("grid"))
    ]
    raw = _rolling_player_priors(raw, windows=windows)

    team_match = _aggregate_match_lineup_strength(raw)
    if team_match.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    team_match = _add_team_rollups(team_match, windows=windows)

    all_roll_cols = [
        c for c in team_match.columns
        if c.startswith("ls_") and c not in {
            "ls_xi_rating",
            "ls_weakest_starter",
            "ls_rating_std",
            "ls_gk_rating",
            "ls_def_rating",
            "ls_mid_rating",
            "ls_att_rating",
            "ls_line_balance",
            "ls_known_starters",
        }
    ]
    history_snapshot = team_match[["team_id", "date_utc"] + all_roll_cols].sort_values(["date_utc", "team_id"])

    def _merge_side(team_col: str, prefix: str) -> pd.DataFrame:
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
        keep = ["fixture_id"] + all_roll_cols
        rename_map = {col: f"{prefix}_{col}" for col in all_roll_cols}
        return merged[keep].rename(columns=rename_map)

    home_feats = _merge_side("home_team_id", "home")
    away_feats = _merge_side("away_team_id", "away")
    out = home_feats.merge(away_feats, on="fixture_id", how="left")
    return add_lineup_strength_system_features(out, windows=windows)


def add_lineup_strength_system_features(df_all: pd.DataFrame, windows=(5, 10, 15)) -> pd.DataFrame:
    df = df_all.copy()

    diff_metrics = [
        "ls_xi_rating_long",
        "ls_weakest_starter_long",
        "ls_gk_rating_long",
        "ls_def_rating_long",
        "ls_mid_rating_long",
        "ls_att_rating_long",
        "ls_line_balance_long",
    ]
    for window in windows:
        diff_metrics.extend(
            [
                f"ls_xi_rating_all_{window}",
                f"ls_weakest_starter_all_{window}",
                f"ls_gk_rating_all_{window}",
                f"ls_def_rating_all_{window}",
                f"ls_mid_rating_all_{window}",
                f"ls_att_rating_all_{window}",
                f"ls_line_balance_all_{window}",
            ]
        )

    for metric in diff_metrics:
        home_col = f"home_{metric}"
        away_col = f"away_{metric}"
        if home_col in df.columns and away_col in df.columns:
            df[f"{metric}_diff"] = (
                pd.to_numeric(df[home_col], errors="coerce")
                - pd.to_numeric(df[away_col], errors="coerce")
            )

    trend_specs = [
        ("home_ls_xi_rating_trend_5v15", "home_ls_xi_rating_all_5", "home_ls_xi_rating_all_15"),
        ("away_ls_xi_rating_trend_5v15", "away_ls_xi_rating_all_5", "away_ls_xi_rating_all_15"),
        ("home_ls_att_rating_trend_5v15", "home_ls_att_rating_all_5", "home_ls_att_rating_all_15"),
        ("away_ls_att_rating_trend_5v15", "away_ls_att_rating_all_5", "away_ls_att_rating_all_15"),
        ("home_ls_def_rating_trend_5v15", "home_ls_def_rating_all_5", "home_ls_def_rating_all_15"),
        ("away_ls_def_rating_trend_5v15", "away_ls_def_rating_all_5", "away_ls_def_rating_all_15"),
    ]
    for out_col, left, right in trend_specs:
        if left in df.columns and right in df.columns:
            df[out_col] = pd.to_numeric(df[left], errors="coerce") - pd.to_numeric(df[right], errors="coerce")

    matchup_specs = [
        ("ls_matchup_home_attack_vs_away_def_10", "home_ls_att_rating_all_10", "away_ls_def_rating_all_10"),
        ("ls_matchup_away_attack_vs_home_def_10", "away_ls_att_rating_all_10", "home_ls_def_rating_all_10"),
        ("ls_matchup_home_mid_vs_away_mid_10", "home_ls_mid_rating_all_10", "away_ls_mid_rating_all_10"),
        ("ls_matchup_venue_xi_edge_10", "home_ls_xi_rating_home_10", "away_ls_xi_rating_away_10"),
    ]
    for out_col, left, right in matchup_specs:
        if left in df.columns and right in df.columns:
            df[out_col] = pd.to_numeric(df[left], errors="coerce") - pd.to_numeric(df[right], errors="coerce")

    return df
