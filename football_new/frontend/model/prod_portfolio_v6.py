from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd


OUTCOME_LABELS = {"home": "П1", "draw": "Х", "away": "П2"}
TOTAL_LABELS = {"over": "ТБ2.5", "under": "ТМ2.5"}
TARGET_HOME_FIX_LEAGUES = {"La Liga", "Ligue 1"}
OUTCOME_ORDER = ["away", "draw", "home"]

HOME_FIX_MAX_CONF = 0.45
HOME_FIX_MIN_MARKET_HOME = 0.36
HOME_FIX_MIN_HOME_GAP = 0.01

TOTAL_LEAGUE_RULES = {
    78: {"edge_A": 0.06, "edge_B": 0.00, "min_odds_A": 1.55, "max_odds_A": 2.20, "min_odds_B": 1.55, "max_odds_B": 2.20, "exclude_edge_ranges": []},
    135: {"edge_A": 0.08, "edge_B": 0.00, "min_odds_A": 1.45, "max_odds_A": 2.60, "min_odds_B": 1.55, "max_odds_B": 2.20, "exclude_edge_ranges": []},
    39: {"edge_A": 0.08, "edge_B": 0.02, "min_odds_A": 1.65, "max_odds_A": 2.40, "min_odds_B": 1.40, "max_odds_B": 2.40, "exclude_edge_ranges": []},
    140: {"edge_A": 0.16, "edge_B": 0.08, "min_odds_A": 1.70, "max_odds_A": 2.10, "min_odds_B": 1.70, "max_odds_B": 2.10, "exclude_edge_ranges": [(0.06, 0.12)]},
    61: {"edge_A": 0.06, "edge_B": 0.00, "min_odds_A": 1.55, "max_odds_A": 2.00, "min_odds_B": 1.60, "max_odds_B": 2.00, "exclude_edge_ranges": []},
}

TOTAL_DEFAULT_RULE = {
    "edge_A": 0.15,
    "edge_B": 0.12,
    "min_odds_A": 1.60,
    "max_odds_A": None,
    "min_odds_B": 1.75,
    "max_odds_B": None,
    "exclude_edge_ranges": [],
}


def safe_float(x: Any) -> float | None:
    try:
        if x is None:
            return None
        v = float(x)
        if pd.isna(v):
            return None
        return v
    except Exception:
        return None


def clip01(x: float | None) -> float:
    v = safe_float(x)
    if v is None:
        return 0.0
    return max(0.0, min(1.0, v))


def kelly_fraction(p: float | None, odds: float | None) -> float | None:
    p = safe_float(p)
    odds = safe_float(odds)
    if p is None or odds is None:
        return None
    b = odds - 1.0
    if b <= 0:
        return None
    q = 1.0 - p
    return (b * p - q) / b


def decide_total_tier(edge: float | None, odds: float | None, league_id: int | None, p_model: float | None) -> str:
    edge = safe_float(edge)
    odds = safe_float(odds)
    p_model = safe_float(p_model)
    if edge is None or odds is None or p_model is None:
        return "NO BET"
    if not (edge and odds and p_model):
        return "NO BET"

    rules = TOTAL_LEAGUE_RULES.get(int(league_id or -1), TOTAL_DEFAULT_RULE)
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


def bucket_odds(odds: float | None) -> str | None:
    odds = safe_float(odds)
    if odds is None:
        return None
    if odds < 1.55:
        return "<1.55"
    if odds < 1.70:
        return "1.55-1.70"
    if odds < 2.00:
        return "1.70-2.00"
    if odds < 2.40:
        return "2.00-2.40"
    if odds < 3.20:
        return "2.40-3.20"
    if odds < 4.00:
        return "3.20-4.00"
    return "4.00+"


