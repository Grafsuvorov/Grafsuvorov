from __future__ import annotations

from collections import defaultdict

import numpy as np
import pandas as pd


def build_v53_context_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)

    league_season_total_matches = (
        out.groupby(["league_id", "season"], sort=False)["fixture_id"].count().to_dict()
    )
    league_season_team_count = {}
    for (league_id, season), g in out.groupby(["league_id", "season"], sort=False):
        teams = set(pd.to_numeric(g["home_team_id"], errors="coerce").dropna().astype(int).tolist())
        teams |= set(pd.to_numeric(g["away_team_id"], errors="coerce").dropna().astype(int).tolist())
        league_season_team_count[(league_id, season)] = len(teams)

    team_state = defaultdict(
        lambda: {
            "home_pts": [],
            "away_pts": [],
            "home_gd": [],
            "away_gd": [],
            "opp_pts_pre": [],
            "adj_pts": [],
        }
    )
    season_table = defaultdict(lambda: defaultdict(lambda: {"pts": 0.0, "mp": 0, "gd": 0.0, "gf": 0.0}))
    league_match_idx = defaultdict(int)
    rows: list[dict] = []

    def avg_last(xs: list[float], n: int, fallback: float = 0.0) -> float:
        if not xs:
            return float(fallback)
        return float(np.mean(xs[-n:]))

    for _, r in out.iterrows():
        league_id = int(r["league_id"])
        season = str(r["season"])
        home_id = int(r["home_team_id"])
        away_id = int(r["away_team_id"])
        key = (league_id, season)
        league_match_idx[key] += 1

        hs = team_state[home_id]
        aw = team_state[away_id]
        table = season_table[key]

        home_prev = table[home_id]
        away_prev = table[away_id]

        standings = sorted(
            table.items(),
            key=lambda kv: (
                -kv[1]["pts"],
                -kv[1]["gd"],
                -kv[1]["gf"],
                kv[0],
            ),
        )
        pos_map = {team_id: idx + 1 for idx, (team_id, _) in enumerate(standings)}
        team_count = max(league_season_team_count.get(key, 20), 2)
        relegation_cut = team_count - 2 if team_count <= 18 else team_count - 3

        home_pos = int(pos_map.get(home_id, team_count // 2))
        away_pos = int(pos_map.get(away_id, team_count // 2))

        top1_pts = standings[0][1]["pts"] if standings else 0.0
        top4_pts = standings[min(3, len(standings) - 1)][1]["pts"] if len(standings) >= 4 else 0.0
        relegation_pts = (
            standings[min(relegation_cut - 1, len(standings) - 1)][1]["pts"]
            if len(standings) >= relegation_cut and relegation_cut > 0
            else 0.0
        )

        home_gap_title = max(0.0, top1_pts - home_prev["pts"])
        away_gap_title = max(0.0, top1_pts - away_prev["pts"])
        home_gap_top4 = max(0.0, top4_pts - home_prev["pts"])
        away_gap_top4 = max(0.0, top4_pts - away_prev["pts"])
        home_gap_safe = max(0.0, relegation_pts - home_prev["pts"])
        away_gap_safe = max(0.0, relegation_pts - away_prev["pts"])

        total_matches = max(league_season_total_matches.get(key, 1), 1)
        season_progress = float(league_match_idx[key] / total_matches)
        late_season_flag = float(season_progress >= 0.75)

        home_title_urgency = max(0.0, 1.0 - home_gap_title / 9.0) if home_pos <= 3 else 0.0
        away_title_urgency = max(0.0, 1.0 - away_gap_title / 9.0) if away_pos <= 3 else 0.0
        home_top4_urgency = max(0.0, 1.0 - home_gap_top4 / 6.0) if home_pos <= 8 else 0.0
        away_top4_urgency = max(0.0, 1.0 - away_gap_top4 / 6.0) if away_pos <= 8 else 0.0
        home_releg_urgency = max(0.0, 1.0 - home_gap_safe / 6.0) if home_pos >= relegation_cut - 2 else 0.0
        away_releg_urgency = max(0.0, 1.0 - away_gap_safe / 6.0) if away_pos >= relegation_cut - 2 else 0.0
        home_must_win = max(home_title_urgency, home_top4_urgency, home_releg_urgency)
        away_must_win = max(away_title_urgency, away_top4_urgency, away_releg_urgency)

        home_opp_pre = away_prev["pts"] / max(away_prev["mp"], 1) if away_prev["mp"] > 0 else 1.2
        away_opp_pre = home_prev["pts"] / max(home_prev["mp"], 1) if home_prev["mp"] > 0 else 1.2

        row = {
            "home_points_home_10": avg_last(hs["home_pts"], 10, 1.3),
            "away_points_away_10": avg_last(aw["away_pts"], 10, 1.0),
            "venue_points_diff_10": avg_last(hs["home_pts"], 10, 1.3) - avg_last(aw["away_pts"], 10, 1.0),
            "home_gd_home_10": avg_last(hs["home_gd"], 10, 0.2),
            "away_gd_away_10": avg_last(aw["away_gd"], 10, -0.2),
            "venue_gd_diff_10": avg_last(hs["home_gd"], 10, 0.2) - avg_last(aw["away_gd"], 10, -0.2),
            "home_recent_opp_points_5": avg_last(hs["opp_pts_pre"], 5, 1.2),
            "away_recent_opp_points_5": avg_last(aw["opp_pts_pre"], 5, 1.2),
            "home_adj_points_5": avg_last(hs["adj_pts"], 5, 1.2),
            "away_adj_points_5": avg_last(aw["adj_pts"], 5, 1.2),
            "adj_points_diff_5": avg_last(hs["adj_pts"], 5, 1.2) - avg_last(aw["adj_pts"], 5, 1.2),
            "home_table_position": float(home_pos),
            "away_table_position": float(away_pos),
            "home_points_before": float(home_prev["pts"]),
            "away_points_before": float(away_prev["pts"]),
            "home_matches_before": float(home_prev["mp"]),
            "away_matches_before": float(away_prev["mp"]),
            "position_diff": float(away_pos - home_pos),
            "points_diff_table": float(home_prev["pts"] - away_prev["pts"]),
            "season_progress": season_progress,
            "late_season_flag": late_season_flag,
            "home_gap_title": float(home_gap_title),
            "away_gap_title": float(away_gap_title),
            "home_gap_top4": float(home_gap_top4),
            "away_gap_top4": float(away_gap_top4),
            "home_gap_safe": float(home_gap_safe),
            "away_gap_safe": float(away_gap_safe),
            "home_must_win_score": float(home_must_win),
            "away_must_win_score": float(away_must_win),
            "must_win_diff": float(home_must_win - away_must_win),
        }
        rows.append(row)

        hg = float(r["home_goals"])
        ag = float(r["away_goals"])
        h_pts = 3.0 if hg > ag else 1.0 if hg == ag else 0.0
        a_pts = 3.0 if ag > hg else 1.0 if hg == ag else 0.0
        h_gd = hg - ag
        a_gd = ag - hg

        hs["home_pts"].append(h_pts)
        hs["home_gd"].append(h_gd)
        hs["opp_pts_pre"].append(home_opp_pre)
        hs["adj_pts"].append(h_pts - home_opp_pre + 1.2)

        aw["away_pts"].append(a_pts)
        aw["away_gd"].append(a_gd)
        aw["opp_pts_pre"].append(away_opp_pre)
        aw["adj_pts"].append(a_pts - away_opp_pre + 1.2)

        home_prev["pts"] += h_pts
        home_prev["mp"] += 1
        home_prev["gd"] += h_gd
        home_prev["gf"] += hg

        away_prev["pts"] += a_pts
        away_prev["mp"] += 1
        away_prev["gd"] += a_gd
        away_prev["gf"] += ag

    return pd.concat([out, pd.DataFrame(rows)], axis=1)
