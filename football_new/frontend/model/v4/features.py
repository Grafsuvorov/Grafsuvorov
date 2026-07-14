from __future__ import annotations

from collections import defaultdict

import numpy as np
import pandas as pd


def build_result_form_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)

    team_state = defaultdict(
        lambda: {
            "pts": [],
            "gf": [],
            "ga": [],
            "home_pts": [],
            "home_gf": [],
            "home_ga": [],
            "away_pts": [],
            "away_gf": [],
            "away_ga": [],
        }
    )

    rows: list[dict] = []

    def avg_last(xs: list[float], n: int, fallback: float = 0.0) -> float:
        if not xs:
            return float(fallback)
        return float(np.mean(xs[-n:]))

    for _, r in out.iterrows():
        home_id = int(r["home_team_id"])
        away_id = int(r["away_team_id"])
        hs = team_state[home_id]
        aw = team_state[away_id]

        home = {
            "home_points_all_5": avg_last(hs["pts"], 5, 1.2),
            "home_points_all_10": avg_last(hs["pts"], 10, 1.2),
            "home_points_home_5": avg_last(hs["home_pts"], 5, 1.3),
            "home_gf_all_5": avg_last(hs["gf"], 5, 1.3),
            "home_ga_all_5": avg_last(hs["ga"], 5, 1.3),
            "home_gd_all_5": avg_last(hs["gf"], 5, 1.3) - avg_last(hs["ga"], 5, 1.3),
            "home_gf_home_5": avg_last(hs["home_gf"], 5, 1.4),
            "home_ga_home_5": avg_last(hs["home_ga"], 5, 1.1),
        }
        away = {
            "away_points_all_5": avg_last(aw["pts"], 5, 1.2),
            "away_points_all_10": avg_last(aw["pts"], 10, 1.2),
            "away_points_away_5": avg_last(aw["away_pts"], 5, 1.0),
            "away_gf_all_5": avg_last(aw["gf"], 5, 1.1),
            "away_ga_all_5": avg_last(aw["ga"], 5, 1.3),
            "away_gd_all_5": avg_last(aw["gf"], 5, 1.1) - avg_last(aw["ga"], 5, 1.3),
            "away_gf_away_5": avg_last(aw["away_gf"], 5, 1.0),
            "away_ga_away_5": avg_last(aw["away_ga"], 5, 1.4),
        }

        row = {
            **home,
            **away,
            "form_points_diff_5": home["home_points_all_5"] - away["away_points_all_5"],
            "form_points_diff_10": home["home_points_all_10"] - away["away_points_all_10"],
            "venue_points_diff_5": home["home_points_home_5"] - away["away_points_away_5"],
            "gd_diff_5": home["home_gd_all_5"] - away["away_gd_all_5"],
            "attack_vs_def_home_5": home["home_gf_home_5"] - away["away_ga_away_5"],
            "attack_vs_def_away_5": away["away_gf_away_5"] - home["home_ga_home_5"],
        }
        rows.append(row)

        hg = float(r["home_goals"])
        ag = float(r["away_goals"])
        h_pts = 3.0 if hg > ag else 1.0 if hg == ag else 0.0
        a_pts = 3.0 if ag > hg else 1.0 if hg == ag else 0.0

        hs["pts"].append(h_pts)
        hs["gf"].append(hg)
        hs["ga"].append(ag)
        hs["home_pts"].append(h_pts)
        hs["home_gf"].append(hg)
        hs["home_ga"].append(ag)

        aw["pts"].append(a_pts)
        aw["gf"].append(ag)
        aw["ga"].append(hg)
        aw["away_pts"].append(a_pts)
        aw["away_gf"].append(ag)
        aw["away_ga"].append(hg)

    return pd.concat([out, pd.DataFrame(rows)], axis=1)


def add_draw_disagreement_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()

    p_home_mkt = pd.to_numeric(out["p_home_mkt"], errors="coerce").fillna(0.0)
    p_draw_mkt = pd.to_numeric(out["p_draw_mkt"], errors="coerce").fillna(0.0)
    p_away_mkt = pd.to_numeric(out["p_away_mkt"], errors="coerce").fillna(0.0)
    p_home_pois = pd.to_numeric(out["p_home_pois"], errors="coerce").fillna(0.0)
    p_draw_pois = pd.to_numeric(out["p_draw_pois"], errors="coerce").fillna(0.0)
    p_away_pois = pd.to_numeric(out["p_away_pois"], errors="coerce").fillna(0.0)

    out["draw_risk_market"] = p_draw_mkt
    out["draw_risk_poisson"] = p_draw_pois
    out["draw_risk_avg"] = 0.5 * (p_draw_mkt + p_draw_pois)
    out["draw_risk_gap"] = p_draw_pois - p_draw_mkt

    out["market_fav_code"] = np.select(
        [p_home_mkt >= p_draw_mkt, p_away_mkt > p_home_mkt],
        [2.0, 0.0],
        default=1.0,
    )
    out["poisson_fav_code"] = np.select(
        [p_home_pois >= p_draw_pois, p_away_pois > p_home_pois],
        [2.0, 0.0],
        default=1.0,
    )
    out["fav_agree_market_poisson"] = (out["market_fav_code"] == out["poisson_fav_code"]).astype(float)

    out["home_market_minus_poisson"] = p_home_mkt - p_home_pois
    out["draw_market_minus_poisson"] = p_draw_mkt - p_draw_pois
    out["away_market_minus_poisson"] = p_away_mkt - p_away_pois

    out["home_form_vs_market"] = pd.to_numeric(out["form_points_diff_5"], errors="coerce").fillna(0.0) * (
        p_home_mkt - p_away_mkt
    )
    out["draw_balance_proxy"] = (
        pd.to_numeric(out["gd_diff_5"], errors="coerce").fillna(0.0).abs()
        + pd.to_numeric(out["venue_points_diff_5"], errors="coerce").fillna(0.0).abs()
    )
    out["draw_balance_proxy"] = 1.0 / (1.0 + out["draw_balance_proxy"])

    return out