def bucket_total_edge(edge: float | None) -> str | None:
    edge = safe_float(edge)
    if edge is None:
        return None
    if edge < 0.02:
        return "<0.02"
    if edge < 0.05:
        return "0.02-0.05"
    if edge < 0.08:
        return "0.05-0.08"
    if edge < 0.12:
        return "0.08-0.12"
    return "0.12+"


def bucket_total_prob(p_model: float | None) -> str | None:
    p_model = safe_float(p_model)
    if p_model is None:
        return None
    if p_model < 0.52:
        return "0.50-0.52"
    if p_model < 0.56:
        return "0.52-0.56"
    if p_model < 0.60:
        return "0.56-0.60"
    if p_model < 0.65:
        return "0.60-0.65"
    return "0.65+"


def market_probs_1x2(home_odds: Any, draw_odds: Any, away_odds: Any) -> np.ndarray | None:
    home_odds = safe_float(home_odds)
    draw_odds = safe_float(draw_odds)
    away_odds = safe_float(away_odds)
    if None in (home_odds, draw_odds, away_odds):
        return None
    if home_odds <= 0 or draw_odds <= 0 or away_odds <= 0:
        return None
    imp_home = 1.0 / home_odds
    imp_draw = 1.0 / draw_odds
    imp_away = 1.0 / away_odds
    overround = imp_home + imp_draw + imp_away
    if overround <= 0:
        return None
    return np.array([imp_away / overround, imp_draw / overround, imp_home / overround], dtype="float64")


def apply_outcome_home_fix(
    league: str,
    probs: np.ndarray,
    market_probs: np.ndarray,
    max_conf: float = HOME_FIX_MAX_CONF,
    min_market_home: float = HOME_FIX_MIN_MARKET_HOME,
    min_home_gap: float = HOME_FIX_MIN_HOME_GAP,
) -> tuple[int, bool]:
    pred_idx = int(np.argmax(probs))
    model_conf = float(np.max(probs))
    market_pred = int(np.argmax(market_probs))
    market_home = float(market_probs[2])
    market_gap = float(market_probs[2] - max(market_probs[0], market_probs[1]))
    corrected = (
        str(league or "") in TARGET_HOME_FIX_LEAGUES
        and pred_idx != 2
        and model_conf < max_conf
        and market_pred == 2
        and market_home >= min_market_home
        and market_gap >= min_home_gap
    )
    return (2 if corrected else pred_idx, corrected)


def build_v62_outcome_offer(row: pd.Series) -> dict[str, Any] | None:
    p_home = safe_float(row.get("p_home"))
    p_draw = safe_float(row.get("p_draw"))
    p_away = safe_float(row.get("p_away"))
    if None in (p_home, p_draw, p_away):
        return None
    probs = np.array([p_away, p_draw, p_home], dtype="float64")
    probs = np.clip(probs, 1e-6, 1.0 - 1e-6)
    probs = probs / probs.sum()

    market = market_probs_1x2(row.get("avg_odds_home"), row.get("avg_odds_draw"), row.get("avg_odds_away"))
    if market is None:
        return None

    pred_idx, corrected = apply_outcome_home_fix(str(row.get("league") or ""), probs, market)
    outcome = OUTCOME_ORDER[pred_idx]
    odds_map = {
        "home": safe_float(row.get("avg_odds_home")),
        "draw": safe_float(row.get("avg_odds_draw")),
        "away": safe_float(row.get("avg_odds_away")),
    }
    odds = odds_map[outcome]
    p = float(probs[pred_idx])
    market_p = float(market[pred_idx])
    if odds is None:
        return None
    ev = p * odds - 1.0
    edge = p - market_p
    kelly = kelly_fraction(p, odds)
    conf = float(np.max(probs))
    score = float(0.70 * conf + 0.20 * max(edge, 0.0) + 0.10 * max(ev, 0.0))
    note = "v62_home_fix" if corrected else "v62_base"
    return {
        "market": "1X2",
        "outcome": outcome,
        "label": OUTCOME_LABELS[outcome],
        "p": round(p, 4),
        "odds": round(odds, 2),
        "ev": round(ev, 4),
        "kelly": round(kelly, 4) if kelly is not None else None,
        "implied": round(market_p, 4),
        "edge": round(edge, 4),
        "model_class": "predictor",
        "model_score": round(score, 6),
        "agreement": "predictor_v62",
        "portfolio_tier": "AUTO",
        "portfolio_segment": ["v62_predictor", str(row.get("league") or ""), note, outcome],
        "predictor_version": "v62",
        "predictor_note": note,
        "predictor_conf": round(conf, 4),
        "predictor_corrected_home": corrected,
        "p_top1": round(conf, 4),
        "pgap": round(float(np.partition(probs, -1)[-1] - np.partition(probs, -2)[-2]), 4),
    }


