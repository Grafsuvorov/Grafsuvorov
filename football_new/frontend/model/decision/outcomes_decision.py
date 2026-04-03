from decision.outcome_rules import LEAGUE_OUTCOME_RULES, DEFAULT_OUTCOME_RULE


def decide_outcome_bet(ev: float, odds: float, league_id: int, outcome: str) -> str:
    if ev is None or odds is None:
        return "NO BET"

    rules = LEAGUE_OUTCOME_RULES.get(league_id, DEFAULT_OUTCOME_RULE)

    if outcome == "Draw" and not rules.get("allow_draw", True):
        return "NO BET"

    if outcome == "Draw" and "draw_min_odds_A" in rules:
        min_odds_a = rules["draw_min_odds_A"]
        max_odds_a = rules.get("draw_max_odds_A")
    else:
        min_odds_a = rules["min_odds_A"]
        max_odds_a = rules.get("max_odds_A")

    in_a_odds_band = odds >= min_odds_a and (max_odds_a is None or odds <= max_odds_a)
    if in_a_odds_band and ev >= rules["ev_A"]:
        return "A"

    if outcome == "Draw" and "draw_min_odds_B" in rules:
        min_odds_b = rules["draw_min_odds_B"]
        max_odds_b = rules.get("draw_max_odds_B")
    else:
        min_odds_b = rules["min_odds_B"]
        max_odds_b = rules.get("max_odds_B")

    in_b_odds_band = odds >= min_odds_b and (max_odds_b is None or odds <= max_odds_b)
    if in_b_odds_band and ev >= rules["ev_B"]:
        return "B"

    return "NO BET"
