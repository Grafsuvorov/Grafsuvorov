import argparse
from dataclasses import dataclass
from itertools import product
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL


LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}


@dataclass
class RuleSet:
    ev_A: float
    ev_B: float
    min_odds_A: float
    max_odds_A: float
    min_odds_B: float
    max_odds_B: float
    allow_draw: bool = True


def _parse_args():
    p = argparse.ArgumentParser(description="Grid search outcome rules per league")
    p.add_argument("--from", dest="date_from", required=True)
    p.add_argument("--to", dest="date_to", required=True)
    p.add_argument("--min-bets", dest="min_bets", type=int, default=6)
    p.add_argument("--topk", dest="topk", type=int, default=5)
    return p.parse_args()


def _ev(p: float, odds: float) -> float:
    return p * odds - 1.0


def _profit(outcome: str, hg: int, ag: int, odds: float) -> float:
    if outcome == "Home":
        won = hg > ag
    elif outcome == "Draw":
        won = hg == ag
    else:
        won = hg < ag
    return (odds - 1.0) if won else -1.0


def _select_pick(row) -> Tuple[str, float, float, float]:
    options = [
        ("Home", row.p_home, row.avg_odds_home),
        ("Draw", row.p_draw, row.avg_odds_draw),
        ("Away", row.p_away, row.avg_odds_away),
    ]
    best = None
    for outcome, p, odds in options:
        if p is None or odds is None:
            continue
        if not np.isfinite(p) or not np.isfinite(odds):
            continue
        ev = _ev(p, odds)
        if best is None or ev > best[3]:
            best = (outcome, p, odds, ev)
    return best


def _apply_rules(rows: pd.DataFrame, rules: RuleSet) -> pd.DataFrame:
    picks = []
    for r in rows.itertuples(index=False):
        pick = _select_pick(r)
        if not pick:
            continue
        outcome, p, odds, ev = pick
        if outcome == "Draw" and not rules.allow_draw:
            continue
        if odds >= rules.min_odds_A and odds <= rules.max_odds_A and ev >= rules.ev_A:
            tier = "A"
        elif odds >= rules.min_odds_B and odds <= rules.max_odds_B and ev >= rules.ev_B:
            tier = "B"
        else:
            continue
        prof = _profit(outcome, r.home_goals, r.away_goals, odds)
        stake = 1.0 if tier == "A" else 0.5
        picks.append(
            {
                "date": r.date,
                "fixture_id": r.fixture_id,
                "outcome": outcome,
                "p": p,
                "odds": odds,
                "ev": ev,
                "tier": tier,
                "profit": prof * stake,
                "stake": stake,
            }
        )
    return pd.DataFrame(picks)


def _risk_metrics(picks: pd.DataFrame) -> Dict[str, float]:
    if picks.empty:
        return dict(win_rate=np.nan, avg_odds=np.nan, stdev=np.nan, max_dd=np.nan)
    wins = (picks["profit"] > 0).sum()
    win_rate = wins / len(picks)
    avg_odds = picks["odds"].mean()
    stdev = picks["profit"].std(ddof=0)
    # max drawdown on cumulative profit
    cum = picks["profit"].cumsum()
    peak = cum.cummax()
    dd = (cum - peak).min()
    return dict(win_rate=win_rate, avg_odds=avg_odds, stdev=stdev, max_dd=dd)


def main():
    args = _parse_args()
    engine = create_engine(DB_URL)
    q = text(
        """
        SELECT
            p.fixture_id,
            s.league_id,
            s.league_name,
            s.date::date AS date,
            s.home_team,
            s.away_team,
            s.home_goals,
            s.away_goals,
            p.p_home,
            p.p_draw,
            p.p_away,
            m.avg_odds_home,
            m.avg_odds_draw,
            m.avg_odds_away
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s
          ON s.fixture_id = p.fixture_id
        LEFT JOIN football.v_ml_epl_training m
          ON m.fixture_id = p.fixture_id
        WHERE s.date BETWEEN :dfrom AND :dto
          AND s.home_goals IS NOT NULL
          AND s.away_goals IS NOT NULL
        ORDER BY s.date ASC;
        """
    )
    df = pd.read_sql(q, engine, params={"dfrom": args.date_from, "dto": args.date_to})
    if df.empty:
        print("No data in selected period")
        return

    # grids
    ev_A_grid = [0.08, 0.10, 0.12, 0.14, 0.16]
    ev_B_grid = [0.04, 0.06, 0.08, 0.10, 0.12]
    min_odds_A_grid = [1.50, 1.70, 1.90, 2.10]
    max_odds_A_grid = [2.20, 2.40, 2.60]
    min_odds_B_grid = [1.40, 1.60, 1.80, 2.00]
    max_odds_B_grid = [2.60, 2.80, 3.00]

    for lid, lname in LEAGUE_NAMES.items():
        sub = df[df.league_id == lid].copy()
        if sub.empty:
            continue
        results = []
        for evA, evB, minA, maxA, minB, maxB in product(
            ev_A_grid, ev_B_grid, min_odds_A_grid, max_odds_A_grid, min_odds_B_grid, max_odds_B_grid
        ):
            if evB > evA:
                continue
            if minA > maxA or minB > maxB:
                continue
            rules = RuleSet(
                ev_A=evA,
                ev_B=evB,
                min_odds_A=minA,
                max_odds_A=maxA,
                min_odds_B=minB,
                max_odds_B=maxB,
                allow_draw=True,
            )
            picks = _apply_rules(sub, rules)
            if len(picks) < args.min_bets:
                continue
            stake = picks["stake"].sum()
            profit = picks["profit"].sum()
            roi = profit / stake if stake > 0 else np.nan
            risk = _risk_metrics(picks)
            results.append(
                {
                    "ev_A": evA,
                    "ev_B": evB,
                    "min_odds_A": minA,
                    "max_odds_A": maxA,
                    "min_odds_B": minB,
                    "max_odds_B": maxB,
                    "bets": len(picks),
                    "stake": stake,
                    "profit": profit,
                    "roi": roi,
                    "win_rate": risk["win_rate"],
                    "avg_odds": risk["avg_odds"],
                    "stdev": risk["stdev"],
                    "max_dd": risk["max_dd"],
                }
            )
        if not results:
            print(f"\n=== {lname} ({lid}) ===")
            print("No rule sets meet min_bets")
            continue

        res = pd.DataFrame(results)
        # prioritize positive ROI, then more bets
        res = res.sort_values(by=["roi", "bets"], ascending=[False, False])

        print(f"\n=== {lname} ({lid}) TOP {args.topk} ===")
        print(res.head(args.topk).to_string(index=False))


if __name__ == "__main__":
    main()
