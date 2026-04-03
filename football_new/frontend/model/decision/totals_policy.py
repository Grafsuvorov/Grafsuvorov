import math


def _safe_float(v):
    try:
        x = float(v)
        return x if math.isfinite(x) else None
    except Exception:
        return None


def should_block_total_candidate(row, outcome: str) -> bool:
    """
    Conservative decision-layer filters discovered in season research.
    They are aimed at removing false positives without touching model probs.
    """
    home_npxg5 = _safe_float(row.get("home_us_npxg_all_5"))
    away_npxg5 = _safe_float(row.get("away_us_npxg_all_5"))
    openness = _safe_float(row.get("tp_match_openness"))
    balance_abs = _safe_float(row.get("tp_match_balance_abs"))
    home_xg_ema = _safe_float(row.get("home_xg_ema"))
    away_xg_ema = _safe_float(row.get("away_xg_ema"))
    tempo_sum = _safe_float(row.get("tp_match_tempo_sum"))
    home_attack_xg = _safe_float(row.get("tp_home_attack_xg"))
    away_attack_xg = _safe_float(row.get("tp_away_attack_xg"))
    p_over = _safe_float(row.get("p_over25"))
    p_under = _safe_float(row.get("p_under25"))
    odds_over = _safe_float(row.get("avg_odds_over25"))
    odds_under = _safe_float(row.get("avg_odds_under25"))
    p_home = _safe_float(row.get("p_home"))
    p_away = _safe_float(row.get("p_away"))
    league_id = _safe_float(row.get("league_id"))

    min_npxg5 = None
    npxg_vals = [v for v in (home_npxg5, away_npxg5) if v is not None]
    if npxg_vals:
        min_npxg5 = min(npxg_vals)

    min_xg_ema = None
    xg_ema_vals = [v for v in (home_xg_ema, away_xg_ema) if v is not None]
    if xg_ema_vals:
        min_xg_ema = min(xg_ema_vals)

    dual_attack_floor = None
    dual_attack_vals = [v for v in (home_attack_xg, away_attack_xg) if v is not None]
    if dual_attack_vals:
        dual_attack_floor = min(dual_attack_vals)

    max_xg_ema = None
    if xg_ema_vals:
        max_xg_ema = max(xg_ema_vals)

    if outcome == "Over2.5":
        # EPL still produces too many false overs in compressed or heavily priced matches.
        if league_id == 39:
            if odds_over is not None and odds_over <= 1.80:
                return True
            if p_over is not None and p_over < 0.68:
                return True
            if p_home is not None and p_away is not None:
                if max(p_home, p_away) >= 0.58:
                    return True
            # Strong-favorite EPL matches often stay one-sided and kill the over.
            if max_side_prob := max([v for v in (p_home, p_away) if v is not None], default=None):
                if max_side_prob >= 0.54:
                    if dual_attack_floor is not None and dual_attack_floor <= 1.22:
                        return True
                    if min_npxg5 is not None and min_npxg5 <= 1.08:
                        return True
                    if openness is not None and openness <= 0.22:
                        return True
            if odds_over is not None and odds_over <= 1.95:
                if dual_attack_floor is not None and dual_attack_floor <= 1.18:
                    return True

        # La Liga overs remain noisy unless both teams carry enough attack.
        if league_id == 140:
            if dual_attack_floor is not None and dual_attack_floor <= 1.10:
                return True
            if min_npxg5 is not None and min_npxg5 <= 0.98:
                return True
            if openness is not None and openness <= 0.10:
                return True

        # Closed matchup + weak recent creation on one side.
        if openness is not None and openness <= 0.0 and min_npxg5 is not None and min_npxg5 <= 1.15:
            return True

        # One-sided matches where one team projects low chance volume often fail as overs.
        if balance_abs is not None and balance_abs >= 0.9 and min_xg_ema is not None and min_xg_ema <= 1.15:
            return True

        return False

    if outcome != "Under2.5":
        return False

    max_side_prob = None
    side_probs = [v for v in (p_home, p_away) if v is not None]
    if side_probs:
        max_side_prob = max(side_probs)

    # Serie A unders became too aggressive in matches where the game can break after first goal.
    if league_id == 135:
        if p_under is not None and p_under < 0.70:
            if odds_under is not None and odds_under >= 1.80:
                return True
            if max_side_prob is not None and max_side_prob >= 0.48:
                return True
        if p_under is not None and p_under >= 0.95:
            home_away_gap = None
            if p_home is not None and p_away is not None:
                home_away_gap = abs(p_home - p_away)
            if home_away_gap is not None and home_away_gap <= 0.10:
                return True

    # Do not force an under if both teams project a healthy attacking floor and the matchup is open.
    if dual_attack_floor is not None and dual_attack_floor >= 1.25:
        if openness is not None and openness >= 0.15:
            return True

    # Balanced, reasonably fast games with live recent creation on both sides often punish unders.
    if min_npxg5 is not None and min_npxg5 >= 1.05:
        if tempo_sum is not None and tempo_sum >= 6.0:
            if balance_abs is None or balance_abs <= 0.85:
                return True

    # If the model already leans over and neither side is attack-dead, under is too fragile.
    if p_over is not None and p_over >= 0.53:
        if min_xg_ema is not None and min_xg_ema >= 1.20:
            return True

    # Big-match openness with two non-dead attacks should not be flattened into a low-total call.
    if openness is not None and openness >= 0.35:
        if min_npxg5 is not None and min_npxg5 >= 0.95:
            if dual_attack_floor is not None and dual_attack_floor >= 1.10:
                return True

    # EPL and Ligue 1 are now prone to false unders when both sides retain a viable scoring floor.
    if league_id in {39, 61}:
        if dual_attack_floor is not None and dual_attack_floor >= 1.12:
            if min_npxg5 is not None and min_npxg5 >= 0.98:
                if openness is None or openness >= 0.05:
                    return True

    # La Liga false unders appear in large-quality-gap matches with explosive favorites.
    if league_id == 140:
        if max_xg_ema is not None and max_xg_ema >= 1.85:
            if min_xg_ema is not None and min_xg_ema >= 1.05:
                return True

    return False


