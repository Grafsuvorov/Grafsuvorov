from __future__ import annotations

import numpy as np
import pandas as pd


def _market_probs(home_odds: float, draw_odds: float, away_odds: float) -> tuple[float, float, float, float]:
    imp_h = 1.0 / float(home_odds)
    imp_d = 1.0 / float(draw_odds)
    imp_a = 1.0 / float(away_odds)
    overround = imp_h + imp_d + imp_a
    p_h = imp_h / overround
    p_d = imp_d / overround
    p_a = imp_a / overround
    entropy = -sum(p * np.log(max(p, 1e-12)) for p in (p_h, p_d, p_a))
    return p_a, p_d, p_h, float(entropy)


def add_timed_market_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()

    open_probs = out.apply(
        lambda r: _market_probs(
            r["avg_odds_home_open"],
            r["avg_odds_draw_open"],
            r["avg_odds_away_open"],
        ),
        axis=1,
        result_type="expand",
    )
    open_probs.columns = ["p_away_open", "p_draw_open", "p_home_open", "market_entropy_open"]

    current_probs = out.apply(
        lambda r: _market_probs(
            r["avg_odds_home_current"],
            r["avg_odds_draw_current"],
            r["avg_odds_away_current"],
        ),
        axis=1,
        result_type="expand",
    )
    current_probs.columns = ["p_away_current", "p_draw_current", "p_home_current", "market_entropy_current"]

    out = pd.concat([out, open_probs, current_probs], axis=1)
    out["overround_open"] = (
        1.0 / pd.to_numeric(out["avg_odds_home_open"], errors="coerce")
        + 1.0 / pd.to_numeric(out["avg_odds_draw_open"], errors="coerce")
        + 1.0 / pd.to_numeric(out["avg_odds_away_open"], errors="coerce")
    )
    out["overround_current"] = (
        1.0 / pd.to_numeric(out["avg_odds_home_current"], errors="coerce")
        + 1.0 / pd.to_numeric(out["avg_odds_draw_current"], errors="coerce")
        + 1.0 / pd.to_numeric(out["avg_odds_away_current"], errors="coerce")
    )
    out["line_move_home"] = out["p_home_current"] - out["p_home_open"]
    out["line_move_draw"] = out["p_draw_current"] - out["p_draw_open"]
    out["line_move_away"] = out["p_away_current"] - out["p_away_open"]
    out["p_away_mkt"] = out["p_away_current"]
    out["p_draw_mkt"] = out["p_draw_current"]
    out["p_home_mkt"] = out["p_home_current"]
    out["favorite_side_open"] = np.argmax(out[["p_away_open", "p_draw_open", "p_home_open"]].to_numpy(), axis=1)
    out["favorite_side_current"] = np.argmax(
        out[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy(),
        axis=1,
    )
    out["favorite_changed_flag"] = (out["favorite_side_open"] != out["favorite_side_current"]).astype(int)
    return out
