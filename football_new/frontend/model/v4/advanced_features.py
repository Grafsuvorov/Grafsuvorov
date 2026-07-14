from __future__ import annotations

from collections import defaultdict

import numpy as np
import pandas as pd


def add_market_context_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    probs = out[["p_away_mkt", "p_draw_mkt", "p_home_mkt"]].to_numpy(dtype="float64")
    probs = np.clip(probs, 1e-9, 1.0)
    out["market_entropy"] = -(probs * np.log(probs)).sum(axis=1)
    out["market_home_fav"] = (out["p_home_mkt"] == out[["p_home_mkt", "p_draw_mkt", "p_away_mkt"]].max(axis=1)).astype(float)
    out["market_away_fav"] = (out["p_away_mkt"] == out[["p_home_mkt", "p_draw_mkt", "p_away_mkt"]].max(axis=1)).astype(float)
    imp_h = 1.0 / out["avg_odds_home"].replace(0, np.nan)
    imp_d = 1.0 / out["avg_odds_draw"].replace(0, np.nan)
    imp_a = 1.0 / out["avg_odds_away"].replace(0, np.nan)
    out["market_overround_1x2"] = imp_h + imp_d + imp_a
    return out


def build_match_stat_rolling_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)
    team_state = defaultdict(
        lambda: {
            "xg": [],
            "xga": [],
            "shots": [],
            "shots_on_goal": [],
            "possession": [],
            "corners": [],
            "dangerous_attacks": [],
            "home_xg": [],
            "home_xga": [],
            "away_xg": [],
            "away_xga": [],
        }
    )

    def avg_last(xs: list[float], n: int, fallback: float = 0.0) -> float:
        if not xs:
            return float(fallback)
        return float(np.mean(xs[-n:]))

    rows: list[dict] = []
    for _, r in out.iterrows():
        home_id = int(r["home_team_id"])
        away_id = int(r["away_team_id"])
        hs = team_state[home_id]
        aw = team_state[away_id]

        home_xg5 = avg_last(hs["xg"], 5, 1.35)
        away_xg5 = avg_last(aw["xg"], 5, 1.15)
        home_xga5 = avg_last(hs["xga"], 5, 1.15)
        away_xga5 = avg_last(aw["xga"], 5, 1.35)
        home_xg_home5 = avg_last(hs["home_xg"], 5, 1.40)
        away_xg_away5 = avg_last(aw["away_xg"], 5, 1.05)
        home_xga_home5 = avg_last(hs["home_xga"], 5, 1.05)
        away_xga_away5 = avg_last(aw["away_xga"], 5, 1.40)

        home_shots5 = avg_last(hs["shots"], 5, 11.0)
        away_shots5 = avg_last(aw["shots"], 5, 10.0)
        home_sot5 = avg_last(hs["shots_on_goal"], 5, 4.0)
        away_sot5 = avg_last(aw["shots_on_goal"], 5, 3.5)
        home_poss5 = avg_last(hs["possession"], 5, 50.0)
        away_poss5 = avg_last(aw["possession"], 5, 50.0)
        home_corners5 = avg_last(hs["corners"], 5, 5.0)
        away_corners5 = avg_last(aw["corners"], 5, 4.5)
        home_da5 = avg_last(hs["dangerous_attacks"], 5, 40.0)
        away_da5 = avg_last(aw["dangerous_attacks"], 5, 38.0)

        rows.append(
            {
                "home_xg_all_5": home_xg5,
                "away_xg_all_5": away_xg5,
                "home_xga_all_5": home_xga5,
                "away_xga_all_5": away_xga5,
                "home_xg_home_5": home_xg_home5,
                "away_xg_away_5": away_xg_away5,
                "home_xga_home_5": home_xga_home5,
                "away_xga_away_5": away_xga_away5,
                "xg_diff_5": home_xg5 - away_xg5,
                "xga_diff_5": away_xga5 - home_xga5,
                "xg_matchup_home_5": home_xg_home5 - away_xga_away5,
                "xg_matchup_away_5": away_xg_away5 - home_xga_home5,
                "home_shots_all_5": home_shots5,
                "away_shots_all_5": away_shots5,
                "shots_diff_5": home_shots5 - away_shots5,
                "home_sot_all_5": home_sot5,
                "away_sot_all_5": away_sot5,
                "sot_diff_5": home_sot5 - away_sot5,
                "home_possession_all_5": home_poss5,
                "away_possession_all_5": away_poss5,
                "possession_diff_5": home_poss5 - away_poss5,
                "home_corners_all_5": home_corners5,
                "away_corners_all_5": away_corners5,
                "corners_diff_5": home_corners5 - away_corners5,
                "home_dangerous_attacks_all_5": home_da5,
                "away_dangerous_attacks_all_5": away_da5,
                "dangerous_attacks_diff_5": home_da5 - away_da5,
                "home_xg_per_shot_5": home_xg5 / max(home_shots5, 1e-6),
                "away_xg_per_shot_5": away_xg5 / max(away_shots5, 1e-6),
            }
        )

        hxg = float(r["home_xg"]) if pd.notna(r["home_xg"]) else np.nan
        axg = float(r["away_xg"]) if pd.notna(r["away_xg"]) else np.nan
        hshots = float(r["home_shots"]) if pd.notna(r["home_shots"]) else np.nan
        ashots = float(r["away_shots"]) if pd.notna(r["away_shots"]) else np.nan
        hsot = float(r["home_shots_on_goal"]) if pd.notna(r["home_shots_on_goal"]) else np.nan
        asot = float(r["away_shots_on_goal"]) if pd.notna(r["away_shots_on_goal"]) else np.nan
        hposs = float(r["home_possession"]) if pd.notna(r["home_possession"]) else np.nan
        aposs = float(r["away_possession"]) if pd.notna(r["away_possession"]) else np.nan
        hcorn = float(r["home_corners"]) if pd.notna(r["home_corners"]) else np.nan
        acorn = float(r["away_corners"]) if pd.notna(r["away_corners"]) else np.nan
        hda = float(r["home_dangerous_attacks"]) if pd.notna(r["home_dangerous_attacks"]) else np.nan
        ada = float(r["away_dangerous_attacks"]) if pd.notna(r["away_dangerous_attacks"]) else np.nan

        if not np.isnan(hxg):
            hs["xg"].append(hxg)
            hs["home_xg"].append(hxg)
        if not np.isnan(axg):
            hs["xga"].append(axg)
            hs["home_xga"].append(axg)
        if not np.isnan(hshots):
            hs["shots"].append(hshots)
        if not np.isnan(hsot):
            hs["shots_on_goal"].append(hsot)
        if not np.isnan(hposs):
            hs["possession"].append(hposs)
        if not np.isnan(hcorn):
            hs["corners"].append(hcorn)
        if not np.isnan(hda):
            hs["dangerous_attacks"].append(hda)

        if not np.isnan(axg):
            aw["xg"].append(axg)
            aw["away_xg"].append(axg)
        if not np.isnan(hxg):
            aw["xga"].append(hxg)
            aw["away_xga"].append(hxg)
        if not np.isnan(ashots):
            aw["shots"].append(ashots)
        if not np.isnan(asot):
            aw["shots_on_goal"].append(asot)
        if not np.isnan(aposs):
            aw["possession"].append(aposs)
        if not np.isnan(acorn):
            aw["corners"].append(acorn)
        if not np.isnan(ada):
            aw["dangerous_attacks"].append(ada)

    return pd.concat([out, pd.DataFrame(rows)], axis=1)

