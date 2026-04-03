LEAGUE_RULES = {
    78: {  # Bundesliga
        "edge_A": 0.06,
        "edge_B": 0.00,
        "min_odds_A": 1.55,
        "max_odds_A": 2.20,
        "min_odds_B": 1.55,
        "max_odds_B": 2.20,
    },
    135: {  # Serie A
        "edge_A": 0.08,
        "edge_B": 0.00,
        "min_odds_A": 1.45,
        "max_odds_A": 2.60,
        "min_odds_B": 1.55,
        "max_odds_B": 2.20,
    },
    39: {  # Premier League
        "edge_A": 0.08,
        "edge_B": 0.02,
        "min_odds_A": 1.65,
        "max_odds_A": 2.40,
        "min_odds_B": 1.40,
        "max_odds_B": 2.40,
        # EPL: allow full edge range, no exclude band
        "exclude_edge_ranges": [],
    },
    140: {  # La Liga
        "edge_A": 0.16,
        "edge_B": 0.08,
        "min_odds_A": 1.70,
        "max_odds_A": 2.10,
        "min_odds_B": 1.70,
        "max_odds_B": 2.10,
        # La Liga anti-noise zone from backtest diagnostics.
        "exclude_edge_ranges": [(0.06, 0.12)],
    },
    61: {  # Ligue 1
        "edge_A": 0.06,
        "edge_B": 0.00,
        "min_odds_A": 1.55,
        "max_odds_A": 2.00,
        "min_odds_B": 1.60,
        "max_odds_B": 2.00,
    },
}

DEFAULT_RULE = {
    "edge_A": 0.15,
    "edge_B": 0.12,
    "min_odds_A": 1.60,
    "min_odds_B": 1.75,
}
