from __future__ import annotations

from collections import defaultdict

import numpy as np
import pandas as pd


def build_v54_xg_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)

    team_state = defaultdict(
        lambda: {
            "xgf": [],
            "xga": [],
            "shots_for": [],
            "shots_against": [],
            "sot_for": [],
            "sot_against": [],
            "home_xgf": [],
            "home_xga": [],
            "away_xgf": [],
            "away_xga": [],
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

        home_xgf_5 = avg_last(hs["xgf"], 5, 1.35)
        home_xga_5 = avg_last(hs["xga"], 5, 1.20)
        away_xgf_5 = avg_last(aw["xgf"], 5, 1.20)
        away_xga_5 = avg_last(aw["xga"], 5, 1.35)
        home_xgf_10 = avg_last(hs["xgf"], 10, 1.35)
        home_xga_10 = avg_last(hs["xga"], 10, 1.20)
        away_xgf_10 = avg_last(aw["xgf"], 10, 1.20)
        away_xga_10 = avg_last(aw["xga"], 10, 1.35)

        row = {
            "home_xgf_5": home_xgf_5,
            "home_xga_5": home_xga_5,
            "away_xgf_5": away_xgf_5,
            "away_xga_5": away_xga_5,
            "home_xgf_10": home_xgf_10,
            "home_xga_10": home_xga_10,
            "away_xgf_10": away_xgf_10,
            "away_xga_10": away_xga_10,
            "home_xgf_home_5": avg_last(hs["home_xgf"], 5, 1.45),
            "home_xga_home_5": avg_last(hs["home_xga"], 5, 1.10),
            "away_xgf_away_5": avg_last(aw["away_xgf"], 5, 1.05),
            "away_xga_away_5": avg_last(aw["away_xga"], 5, 1.45),
            "xg_balance_home_5": home_xgf_5 - home_xga_5,
            "xg_balance_away_5": away_xgf_5 - away_xga_5,
            "xg_balance_diff_5": (home_xgf_5 - home_xga_5) - (away_xgf_5 - away_xga_5),
            "xg_balance_diff_10": (home_xgf_10 - home_xga_10) - (away_xgf_10 - away_xga_10),
            "xg_home_attack_vs_away_def_5": avg_last(hs["home_xgf"], 5, 1.45) - avg_last(aw["away_xga"], 5, 1.45),
            "xg_away_attack_vs_home_def_5": avg_last(aw["away_xgf"], 5, 1.05) - avg_last(hs["home_xga"], 5, 1.10),
            "home_xg_trend_5v10": home_xgf_5 - home_xgf_10,
            "away_xg_trend_5v10": away_xgf_5 - away_xgf_10,
            "home_xga_trend_5v10": home_xga_5 - home_xga_10,
            "away_xga_trend_5v10": away_xga_5 - away_xga_10,
            "home_shots_for_5": avg_last(hs["shots_for"], 5, 12.0),
            "away_shots_for_5": avg_last(aw["shots_for"], 5, 10.5),
            "home_shots_against_5": avg_last(hs["shots_against"], 5, 10.5),
            "away_shots_against_5": avg_last(aw["shots_against"], 5, 12.0),
            "shots_balance_diff_5": (
                avg_last(hs["shots_for"], 5, 12.0) - avg_last(hs["shots_against"], 5, 10.5)
            ) - (
                avg_last(aw["shots_for"], 5, 10.5) - avg_last(aw["shots_against"], 5, 12.0)
            ),
            "home_sot_for_5": avg_last(hs["sot_for"], 5, 4.5),
            "away_sot_for_5": avg_last(aw["sot_for"], 5, 4.0),
            "sot_diff_5": avg_last(hs["sot_for"], 5, 4.5) - avg_last(aw["sot_for"], 5, 4.0),
            "home_xg_per_shot_5": home_xgf_5 / max(avg_last(hs["shots_for"], 5, 12.0), 1e-6),
            "away_xg_per_shot_5": away_xgf_5 / max(avg_last(aw["shots_for"], 5, 10.5), 1e-6),
            "xg_per_shot_diff_5": (
                home_xgf_5 / max(avg_last(hs["shots_for"], 5, 12.0), 1e-6)
            ) - (
                away_xgf_5 / max(avg_last(aw["shots_for"], 5, 10.5), 1e-6)
            ),
        }
        rows.append(row)

        hxg = float(pd.to_numeric(pd.Series([r.get("home_xg")]), errors="coerce").fillna(1.35).iloc[0])
        axg = float(pd.to_numeric(pd.Series([r.get("away_xg")]), errors="coerce").fillna(1.20).iloc[0])
        hshots = float(pd.to_numeric(pd.Series([r.get("home_shots")]), errors="coerce").fillna(12.0).iloc[0])
        ashots = float(pd.to_numeric(pd.Series([r.get("away_shots")]), errors="coerce").fillna(10.5).iloc[0])
        hsot = float(pd.to_numeric(pd.Series([r.get("home_shots_on_goal")]), errors="coerce").fillna(4.5).iloc[0])
        asot = float(pd.to_numeric(pd.Series([r.get("away_shots_on_goal")]), errors="coerce").fillna(4.0).iloc[0])

        hs["xgf"].append(hxg)
        hs["xga"].append(axg)
        hs["shots_for"].append(hshots)
        hs["shots_against"].append(ashots)
        hs["sot_for"].append(hsot)
        hs["sot_against"].append(asot)
        hs["home_xgf"].append(hxg)
        hs["home_xga"].append(axg)

        aw["xgf"].append(axg)
        aw["xga"].append(hxg)
        aw["shots_for"].append(ashots)
        aw["shots_against"].append(hshots)
        aw["sot_for"].append(asot)
        aw["sot_against"].append(hsot)
        aw["away_xgf"].append(axg)
        aw["away_xga"].append(hxg)

    return pd.concat([out, pd.DataFrame(rows)], axis=1)
