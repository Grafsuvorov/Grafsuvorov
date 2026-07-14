import numpy as np
import pandas as pd


def _rank_table(rows: list[dict]) -> list[dict]:
    ranked = sorted(
        rows,
        key=lambda r: (
            -float(r.get("points", 0.0)),
            -float(r.get("goal_diff", 0.0)),
            -float(r.get("goals_for", 0.0)),
            int(r.get("team_id", 0)),
        ),
    )
    for idx, row in enumerate(ranked, start=1):
        row["position"] = idx
    return ranked


def _bucket_for_position(pos: int, n_teams: int, top_n: int, bottom_n: int) -> str:
    top_cut = min(top_n, max(1, n_teams // 3))
    bottom_cut = max(1, min(bottom_n, n_teams // 3))
    if pos <= top_cut:
        return "top"
    if pos > n_teams - bottom_cut:
        return "bottom"
    return "mid"


def _agg_side_history(hist: list[dict], bucket: str, window: int, venue: str | None) -> tuple[float, float]:
    items = [x for x in hist if x["opp_bucket"] == bucket and (venue is None or x["venue"] == venue)]
    if not items:
        return np.nan, np.nan
    items = items[-window:]
    pts = np.mean([x["points"] for x in items]) if items else np.nan
    gd = np.mean([x["goal_diff"] for x in items]) if items else np.nan
    return float(pts), float(gd)


def build_opponent_segment_features(
    schedule: pd.DataFrame,
    windows=(5, 10),
    top_n: int = 6,
    bottom_n: int = 6,
) -> pd.DataFrame:
    """
    Pre-match features describing how teams perform against strong/mid/weak opponents.
    No leakage: opponent bucket for each historical match is based on opponent pre-match table position.
    """
    base = schedule.sort_values(["league_id", "season", "date_utc", "fixture_id"]).copy()
    rows: list[dict] = []

    for (league_id, season), g in base.groupby(["league_id", "season"], sort=False):
        g = g.sort_values(["date_utc", "fixture_id"]).copy()
        team_ids = sorted(set(g["home_team_id"].dropna().astype(int)).union(set(g["away_team_id"].dropna().astype(int))))
        n_teams = len(team_ids)
        if n_teams == 0:
            continue

        standings = {
            int(tid): {"team_id": int(tid), "points": 0.0, "games": 0, "goals_for": 0.0, "goals_against": 0.0, "goal_diff": 0.0}
            for tid in team_ids
        }
        histories = {int(tid): [] for tid in team_ids}

        for row in g.itertuples():
            fixture_id = int(row.fixture_id)
            home_id = int(row.home_team_id)
            away_id = int(row.away_team_id)

            ranked = _rank_table([dict(v) for v in standings.values()])
            pos_map = {r["team_id"]: int(r["position"]) for r in ranked}

            home_opp_bucket = _bucket_for_position(pos_map[away_id], n_teams, top_n, bottom_n)
            away_opp_bucket = _bucket_for_position(pos_map[home_id], n_teams, top_n, bottom_n)

            out = {
                "fixture_id": fixture_id,
                "home_opp_bucket_top": int(home_opp_bucket == "top"),
                "home_opp_bucket_mid": int(home_opp_bucket == "mid"),
                "home_opp_bucket_bottom": int(home_opp_bucket == "bottom"),
                "away_opp_bucket_top": int(away_opp_bucket == "top"),
                "away_opp_bucket_mid": int(away_opp_bucket == "mid"),
                "away_opp_bucket_bottom": int(away_opp_bucket == "bottom"),
            }

            for w in windows:
                h_pts_all, h_gd_all = _agg_side_history(histories[home_id], home_opp_bucket, w, venue=None)
                h_pts_venue, h_gd_venue = _agg_side_history(histories[home_id], home_opp_bucket, w, venue="home")
                a_pts_all, a_gd_all = _agg_side_history(histories[away_id], away_opp_bucket, w, venue=None)
                a_pts_venue, a_gd_venue = _agg_side_history(histories[away_id], away_opp_bucket, w, venue="away")

                out[f"home_vs_bucket_points_all_{w}"] = h_pts_all
                out[f"home_vs_bucket_gd_all_{w}"] = h_gd_all
                out[f"home_vs_bucket_points_venue_{w}"] = h_pts_venue
                out[f"home_vs_bucket_gd_venue_{w}"] = h_gd_venue
                out[f"away_vs_bucket_points_all_{w}"] = a_pts_all
                out[f"away_vs_bucket_gd_all_{w}"] = a_gd_all
                out[f"away_vs_bucket_points_venue_{w}"] = a_pts_venue
                out[f"away_vs_bucket_gd_venue_{w}"] = a_gd_venue
                out[f"vs_bucket_points_all_diff_{w}"] = (
                    np.nan if pd.isna(h_pts_all) or pd.isna(a_pts_all) else float(h_pts_all - a_pts_all)
                )
                out[f"vs_bucket_gd_all_diff_{w}"] = (
                    np.nan if pd.isna(h_gd_all) or pd.isna(a_gd_all) else float(h_gd_all - a_gd_all)
                )
                out[f"vs_bucket_points_venue_diff_{w}"] = (
                    np.nan if pd.isna(h_pts_venue) or pd.isna(a_pts_venue) else float(h_pts_venue - a_pts_venue)
                )
                out[f"vs_bucket_gd_venue_diff_{w}"] = (
                    np.nan if pd.isna(h_gd_venue) or pd.isna(a_gd_venue) else float(h_gd_venue - a_gd_venue)
                )

            rows.append(out)

            hg = row.home_goals
            ag = row.away_goals
            if pd.notna(hg) and pd.notna(ag):
                hg = float(hg)
                ag = float(ag)

                home_pts = 3.0 if hg > ag else 1.0 if hg == ag else 0.0
                away_pts = 3.0 if ag > hg else 1.0 if hg == ag else 0.0
                histories[home_id].append(
                    {
                        "opp_bucket": home_opp_bucket,
                        "venue": "home",
                        "points": home_pts,
                        "goal_diff": hg - ag,
                    }
                )
                histories[away_id].append(
                    {
                        "opp_bucket": away_opp_bucket,
                        "venue": "away",
                        "points": away_pts,
                        "goal_diff": ag - hg,
                    }
                )

                standings[home_id]["games"] += 1
                standings[away_id]["games"] += 1
                standings[home_id]["goals_for"] += hg
                standings[home_id]["goals_against"] += ag
                standings[away_id]["goals_for"] += ag
                standings[away_id]["goals_against"] += hg
                standings[home_id]["goal_diff"] = standings[home_id]["goals_for"] - standings[home_id]["goals_against"]
                standings[away_id]["goal_diff"] = standings[away_id]["goals_for"] - standings[away_id]["goals_against"]
                if hg > ag:
                    standings[home_id]["points"] += 3.0
                elif hg < ag:
                    standings[away_id]["points"] += 3.0
                else:
                    standings[home_id]["points"] += 1.0
                    standings[away_id]["points"] += 1.0

    out_df = pd.DataFrame(rows)
    if out_df.empty:
        return out_df
    return out_df.replace([np.inf, -np.inf], np.nan)
