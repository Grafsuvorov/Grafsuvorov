import pandas as pd
import numpy as np
from sqlalchemy import create_engine

from config import (
    ALLOWED_BET_TYPES_BY_LEAGUE,
    MIN_EV_BY_TYPE,
    MIN_EV_BY_LEAGUE_BET,
    MIN_BET_ODDS,
)

DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"

DATE_FROM = "2025-11-01"
DATE_TO   = "2026-01-05"

engine = create_engine(DB_URL)

print("Loading data...")

q = """
SELECT
    p.fixture_id,
    s.league_id,
    s.match_date,
    s.home_goals,
    s.away_goals,

    p.p_home,
    p.p_draw,
    p.p_away,
    p.p_over25,

    s.avg_odds_home,
    s.avg_odds_draw,
    s.avg_odds_away,
    s.avg_odds_over25,
    s.avg_odds_under25

FROM football.ml_predictions p
JOIN football.v_ml_epl_training s
  ON s.fixture_id = p.fixture_id
WHERE s.match_date BETWEEN %(dfrom)s AND %(dto)s
  AND s.home_goals IS NOT NULL
  AND s.away_goals IS NOT NULL
"""

df = pd.read_sql(q, engine, params={"dfrom": DATE_FROM, "dto": DATE_TO})
print("Rows:", len(df))


# --------------------
# helpers
# --------------------
def ev(p, odds):
    if pd.isna(p) or pd.isna(odds) or odds <= 1:
        return np.nan
    return p * odds - 1

def profit(win, odds):
    return (odds - 1) if win else -1


def _bet_allowed(league_id, bet_type):
    allowed = ALLOWED_BET_TYPES_BY_LEAGUE.get(int(league_id) if pd.notna(league_id) else -1, set())
    return ("*" in allowed) or (bet_type in allowed)


def _ev_threshold(league_id, bet_type):
    lid = int(league_id) if pd.notna(league_id) else None
    if lid is not None and lid in MIN_EV_BY_LEAGUE_BET:
        return MIN_EV_BY_LEAGUE_BET[lid].get(bet_type, MIN_EV_BY_TYPE.get(bet_type, 0.0))
    return MIN_EV_BY_TYPE.get(bet_type, 0.0)


rows = []

for _, r in df.iterrows():
    total_goals = r.home_goals + r.away_goals

    bets = []

    # 1X2
    bets.append(("1X2", "Home", ev(r.p_home, r.avg_odds_home),
                 r.home_goals > r.away_goals, r.avg_odds_home))

    bets.append(("1X2", "Away", ev(r.p_away, r.avg_odds_away),
                 r.away_goals > r.home_goals, r.avg_odds_away))

    # Totals
    bets.append(("TOTAL", "Over2.5", ev(r.p_over25, r.avg_odds_over25),
                 total_goals >= 3, r.avg_odds_over25))

    bets.append(("TOTAL", "Under2.5", ev(1 - r.p_over25, r.avg_odds_under25),
                 total_goals <= 2, r.avg_odds_under25))

    cand = []
    for bet_type, outcome, ev_val, won, odds in bets:
        if ev_val is None or not np.isfinite(ev_val):
            continue
        if odds is None or odds < MIN_BET_ODDS:
            continue
        if not _bet_allowed(r.league_id, bet_type):
            continue
        if ev_val < _ev_threshold(r.league_id, bet_type):
            continue
        cand.append((bet_type, outcome, ev_val, won, odds))

    if not cand:
        continue

    best = max(cand, key=lambda x: x[2])

    rows.append({
        "fixture_id": r.fixture_id,
        "league_id": r.league_id,
        "bet_type": best[0],
        "bet_outcome": best[1],
        "ev": best[2],
        "profit": profit(best[3], best[4])
    })


res = pd.DataFrame(rows)

print("\nSelected bets:", len(res))


# --------------------
# ROI by league
# --------------------
roi_league = (
    res.groupby(["league_id", "bet_type"])
       .agg(bets=("profit", "count"),
            profit=("profit", "sum"))
       .assign(roi=lambda x: x.profit / x.bets)
       .sort_values("roi", ascending=False)
)

print("\n=== ROI by league & bet type ===")
print(roi_league)


# --------------------
# ROI vs EV thresholds
# --------------------
EV_SCAN = [0.02, 0.04, 0.06, 0.08, 0.10, 0.12]
scan_rows = []

for (lid, btype), grp in res.groupby(["league_id", "bet_type"]):
    for thr in EV_SCAN:
        part = grp[grp["ev"] >= thr]
        if part.empty:
            continue
        bets = len(part)
        prof = part["profit"].sum()
        roi = prof / bets if bets else np.nan
        scan_rows.append({
            "league_id": lid,
            "bet_type": btype,
            "ev_thr": thr,
            "bets": bets,
            "profit": prof,
            "roi": roi,
        })

if scan_rows:
    scan_df = pd.DataFrame(scan_rows)
    scan_df = scan_df.sort_values(["league_id", "bet_type", "ev_thr"])
    print("\n=== ROI by EV threshold (league x bet type) ===")
    print(scan_df.to_string(index=False))
else:
    print("\n=== ROI by EV threshold ===\nNo bets to analyze.")


# --------------------
# DRAW hypothesis
# --------------------
draws = df[
    (abs(df.p_home - df.p_away) <= 0.02) &
    (df.p_draw >= 0.28)
].copy()

draws["ev_draw"] = draws.apply(lambda r: ev(r.p_draw, r.avg_odds_draw), axis=1)
draws = draws[draws.ev_draw >= 0.02]

draws["profit"] = np.where(
    draws.home_goals == draws.away_goals,
    draws.avg_odds_draw - 1,
    -1
)

print("\n=== DRAW hypothesis ===")
print({
    "bets": len(draws),
    "profit": draws.profit.sum(),
    "roi": draws.profit.sum() / len(draws) if len(draws) else None
})
