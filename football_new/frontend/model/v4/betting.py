from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd


OUTCOMES = ["Away", "Draw", "Home"]
ODDS_COLS = ["avg_odds_away", "avg_odds_draw", "avg_odds_home"]
MARKET_COLS = ["p_away_mkt", "p_draw_mkt", "p_home_mkt"]


@dataclass
class BetRule:
    min_ev: float
    min_edge: float
    min_odds: float
    max_odds: float


def build_best_bets(df: pd.DataFrame, probs: np.ndarray, rule: BetRule) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)
    odds = out[ODDS_COLS].to_numpy(dtype="float64")
    market = out[MARKET_COLS].to_numpy(dtype="float64")
    ev = probs * odds - 1.0
    edge = probs - market

    chosen = np.argmax(ev, axis=1)
    chosen_ev = ev[np.arange(len(out)), chosen]
    chosen_edge = edge[np.arange(len(out)), chosen]
    chosen_odds = odds[np.arange(len(out)), chosen]
    chosen_prob = probs[np.arange(len(out)), chosen]

    mask = (
        (chosen_ev >= rule.min_ev)
        & (chosen_edge >= rule.min_edge)
        & (chosen_odds >= rule.min_odds)
        & (chosen_odds <= rule.max_odds)
    )

    bet_df = out.loc[mask].copy()
    if bet_df.empty:
        return bet_df

    bet_idx = np.where(mask)[0]
    bet_df["bet_outcome"] = [OUTCOMES[i] for i in chosen[mask]]
    bet_df["bet_odds"] = chosen_odds[mask]
    bet_df["bet_ev"] = chosen_ev[mask]
    bet_df["bet_edge"] = chosen_edge[mask]
    bet_df["bet_prob"] = chosen_prob[mask]

    actual = np.zeros(len(out), dtype="int64")
    hg = pd.to_numeric(out["home_goals"], errors="coerce").fillna(0).to_numpy()
    ag = pd.to_numeric(out["away_goals"], errors="coerce").fillna(0).to_numpy()
    actual[ag > hg] = 0
    actual[ag == hg] = 1
    actual[hg > ag] = 2
    bet_df["won"] = (actual[bet_idx] == chosen[mask]).astype(int)
    bet_df["profit"] = np.where(bet_df["won"] == 1, bet_df["bet_odds"] - 1.0, -1.0)
    return bet_df


def summarize_bets(bets: pd.DataFrame) -> dict:
    if bets.empty:
        return {
            "bets": 0,
            "wins": 0,
            "hit_rate": 0.0,
            "avg_odds": 0.0,
            "avg_ev": 0.0,
            "profit": 0.0,
            "roi": 0.0,
        }
    return {
        "bets": int(len(bets)),
        "wins": int(bets["won"].sum()),
        "hit_rate": round(float(bets["won"].mean()), 6),
        "avg_odds": round(float(bets["bet_odds"].mean()), 6),
        "avg_ev": round(float(bets["bet_ev"].mean()), 6),
        "profit": round(float(bets["profit"].sum()), 6),
        "roi": round(float(bets["profit"].sum() / len(bets)), 6),
    }


def summarize_bets_by_league(bets: pd.DataFrame) -> list[dict]:
    rows = []
    for league, g in bets.groupby("league", sort=True):
        rows.append({"league": league, **summarize_bets(g)})
    return rows


def optimize_rule(cal_df: pd.DataFrame, probs: np.ndarray) -> tuple[BetRule, dict]:
    best_rule = BetRule(0.05, 0.03, 1.6, 4.0)
    best_summary = summarize_bets(build_best_bets(cal_df, probs, best_rule))
    best_score = (-999.0, -999)

    for min_ev in (0.03, 0.05, 0.08, 0.10):
        for min_edge in (0.00, 0.02, 0.03, 0.05):
            for min_odds, max_odds in ((1.55, 4.0), (1.70, 3.5), (1.80, 3.2)):
                rule = BetRule(min_ev=min_ev, min_edge=min_edge, min_odds=min_odds, max_odds=max_odds)
                bets = build_best_bets(cal_df, probs, rule)
                summary = summarize_bets(bets)
                if summary["bets"] < 20:
                    continue
                score = (summary["roi"], summary["bets"])
                if score > best_score:
                    best_score = score
                    best_rule = rule
                    best_summary = summary
    return best_rule, best_summary

