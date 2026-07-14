import numpy as np
import pandas as pd
from sqlalchemy import text


def load_understat_player_history(engine, min_season: int) -> pd.DataFrame:
    return pd.read_sql(
        text(
            """
            SELECT
                um.match_id,
                um.match_dt_utc::timestamp AS date_utc,
                um.season,
                um.league AS league_raw,
                mp.team_id AS understat_team_id,
                mp.player_id,
                COALESCE(mp.minutes, 0) AS minutes,
                COALESCE(mp.xg, 0)::double precision AS xg,
                COALESCE(mp.xa, 0)::double precision AS xa,
                COALESCE(mp.shots, 0) AS shots,
                COALESCE(mp.key_passes, 0) AS key_passes
            FROM football.understat_match_players mp
            JOIN football.understat_matches um
              ON um.match_id = mp.match_id
            WHERE um.season >= :min_season
            """
        ),
        engine,
        params={"min_season": int(min_season)},
    )


def load_understat_team_map(engine, min_season: int) -> pd.DataFrame:
    return pd.read_sql(
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


def _top_share(values: np.ndarray, k: int) -> float:
    arr = np.sort(np.clip(np.asarray(values, dtype=float), 0.0, None))[::-1]
    if arr.size == 0:
        return 0.0
    total = float(arr.sum())
    if total <= 0:
        return 0.0
    return float(arr[:k].sum() / total)


def _hhi(values: np.ndarray) -> float:
    arr = np.clip(np.asarray(values, dtype=float), 0.0, None)
    total = float(arr.sum())
    if total <= 0:
        return 0.0
    shares = arr / total
    return float(np.square(shares).sum())


def _aggregate_match_team_players(players: pd.DataFrame) -> pd.DataFrame:
    rows = []

    for keys, g in players.groupby(["match_id", "date_utc", "team_id"], sort=False):
        match_id, date_utc, team_id = keys
        xg = pd.to_numeric(g["xg"], errors="coerce").fillna(0.0).to_numpy(dtype=float)
        xa = pd.to_numeric(g["xa"], errors="coerce").fillna(0.0).to_numpy(dtype=float)
        minutes = pd.to_numeric(g["minutes"], errors="coerce").fillna(0.0).clip(lower=0).to_numpy(dtype=float)
        contrib = xg + xa

        usage_top3_share = 0.0
        total_minutes = float(minutes.sum())
        if total_minutes > 0 and contrib.size:
            order = np.argsort(-contrib)
            usage_top3_share = float(minutes[order[:3]].sum() / total_minutes)

        rows.append(
            {
                "match_id": int(match_id),
                "date_utc": pd.to_datetime(date_utc, utc=True, errors="coerce"),
                "team_id": int(team_id),
                "pl_top1_xg_share": _top_share(xg, 1),
                "pl_top3_xg_share": _top_share(xg, 3),
                "pl_top1_xa_share": _top_share(xa, 1),
                "pl_top3_xa_share": _top_share(xa, 3),
                "pl_xg_hhi": _hhi(xg),
                "pl_xa_hhi": _hhi(xa),
                "pl_xg_contributors": int((xg >= 0.15).sum()),
                "pl_xa_creators": int((xa >= 0.10).sum()),
                "pl_usage_top3_share": usage_top3_share,
                "pl_attack_core_load": float(np.sort(np.clip(contrib, 0.0, None))[::-1][:3].sum()),
            }
        )

    return pd.DataFrame(rows)


def build_player_contribution_features(
    schedule: pd.DataFrame,
    engine,
    windows=(5, 10),
    min_season: int = 2024,
) -> pd.DataFrame:
    sched = schedule.copy()
    if sched.empty:
        return pd.DataFrame({"fixture_id": []})

    sched["date_utc"] = pd.to_datetime(sched["date_utc"], utc=True, errors="coerce")

    raw = load_understat_player_history(engine, min_season=min_season)
    if raw.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    league_name_map = {
        "EPL": "Premier League",
        "Premier League": "Premier League",
        "Bundesliga": "Bundesliga",
        "Serie_A": "Serie A",
        "Serie A": "Serie A",
        "Ligue_1": "Ligue 1",
        "Ligue 1": "Ligue 1",
        "La_liga": "La Liga",
        "La liga": "La Liga",
        "La Liga": "La Liga",
    }
    raw["league_name"] = raw["league_raw"].map(league_name_map)
    raw = raw.dropna(subset=["league_name"]).copy()

    team_map = load_understat_team_map(engine, min_season=min_season)
    if team_map.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    team_map = (
        team_map.sort_values(["season", "league_name", "understat_team_id", "api_team_id"])
        .drop_duplicates(subset=["season", "league_name", "understat_team_id"], keep="first")
        .copy()
    )

    raw = raw.merge(
        team_map,
        on=["season", "league_name", "understat_team_id"],
        how="inner",
    )
    if raw.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    raw["team_id"] = raw["api_team_id"]
    raw = raw.dropna(subset=["team_id", "date_utc"]).copy()
    if raw.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    match_team = _aggregate_match_team_players(raw)
    if match_team.empty:
        return pd.DataFrame({"fixture_id": sched["fixture_id"]})

    match_team = match_team.sort_values(["team_id", "date_utc"]).reset_index(drop=True)
    base_metrics = [c for c in match_team.columns if c.startswith("pl_")]

    for window in windows:
        for metric in base_metrics:
            match_team[f"{metric}_{window}"] = (
                match_team.groupby("team_id")[metric]
                .transform(lambda s: s.shift(1).rolling(window, min_periods=1).mean())
            )

    hist_cols = [c for c in match_team.columns if c.startswith("pl_") and c not in base_metrics]
    history_snapshot = match_team[["team_id", "date_utc"] + hist_cols].sort_values(["date_utc", "team_id"])

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

        keep = ["fixture_id"] + hist_cols
        rename_map = {col: f"{prefix}_{col}" for col in hist_cols}
        return merged[keep].rename(columns=rename_map)

    home_feats = _merge_side("home_team_id", "home")
    away_feats = _merge_side("away_team_id", "away")
    return home_feats.merge(away_feats, on="fixture_id", how="left")


def add_player_contribution_system_features(df_all: pd.DataFrame, windows=(5, 10)) -> pd.DataFrame:
    df = df_all.copy()

    diff_metrics = [
        "pl_top1_xg_share",
        "pl_top3_xg_share",
        "pl_top1_xa_share",
        "pl_top3_xa_share",
        "pl_xg_hhi",
        "pl_xa_hhi",
        "pl_xg_contributors",
        "pl_xa_creators",
        "pl_usage_top3_share",
        "pl_attack_core_load",
    ]

    for window in windows:
        for metric in diff_metrics:
            home_col = f"home_{metric}_{window}"
            away_col = f"away_{metric}_{window}"
            if home_col in df.columns and away_col in df.columns:
                df[f"{metric}_diff_{window}"] = (
                    pd.to_numeric(df[home_col], errors="coerce")
                    - pd.to_numeric(df[away_col], errors="coerce")
                )

    return df
