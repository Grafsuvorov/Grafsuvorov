import numpy as np
import pandas as pd


def _safe_float(v):
    try:
        x = float(v)
        return x if np.isfinite(x) else np.nan
    except Exception:
        return np.nan


def _draw_overlay_candidate(row):
    league_id = int(row.get("league_id")) if pd.notna(row.get("league_id")) else None
    if league_id not in {61, 135, 140}:
        return None

    p_home = _safe_float(row.get("p_home"))
    p_draw = _safe_float(row.get("p_draw"))
    p_away = _safe_float(row.get("p_away"))
    odds_draw = _safe_float(row.get("avg_odds_draw"))
    openness = _safe_float(row.get("tp_match_openness"))
    balance_abs = _safe_float(row.get("tp_match_balance_abs"))
    if not (np.isfinite(p_home) and np.isfinite(p_draw) and np.isfinite(p_away) and np.isfinite(odds_draw) and odds_draw > 1.01):
        return None

    probs = np.array([p_home, p_draw, p_away], dtype=float)
    top2 = np.sort(probs)[-2:]
    gap_top2 = float(top2[1] - top2[0])
    ha_gap = float(abs(p_home - p_away))
    ev_draw = float(p_draw * odds_draw - 1.0)

    # Liga-specific draw zones found in season-2025 research.
    if league_id == 140:
        if ev_draw >= 0.04 and 2.4 <= odds_draw <= 4.5 and gap_top2 <= 0.02 and ha_gap <= 0.20:
            return ("1X2", "Draw", odds_draw, ev_draw)

    if league_id == 135:
        if ev_draw >= 0.04 and 3.0 <= odds_draw <= 4.5 and gap_top2 <= 0.10 and ha_gap <= 0.12:
            return ("1X2", "Draw", odds_draw, ev_draw)

    # Ligue 1 and Bundesliga benefit from a narrower draw-overlay only in slow, balanced games.
    if league_id == 61:
        if (
            ev_draw >= 0.06 and 3.0 <= odds_draw <= 4.2 and gap_top2 <= 0.05 and ha_gap <= 0.12
            and (not np.isfinite(openness) or openness <= 0.10)
            and (not np.isfinite(balance_abs) or balance_abs <= 0.10)
        ):
            return ("1X2", "Draw", odds_draw, ev_draw)

    return None


def _should_block_outcome_candidate(row, outcome: str):
    balance_abs = _safe_float(row.get("tp_match_balance_abs"))
    openness = _safe_float(row.get("tp_match_openness"))
    p_draw = _safe_float(row.get("p_draw"))
    p_home = _safe_float(row.get("p_home"))
    p_away = _safe_float(row.get("p_away"))
    draw_balance_elo_abs = _safe_float(row.get("osc_draw_balance_elo_abs"))
    draw_balance_control_abs = _safe_float(row.get("osc_draw_balance_control_abs"))
    draw_balance_front_abs = _safe_float(row.get("osc_draw_balance_front_abs"))
    league_id = int(row.get("league_id")) if pd.notna(row.get("league_id")) else None

    # Hard league-specific allowlists from realized ROI. These are intentionally
    # conservative and keep only the side families that remained profitable.
    if league_id == 39 and outcome == "Home":
        return True
    if league_id == 61 and outcome != "Home":
        return True
    if league_id == 78 and outcome != "Away":
        return True
    if league_id == 135 and outcome != "Draw":
        return True
    if league_id == 140 and outcome != "Home":
        return True

    # Serie A draw remained the main toxic residual segment. Keep only truly
    # balanced draw scripts and block pretty-price draws in mismatched games.
    if league_id == 135 and outcome == "Draw":
        if np.isfinite(balance_abs) and balance_abs >= 0.28:
            return True
        if np.isfinite(draw_balance_elo_abs) and draw_balance_elo_abs >= 140:
            return True
        if np.isfinite(draw_balance_control_abs) and draw_balance_control_abs >= 2.8:
            return True
        if np.isfinite(draw_balance_front_abs) and draw_balance_front_abs >= 0.22:
            return True

    if not np.isfinite(balance_abs) and not np.isfinite(openness):
        return False

    # Very balanced matches are poor spots for forcing a side.
    if outcome in {"Home", "Away"} and np.isfinite(balance_abs) and balance_abs <= 0.08:
        return True

    # A draw candidate is much less attractive once balance is gone.
    if outcome == "Draw" and np.isfinite(balance_abs) and balance_abs >= 0.22:
        return True

    # Slow and balanced games with healthy draw probability should not be forced into a side.
    if outcome in {"Home", "Away"}:
        if np.isfinite(p_draw) and p_draw >= 0.29:
            if (not np.isfinite(balance_abs) or balance_abs <= 0.12) and (not np.isfinite(openness) or openness <= 0.10):
                return True

    # Bundesliga home/away sides were overcalled in compressed matches.
    if league_id == 78 and outcome in {"Home", "Away"}:
        if np.isfinite(balance_abs) and balance_abs <= 0.14:
            if not np.isfinite(openness) or openness <= 0.14:
                return True
        if outcome == "Home":
            if np.isfinite(p_draw) and p_draw >= 0.26:
                return True
    if league_id == 78 and outcome == "Draw":
        return True

    # Ligue 1 away/home calls are noisy in low-openness matches unless one side clearly separates.
    if league_id == 61 and outcome in {"Home", "Away"}:
        side_gap = abs(p_home - p_away) if np.isfinite(p_home) and np.isfinite(p_away) else np.nan
        if np.isfinite(side_gap) and side_gap <= 0.14:
            if not np.isfinite(openness) or openness <= 0.12:
                return True
        if outcome == "Away":
            if np.isfinite(side_gap) and side_gap <= 0.18:
                return True

    # EPL home calls have been over-aggressive in relatively balanced matches.
    if league_id == 39 and outcome == "Home":
        side_gap = abs(p_home - p_away) if np.isfinite(p_home) and np.isfinite(p_away) else np.nan
        if np.isfinite(side_gap) and side_gap <= 0.24:
            return True
        if np.isfinite(p_draw) and p_draw >= 0.22:
            return True

    # Serie A away sides underperform unless the away edge is very clear; draw remains the stronger signal.
    if league_id == 135 and outcome == "Away":
        side_gap = abs(p_home - p_away) if np.isfinite(p_home) and np.isfinite(p_away) else np.nan
        if np.isfinite(side_gap) and side_gap <= 0.24:
            return True
        if np.isfinite(p_draw) and p_draw >= 0.24:
            return True

    return False


def apply_outcome_league_policy(row, candidates):
    """
    Allows league-specific overlays on top of baseline outcome candidates.
    Returns an updated candidate list in the same (type, name, odds, ev) shape.
    """
    out = [
        candidate
        for candidate in candidates
        if not (candidate[0] == "1X2" and _should_block_outcome_candidate(row, candidate[1]))
    ]
    draw_overlay = _draw_overlay_candidate(row)
    if draw_overlay is not None:
        out.append(draw_overlay)
    return out