def _overlay_candidate(row):
    league_id = _safe_float(row.get("league_id"))
    if league_id is None:
        return None
    league_id = int(league_id)

    p_over = _safe_float(row.get("p_over25"))
    p_under = _safe_float(row.get("p_under25"))
    odds_over = _safe_float(row.get("avg_odds_over25"))
    odds_under = _safe_float(row.get("avg_odds_under25"))

    def _ev(p, odds):
        if p is None or odds is None or odds <= 1.01:
            return None
        return p * odds - 1.0

    if league_id == 39:
        ev_under = _ev(p_under, odds_under)
        if ev_under is not None and ev_under >= 0.10 and odds_under is not None and 1.80 <= odds_under <= 2.55:
            return ("TOTAL", "Under2.5", odds_under, ev_under)
        ev_over = _ev(p_over, odds_over)
        if ev_over is not None and ev_over >= 0.10 and odds_over is not None and 1.65 <= odds_over <= 2.10:
            return ("TOTAL", "Over2.5", odds_over, ev_over)

    if league_id == 61:
        ev_under = _ev(p_under, odds_under)
        if ev_under is not None and ev_under >= 0.08 and odds_under is not None and 1.75 <= odds_under <= 3.2:
            return ("TOTAL", "Under2.5", odds_under, ev_under)

    if league_id == 135:
        ev_under = _ev(p_under, odds_under)
        if ev_under is not None and ev_under >= 0.06 and odds_under is not None and 1.55 <= odds_under <= 1.95:
            return ("TOTAL", "Under2.5", odds_under, ev_under)

    if league_id == 140:
        ev_over = _ev(p_over, odds_over)
        if ev_over is not None and ev_over >= 0.08 and odds_over is not None and 1.95 <= odds_over <= 2.60:
            return ("TOTAL", "Over2.5", odds_over, ev_over)

    return None


def apply_total_league_policy(row, candidates):
    out = list(candidates)
    overlay = _overlay_candidate(row)
    if overlay is not None:
        out.append(overlay)

    deduped = {}
    for market, outcome, odds, edge in out:
        key = (market, outcome)
        if key not in deduped or edge > deduped[key][3]:
            deduped[key] = (market, outcome, odds, edge)
    return list(deduped.values())


def allow_bet(row) -> bool:
    # 1. Minimum edge
    if row.edge < 0.15:
        return False

    # 2. Odds band (remove noise)
    if row.odds < 1.75 or row.odds > 3.10:
        return False

    # 3. Minimum model confidence
    if row.p_model < 0.58:
        return False

    # 4. League gating (temporary)
    if row.league_id in {39, 61}:
        return False

    return True
