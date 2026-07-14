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


def build_season_motivation_features(schedule: pd.DataFrame) -> pd.DataFrame:
    """
    Pre-match league-table and season-phase features.
    No leakage: state is recorded before each fixture and only then updated with the result.
    """
    base = schedule.sort_values(["league_id", "season", "date_utc", "fixture_id"]).copy()
    rows = []

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
        max_games_season = max(1, (n_teams - 1) * 2)
        safe_pos = max(1, n_teams - 3)

        for row in g.itertuples():
            fixture_id = int(row.fixture_id)
            home_id = int(row.home_team_id)
            away_id = int(row.away_team_id)

            ranked = _rank_table([dict(v) for v in standings.values()])
            pos_map = {r["team_id"]: int(r["position"]) for r in ranked}
            points_map = {r["position"]: float(r["points"]) for r in ranked}

            home_state = standings[home_id]
            away_state = standings[away_id]

            round_est = max(int(home_state["games"]), int(away_state["games"])) + 1
            season_progress = float(round_est / max_games_season)

            def _gap(team_state: dict, pos: int) -> float:
                if pos < 1 or pos > n_teams:
                    return np.nan
                return float(team_state["points"] - points_map.get(pos, np.nan))

            home_gap_title = _gap(home_state, 1)
            away_gap_title = _gap(away_state, 1)
            home_gap_top4 = _gap(home_state, min(4, n_teams))
            away_gap_top4 = _gap(away_state, min(4, n_teams))
            home_gap_safe = _gap(home_state, safe_pos)
            away_gap_safe = _gap(away_state, safe_pos)

            def _must_win(position: int, gap_title: float, gap_top4: float, gap_safe: float, progress: float) -> float:
                progress_boost = float(np.clip((progress - 0.45) / 0.45, 0.0, 1.0))
                title_push = np.clip(1.0 - abs(gap_title) / 6.0, 0.0, 1.0) if position <= 4 else 0.0
                top4_push = np.clip(1.0 - abs(gap_top4) / 5.0, 0.0, 1.0) if position <= 8 else 0.0
                relegation_push = np.clip(1.0 - abs(gap_safe) / 4.0, 0.0, 1.0) if position >= safe_pos - 2 else 0.0
                return float(progress_boost * max(title_push, top4_push, relegation_push))

            home_must_win = _must_win(pos_map[home_id], home_gap_title, home_gap_top4, home_gap_safe, season_progress)
            away_must_win = _must_win(pos_map[away_id], away_gap_title, away_gap_top4, away_gap_safe, season_progress)

            home_dead_rubber = int(
                season_progress >= 0.75
                and pos_map[home_id] > 6
                and pos_map[home_id] < safe_pos - 2
                and abs(home_gap_top4) > 8.0
                and abs(home_gap_safe) > 8.0
            )
            away_dead_rubber = int(
                season_progress >= 0.75
                and pos_map[away_id] > 6
                and pos_map[away_id] < safe_pos - 2
                and abs(away_gap_top4) > 8.0
                and abs(away_gap_safe) > 8.0
            )

            rows.append(
                {
                    "fixture_id": fixture_id,
                    "sm_round_estimate": round_est,
                    "sm_season_progress": season_progress,
                    "home_table_position": pos_map[home_id],
                    "away_table_position": pos_map[away_id],
                    "home_points_before": float(home_state["points"]),
                    "away_points_before": float(away_state["points"]),
                    "home_games_before": int(home_state["games"]),
                    "away_games_before": int(away_state["games"]),
                    "home_gap_title": home_gap_title,
                    "away_gap_title": away_gap_title,
                    "home_gap_top4": home_gap_top4,
                    "away_gap_top4": away_gap_top4,
                    "home_gap_safe": home_gap_safe,
                    "away_gap_safe": away_gap_safe,
                    "home_must_win_score": home_must_win,
                    "away_must_win_score": away_must_win,
                    "sm_must_win_diff": float(home_must_win - away_must_win),
                    "home_dead_rubber_flag": home_dead_rubber,
                    "away_dead_rubber_flag": away_dead_rubber,
                    "sm_dead_rubber_any": int(home_dead_rubber or away_dead_rubber),
                    "sm_position_diff": float(pos_map[away_id] - pos_map[home_id]),
                    "sm_points_diff": float(home_state["points"] - away_state["points"]),
                }
            )

            hg = row.home_goals
            ag = row.away_goals
            if pd.notna(hg) and pd.notna(ag):
                hg = float(hg)
                ag = float(ag)
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

    return pd.DataFrame(rows)
