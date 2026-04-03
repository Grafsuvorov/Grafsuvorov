def allow_bet(row):
    # minimum edge
    if row.edge < 0.10:
        return False

    # minimum odds
    if row.odds < 1.70:
        return False

    # upper bound (junk markets)
    if row.odds > 3.20:
        return False

    # early season / low sample leagues (temporary)
    if row.league_id in {61, 39} and row.sample_league_matches < 200:
        return False

    return True