def build_total_auto_offers(row: pd.Series) -> list[dict[str, Any]]:
    over_odds = safe_float(row.get("avg_odds_over25"))
    under_odds = safe_float(row.get("avg_odds_under25"))
    p_over = safe_float(row.get("p_over25"))
    if None in (over_odds, under_odds, p_over):
        return []
    if over_odds <= 0 or under_odds <= 0:
        return []

    imp_over = 1.0 / over_odds
    imp_under = 1.0 / under_odds
    overround = imp_over + imp_under
    if overround <= 0:
        return []
    p_over_market = imp_over / overround
    p_under_market = imp_under / overround

    league_id = safe_float(row.get("league_id"))
    p_model_over = float(p_over)
    league_name = str(row.get("league") or "")
    if int(league_id or -1) == 140:
        p_model_over = float(0.9 * p_over + 0.1 * p_over_market)

    if p_model_over >= 0.5:
        outcome = "over"
        p_model = p_model_over
        p_market = p_over_market
        odds = over_odds
    else:
        outcome = "under"
        p_model = 1.0 - p_model_over
        p_market = p_under_market
        odds = under_odds

    edge = float(p_model - p_market)
    ev = float(p_model * odds - 1.0)
    tier = decide_total_tier(edge, odds, int(league_id or -1), p_model)
    if tier == "NO BET":
        return []

    kelly = kelly_fraction(p_model, odds)
    score = float(0.55 * max(ev, 0.0) + 0.25 * max(edge, 0.0) + 0.20 * min(p_model, 0.75))
    total_outcome = "Over2.5" if outcome == "over" else "Under2.5"
    return [
        {
            "market": "OU25",
            "outcome": outcome,
            "label": TOTAL_LABELS[outcome],
            "p": round(float(p_model), 4),
            "odds": round(float(odds), 2),
            "ev": round(ev, 4),
            "kelly": round(kelly, 4) if kelly is not None else None,
            "implied": round(float(p_market), 4),
            "edge": round(edge, 4),
            "model_class": "totals_all",
            "model_score": round(score, 6),
            "agreement": "totals_all_rules",
            "portfolio_tier": "AUTO",
            "portfolio_segment": [
                "all_totals",
                league_name,
                total_outcome,
                tier,
                bucket_odds(odds),
                bucket_total_edge(edge),
                bucket_total_prob(p_model),
            ],
        }
    ]


def build_prod_auto_offers(row: pd.Series) -> list[dict[str, Any]]:
    offers: list[dict[str, Any]] = []
    outcome_offer = build_v62_outcome_offer(row)
    if outcome_offer is not None:
        offers.append(outcome_offer)
    offers.extend(build_total_auto_offers(row))
    offers.sort(key=lambda x: (x["market"] != "1X2", -(x.get("model_score") or -999.0), -(x.get("ev") or -999.0)))
    return offers


def choose_primary_offer(offers: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not offers:
        return None
    return sorted(
        offers,
        key=lambda x: (
            x.get("ev") or -999.0,
            x.get("model_score") or -999.0,
            1 if x["market"] == "OU25" else 0,
        ),
        reverse=True,
    )[0]
