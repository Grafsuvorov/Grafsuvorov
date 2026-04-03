from decision.league_rules import LEAGUE_RULES, DEFAULT_RULE


def decide_total_bet(edge: float, odds: float, league_id: int, p_model: float) -> str:
    if not (edge and odds and p_model):
        return "NO BET"

    rules = LEAGUE_RULES.get(league_id, DEFAULT_RULE)
    for edge_min, edge_max in rules.get("exclude_edge_ranges", []):
        if edge_min <= edge < edge_max:
            return "NO BET"

    max_odds_a = rules.get("max_odds_A")
    in_a_odds_band = odds >= rules["min_odds_A"] and (max_odds_a is None or odds <= max_odds_a)
    if in_a_odds_band and edge >= rules["edge_A"]:
        return "A"

    max_odds_b = rules.get("max_odds_B")
    in_b_odds_band = odds >= rules["min_odds_B"] and (max_odds_b is None or odds <= max_odds_b)
    if in_b_odds_band and edge >= rules["edge_B"]:
        return "B"

    return "NO BET"
