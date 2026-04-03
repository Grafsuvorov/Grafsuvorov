import argparse
from typing import Dict, Tuple

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL
from decision.outcomes_decision import decide_outcome_bet


LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}


def _parse_args():
    p = argparse.ArgumentParser(description="Evaluate league-specific outcome calibration")
    p.add_argument("--from", dest="date_from", required=True)
    p.add_argument("--to", dest="date_to", required=True)
    p.add_argument("--min-sample", dest="min_sample", type=int, default=30)
    return p.parse_args()


def _sanitize_prob(P: np.ndarray) -> np.ndarray:
    P = np.clip(P, 1e-6, 1 - 1e-6)
    s = P.sum(axis=1, keepdims=True)
    return P / s


def _outcome_from_score(hg: int, ag: int) -> int:
    if hg > ag:
        return 2  # Home
    if hg == ag:
        return 1  # Draw
    return 0  # Away


def _pick_best(p: np.ndarray, odds: np.ndarray) -> Tuple[str, float, float, float]:
    # p order: [Away, Draw, Home]
    labels = ["Away", "Draw", "Home"]
    best = None
    for i, lab in enumerate(labels):
        if not np.isfinite(p[i]) or not np.isfinite(odds[i]):
            continue
        ev = p[i] * odds[i] - 1.0
        if best is None or ev > best[3]:
            best = (lab, float(p[i]), float(odds[i]), float(ev))
    return best


def _profit(outcome: str, hg: int, ag: int, odds: float) -> float:
    if outcome == "Home":
        won = hg > ag
    elif outcome == "Draw":
        won = hg == ag
    else:
        won = hg < ag
    return (odds - 1.0) if won else -1.0


def _summarize(df: pd.DataFrame, tag: str):
    if df.empty:
        print(f"\n=== {tag} ===\nNo bets")
        return
    grp = df.groupby("league_id")
    print(f"\n=== {tag} ===")
    rows = []
    for lid, part in grp:
        stake = part["stake"].sum()
        profit = part["profit"].sum()
        roi = profit / stake if stake > 0 else np.nan
        rows.append(
            dict(
                league_id=lid,
                league=LEAGUE_NAMES.get(lid, str(lid)),
                bets=len(part),
                stake=stake,
                profit=profit,
                roi=roi,
            )
        )
    out = pd.DataFrame(rows).sort_values("league_id")
    print(out.to_string(index=False))


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

    # base P in [Away, Draw, Home]
    P = df[["p_away", "p_draw", "p_home"]].astype(float).to_numpy()
    P = _sanitize_prob(P)
    y = np.array([_outcome_from_score(h, a) for h, a in zip(df.home_goals, df.away_goals)])
    y_onehot = np.eye(3)[y]

    # compute league deltas
    league_bias: Dict[int, np.ndarray] = {}
    for lid, part in df.groupby("league_id"):
        mask = df.league_id == lid
        if mask.sum() < args.min_sample:
            continue
        mean_pred = P[mask.values].mean(axis=0)
        mean_actual = y_onehot[mask.values].mean(axis=0)
        delta = mean_actual - mean_pred
        league_bias[int(lid)] = delta

    print("\n=== League bias (mean_actual - mean_pred) ===")
    for lid in sorted(league_bias.keys()):
        d = league_bias[lid]
        print(f"L{lid} {LEAGUE_NAMES.get(lid, lid)} -> {d}")

    # evaluate base decisions
    base_rows = []
    adj_rows = []
    for i, r in df.iterrows():
        odds = np.array([r.avg_odds_away, r.avg_odds_draw, r.avg_odds_home], dtype=float)
        if not np.isfinite(odds).all():
            continue
        pick = _pick_best(P[i], odds)
        if pick:
            outcome, p, od, ev = pick
            tier = decide_outcome_bet(ev, od, int(r.league_id), outcome)
            if tier in ("A", "B"):
                stake = 1.0 if tier == "A" else 0.5
                base_rows.append(
                    dict(
                        league_id=int(r.league_id),
                        stake=stake,
                        profit=_profit(outcome, r.home_goals, r.away_goals, od) * stake,
                    )
                )

        # apply bias only for leagues we have
        p_adj = P[i].copy()
        delta = league_bias.get(int(r.league_id))
        if delta is not None:
            p_adj = _sanitize_prob((p_adj + delta).reshape(1, -1))[0]
        pick2 = _pick_best(p_adj, odds)
        if pick2:
            outcome, p, od, ev = pick2
            tier = decide_outcome_bet(ev, od, int(r.league_id), outcome)
            if tier in ("A", "B"):
                stake = 1.0 if tier == "A" else 0.5
                adj_rows.append(
                    dict(
                        league_id=int(r.league_id),
                        stake=stake,
                        profit=_profit(outcome, r.home_goals, r.away_goals, od) * stake,
                    )
                )

    base = pd.DataFrame(base_rows)
    adj = pd.DataFrame(adj_rows)

    _summarize(base, "BASE (current probs)")
    _summarize(adj, "AFTER league bias")


if __name__ == "__main__":
    main()
