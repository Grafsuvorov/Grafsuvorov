import json

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL


LEAGUE_RULES = {
    78: {"edge_A": 0.06, "edge_B": 0.00, "min_odds_A": 1.55, "max_odds_A": 2.20, "min_odds_B": 1.55, "max_odds_B": 2.20, "exclude_edge_ranges": []},
    135: {"edge_A": 0.08, "edge_B": 0.00, "min_odds_A": 1.45, "max_odds_A": 2.60, "min_odds_B": 1.55, "max_odds_B": 2.20, "exclude_edge_ranges": []},
    39: {"edge_A": 0.08, "edge_B": 0.02, "min_odds_A": 1.65, "max_odds_A": 2.40, "min_odds_B": 1.40, "max_odds_B": 2.40, "exclude_edge_ranges": []},
    140: {"edge_A": 0.16, "edge_B": 0.08, "min_odds_A": 1.70, "max_odds_A": 2.10, "min_odds_B": 1.70, "max_odds_B": 2.10, "exclude_edge_ranges": [(0.06, 0.12)]},
    61: {"edge_A": 0.06, "edge_B": 0.00, "min_odds_A": 1.55, "max_odds_A": 2.00, "min_odds_B": 1.60, "max_odds_B": 2.00, "exclude_edge_ranges": []},
}

DEFAULT_RULE = {
    "edge_A": 0.15,
    "edge_B": 0.12,
    "min_odds_A": 1.60,
    "max_odds_A": None,
    "min_odds_B": 1.75,
    "max_odds_B": None,
    "exclude_edge_ranges": [],
}


def decide_total_bet(edge: float | None, odds: float | None, league_id: int, p_model: float | None) -> str:
    if edge is None or odds is None or p_model is None:
        return "NO BET"
    try:
        edge = float(edge)
        odds = float(odds)
        p_model = float(p_model)
    except Exception:
        return "NO BET"
    if not (edge and odds and p_model):
        return "NO BET"

    rules = LEAGUE_RULES.get(int(league_id), DEFAULT_RULE)
    for edge_min, edge_max in rules.get("exclude_edge_ranges", []):
        if edge_min <= edge < edge_max:
            return "NO BET"

    max_odds_a = rules.get("max_odds_A")
    if odds >= rules["min_odds_A"] and (max_odds_a is None or odds <= max_odds_a) and edge >= rules["edge_A"]:
        return "A"

    max_odds_b = rules.get("max_odds_B")
    if odds >= rules["min_odds_B"] and (max_odds_b is None or odds <= max_odds_b) and edge >= rules["edge_B"]:
        return "B"

    return "NO BET"


def main() -> None:
    engine = create_engine(DB_URL)
    q = text(
        """
        SELECT
            s.fixture_id,
            s.league_id,
            s.date,
            s.home_goals,
            s.away_goals,
            p.p_over25,
            m.avg_odds_over25,
            m.avg_odds_under25
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s ON s.fixture_id = p.fixture_id
        JOIN football.v_ml_epl_training m ON m.fixture_id = p.fixture_id
        WHERE s.date BETWEEN '2025-07-01' AND '2026-06-30'
          AND s.home_goals IS NOT NULL
          AND s.away_goals IS NOT NULL
          AND s.league_id IN (39, 61, 78, 135, 140)
        """
    )
    df = pd.read_sql(q, engine)
    for c in ["p_over25", "avg_odds_over25", "avg_odds_under25"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")

    imp_over = 1.0 / df["avg_odds_over25"].replace(0, np.nan)
    imp_under = 1.0 / df["avg_odds_under25"].replace(0, np.nan)
    overround = imp_over + imp_under
    df["p_market_over"] = imp_over / overround
    df["p_market_under"] = imp_under / overround
    df["p_model_over"] = df["p_over25"]

    laliga = df["league_id"] == 140
    df.loc[laliga, "p_model_over"] = (
        0.9 * df.loc[laliga, "p_over25"] + 0.1 * df.loc[laliga, "p_market_over"]
    )
    df["p_model_under"] = 1.0 - df["p_model_over"]
    df["side"] = np.where(df["p_model_over"] >= 0.5, "Over2.5", "Under2.5")
    df["odds"] = np.where(df["side"] == "Over2.5", df["avg_odds_over25"], df["avg_odds_under25"])
    df["edge"] = np.where(
        df["side"] == "Over2.5",
        df["p_model_over"] - df["p_market_over"],
        df["p_model_under"] - df["p_market_under"],
    )
    df["prob_side"] = np.where(df["side"] == "Over2.5", df["p_model_over"], df["p_model_under"])
    df["tier"] = [
        decide_total_bet(edge, odds, lid, p)
        for edge, odds, lid, p in zip(df["edge"], df["odds"], df["league_id"], df["prob_side"])
    ]
    df = df[df["tier"].isin(["A", "B"])].copy()

    goals = df["home_goals"] + df["away_goals"]
    df["won"] = np.where(df["side"] == "Over2.5", goals > 2.5, goals <= 2.5)
    df["stake"] = np.where(df["tier"] == "A", 1.0, 0.4)
    df["profit_raw"] = np.where(df["won"], df["odds"] - 1.0, -1.0)
    df["profit"] = df["profit_raw"] * df["stake"]

    overall = {
        "bets": int(len(df)),
        "wins": int(df["won"].sum()),
        "hit_rate": float(df["won"].mean()) if len(df) else None,
        "avg_odds": float(df["odds"].mean()) if len(df) else None,
        "profit": float(df["profit"].sum()),
        "roi": float(df["profit"].sum() / df["stake"].sum()) if len(df) else None,
    }
    by_side = (
        df.groupby("side")
        .agg(
            bets=("fixture_id", "count"),
            wins=("won", "sum"),
            avg_odds=("odds", "mean"),
            profit=("profit", "sum"),
            stake=("stake", "sum"),
        )
        .assign(roi=lambda x: x["profit"] / x["stake"])
        .to_dict("index")
    )
    by_league = (
        df.groupby("league_id")
        .agg(bets=("fixture_id", "count"), wins=("won", "sum"), profit=("profit", "sum"), stake=("stake", "sum"))
        .assign(roi=lambda x: x["profit"] / x["stake"])
        .to_dict("index")
    )
    print(json.dumps({"overall": overall, "by_side": by_side, "by_league": by_league}, ensure_ascii=False))


if __name__ == "__main__":
    main()
