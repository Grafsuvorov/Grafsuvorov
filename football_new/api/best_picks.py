# api/best_picks.py
# -*- coding: utf-8 -*-
from fastapi import APIRouter, Query, HTTPException
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
import os
import pandas as pd
from sqlalchemy import create_engine, text, inspect
from typing import Optional, List, Dict, Any
import numpy as np
import traceback
from api.core.config import settings
from api.prod_portfolio_v6 import build_prod_auto_offers, choose_primary_offer

router = APIRouter(
    prefix="/api",
    tags=["Лучшие ставки"],
    responses={404: {"description": "Not found"}}
)

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

# ====================== Utils ======================

def _safe_float(x) -> Optional[float]:
    try:
        if x is None:
            return None
        v = float(x)
        if pd.isna(v):
            return None
        return v
    except Exception:
        return None

def _clip01(x: Optional[float]) -> float:
    v = _safe_float(x)
    if v is None:
        return 0.0
    return max(0.0, min(1.0, v))

def _kelly_fraction(p: Optional[float], odds: Optional[float]) -> Optional[float]:
    p = _safe_float(p)
    odds = _safe_float(odds)
    if p is None or odds is None:
        return None
    b = odds - 1.0
    if b <= 0:
        return None
    q = 1.0 - p
    return (b * p - q) / b

def _format_label(market: str, outcome: str) -> Optional[str]:
    if market == "1X2":
        return {"home": "П1", "draw": "Х", "away": "П2"}.get(outcome)
    if market == "OU25":
        return {"over": "ТБ2.5", "under": "ТМ2.5"}.get(outcome)
    return None

def _strength_rank(bet_rating: Optional[str]) -> int:
    if not bet_rating:
        return 0
    s = str(bet_rating).strip().lower()
    return {"strong": 3, "medium": 2, "weak": 1}.get(s, 0)

# компактные правила классификации
CLASS_RULES = {
    "ev_strong": 0.12,
    "ev_medium": 0.06,
    "ev_weak": 0.03,
    "edge_medium": 0.03
}

BET_DECISION_DISPLAY = {
    "close_gap": float(os.getenv("BET_CLOSE_GAP", 0.08)),
    "close_draw_prob": float(os.getenv("BET_CLOSE_DRAW_PROB", 0.30)),
}

# Conservative live policy derived from the latest settled production season
# on the server (season 2025). The goal is not max coverage, but better hit
# rate / ROI in production.
RESEARCH_POLICY = {
    "only_strong_1x2": True,
    "only_strong_totals": True,
    "blocked_total_leagues": {"La Liga"},
    "medium_total_leagues": {"Premier League", "Bundesliga", "Serie A"},
    "blocked_home_1x2_leagues": {"La Liga", "Ligue 1"},
    "min_away_1x2_ev": 0.10,
    "prefer_1x2_home_min_ev": 0.10,
    "prefer_1x2_home_min_odds": 1.75,
    "prefer_1x2_home_max_odds": 2.25,
    "prefer_1x2_score_gap": 0.12,
    "prefer_1x2_ev_gap": 0.16,
}

# Whitelist of empirically positive segments for the live portfolio.
# Outcome keys:
#   (league, outcome, odds_bucket, edge_bucket, draw_risk_bucket)
# Totals keys:
#   (league, outcome, odds_bucket, edge_bucket, prob_bucket)
GOOD_OUTCOME_SEGMENTS = {
    ("Premier League", "Draw", "4.00+", "-0.02-0.02", "0.26-0.30"),
    ("Premier League", "Home", "1.70-2.00", "0.08-0.12", "0.26-0.30"),
    ("Premier League", "Home", "2.00-2.40", "0.08-0.12", "0.34+"),
    ("Premier League", "Draw", "3.20-4.00", "-0.02-0.02", "0.30-0.34"),
    ("Ligue 1", "Draw", "3.20-4.00", "-0.02-0.02", "0.30-0.34"),
    ("Ligue 1", "Draw", "3.20-4.00", "-0.02-0.02", "0.34+"),
    ("Bundesliga", "Draw", "3.20-4.00", "-0.02-0.02", "0.26-0.30"),
    ("Bundesliga", "Draw", "3.20-4.00", "0.02-0.05", "0.34+"),
    ("Serie A", "Draw", "4.00+", "0.02-0.05", "0.22-0.26"),
    ("Serie A", "Draw", "3.20-4.00", "0.05-0.08", "0.34+"),
    ("Serie A", "Draw", "2.40-3.20", "0.02-0.05", "0.34+"),
    ("Serie A", "Away", "2.40-3.20", "-0.02-0.02", "0.34+"),
    ("Serie A", "Draw", "4.00+", "0.02-0.05", "0.26-0.30"),
    ("Serie A", "Draw", "3.20-4.00", "0.02-0.05", "0.34+"),
    ("Serie A", "Home", "<1.55", "0.05-0.08", "0.22-0.26"),
    ("La Liga", "Draw", "3.20-4.00", "0.02-0.05", "0.30-0.34"),
    ("La Liga", "Draw", "3.20-4.00", "-0.02-0.02", "0.30-0.34"),
}

GOOD_TOTAL_SEGMENTS = {
    ("Premier League", "Over2.5", "1.70-2.00", "0.12+", "0.65+"),
    ("Premier League", "Under2.5", "2.00-2.40", "0.12+", "0.56-0.60"),
    ("Premier League", "Over2.5", "<1.55", "0.12+", "0.65+"),
    ("Premier League", "Under2.5", "1.70-2.00", "0.05-0.08", "0.56-0.60"),
    ("Premier League", "Under2.5", "2.00-2.40", "0.08-0.12", "0.56-0.60"),
    ("Serie A", "Under2.5", "1.55-1.70", "0.08-0.12", "0.65+"),
}


def _bucket_odds(odds: Optional[float]) -> Optional[str]:
    odds = _safe_float(odds)
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


def _bucket_outcome_edge(edge: Optional[float]) -> Optional[str]:
    edge = _safe_float(edge)
    if edge is None:
        return None
    if edge < -0.02:
        return "<-0.02"
    if edge < 0.02:
        return "-0.02-0.02"
    if edge < 0.05:
        return "0.02-0.05"
    if edge < 0.08:
        return "0.05-0.08"
    if edge < 0.12:
        return "0.08-0.12"
    return "0.12+"


def _bucket_total_edge(edge: Optional[float]) -> Optional[str]:
    edge = _safe_float(edge)
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


def _bucket_draw_risk(p_draw: Optional[float]) -> Optional[str]:
    p_draw = _safe_float(p_draw)
    if p_draw is None:
        return None
    if p_draw <= 0.22:
        return "<=0.22"
    if p_draw <= 0.26:
        return "0.22-0.26"
    if p_draw <= 0.30:
        return "0.26-0.30"
    if p_draw <= 0.34:
        return "0.30-0.34"
    return "0.34+"


def _bucket_total_prob(p_model: Optional[float]) -> Optional[str]:
    p_model = _safe_float(p_model)
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


def _portfolio_segment_key(offer: Dict[str, Any], row: pd.Series) -> Optional[tuple]:
    league = str(row.get("league") or "").strip()
    market = str(offer.get("market") or "").upper()
    outcome = str(offer.get("outcome") or "").lower()
    odds_bucket = _bucket_odds(offer.get("odds"))
    if market == "1X2":
        key = (
            league,
            outcome.capitalize(),
            odds_bucket,
            _bucket_outcome_edge(offer.get("edge")),
            _bucket_draw_risk(row.get("p_draw")),
        )
        return key if None not in key else None
    if market == "OU25":
        total_outcome = "Over2.5" if outcome == "over" else "Under2.5" if outcome == "under" else None
        key = (
            league,
            total_outcome,
            odds_bucket,
            _bucket_total_edge(offer.get("edge")),
            _bucket_total_prob(offer.get("p")),
        )
        return key if None not in key else None
    return None


def _passes_portfolio_whitelist(offer: Dict[str, Any], row: pd.Series) -> bool:
    key = _portfolio_segment_key(offer, row)
    if key is None:
        return False
    market = str(offer.get("market") or "").upper()
    if market == "1X2":
        allowed = key in GOOD_OUTCOME_SEGMENTS
    elif market == "OU25":
        allowed = key in GOOD_TOTAL_SEGMENTS
    else:
        allowed = False
    # Late-season EPL anti-under guard:
    # if market strongly leans to Over and Under is the longer contrarian side,
    # we do not want mild 56-59% model unders to survive just because the
    # segment looked good historically.
    if allowed and market == "OU25" and key[0] == "Premier League" and key[1] == "Under2.5":
        round_str = str(row.get("round") or "")
        over_odds = _safe_float(row.get("avg_odds_over25"))
        under_odds = _safe_float(offer.get("odds"))
        is_late_round = any(tag in round_str for tag in ("Regular Season - 36", "Regular Season - 37", "Regular Season - 38"))
        strong_market_over = over_odds is not None and over_odds <= 1.70
        long_under = under_odds is not None and under_odds >= 2.20
        mild_under_prob = (_safe_float(offer.get("p")) or 0.0) < 0.60
        if is_late_round and strong_market_over and long_under and mild_under_prob:
            return False
    if allowed:
        offer["portfolio_segment"] = list(key)
    return allowed


def _prediction_columns() -> set[str]:
    try:
        insp = inspect(engine)
        cols = insp.get_columns("ml_predictions", schema="football")
        return {c["name"] for c in cols}
    except Exception:
        return set()

def _odds_view_available() -> bool:
    try:
        insp = inspect(engine)
        views = set(insp.get_view_names(schema="football"))
        tables = set(insp.get_table_names(schema="football"))
        return "v_ml_epl_training" in views or "v_ml_epl_training" in tables
    except Exception:
        return False


def _select_expr(columns: set[str], name: str, alias: Optional[str] = None, cast: str = "double precision") -> str:
    alias = alias or name
    if name in columns:
        return f"p.{name} AS {alias}"
    return f"NULL::{cast} AS {alias}"

def _classify_signal(p: Optional[float], odds: Optional[float], ev: Optional[float], kelly: Optional[float]) -> Dict[str, Any]:
    p = _safe_float(p); odds = _safe_float(odds); ev = _safe_float(ev)
    kelly_calc = _kelly_fraction(p, odds) if kelly is None else _safe_float(kelly)
    implied = (1.0 / odds) if (odds and odds > 0) else None
    edge = (p - implied) if (p is not None and implied is not None) else None

    if p is None or odds is None or ev is None:
        label = "nobet"
    elif ev < 0 or (kelly_calc is not None and kelly_calc <= 0):
        label = "avoid"
    else:
        if ev >= CLASS_RULES["ev_strong"]:
            label = "strong"
        elif ev >= CLASS_RULES["ev_medium"] and (edge or 0) >= CLASS_RULES["edge_medium"]:
            label = "medium"
        elif ev >= CLASS_RULES["ev_weak"]:
            label = "weak"
        else:
            label = "nobet"

    score = 0.65 * (ev or 0.0) + 0.25 * (edge or 0.0) + 0.10 * _clip01(kelly_calc)
    return {"class": label, "score": float(score), "implied": _safe_float(implied), "edge": _safe_float(edge), "kelly_used": _safe_float(kelly_calc)}

def _offer(market: str, outcome: str, p, odds, ev, kelly) -> Optional[Dict[str, Any]]:
    p = _safe_float(p); odds = _safe_float(odds); ev = _safe_float(ev); kelly = _safe_float(kelly)
    if p is None or odds is None:
        return None
    if ev is None:
        ev = p * odds - 1.0
    if kelly is None:
        kelly = _kelly_fraction(p, odds)
    cls = _classify_signal(p, odds, ev, kelly)
    return {
        "market": market, "outcome": outcome, "label": _format_label(market, outcome),
        "p": round(p, 4), "odds": round(odds, 2),
        "ev": round(ev, 4) if ev is not None else None,
        "kelly": round(kelly, 4) if kelly is not None else None,
        "implied": round(cls["implied"], 4) if cls["implied"] is not None else None,
        "edge": round(cls["edge"], 4) if cls["edge"] is not None else None,
        "model_class": cls["class"], "model_score": round(cls["score"], 6)
    }

def _collect_offers(row: pd.Series) -> List[Dict[str, Any]]:
    offers: List[Dict[str, Any]] = []

    # модельные вероятности для 1X2
    p_home = _safe_float(row.get("p_home")); p_draw = _safe_float(row.get("p_draw")); p_away = _safe_float(row.get("p_away"))
    probs = {"home": p_home, "draw": p_draw, "away": p_away}
    order = sorted(probs.items(), key=lambda kv: (kv[1] if kv[1] is not None else -1), reverse=True)
    top1_out = order[0][0] if order else None
    top2_out = order[1][0] if len(order) > 1 else None
    p_top1 = order[0][1] if (order and order[0][1] is not None) else None
    p_gap = None
    if len(order) > 1 and (order[0][1] is not None) and (order[1][1] is not None):
        p_gap = float(order[0][1] - order[1][1])

    # 1X2
    o1 = _offer("1X2", "home", p_home, row.get("avg_odds_home"), row.get("ev_home"), row.get("kelly_home"))
    o2 = _offer("1X2", "draw", p_draw, row.get("avg_odds_draw"), row.get("ev_draw"), row.get("kelly_draw"))
    o3 = _offer("1X2", "away", p_away, row.get("avg_odds_away"), row.get("ev_away"), row.get("kelly_away"))
    # OU 2.5
    o4 = _offer("OU25", "over",  row.get("p_over25"),  row.get("avg_odds_over25"),  row.get("ev_over"),  row.get("kelly_over"))
    o5 = _offer("OU25", "under", row.get("p_under25"), row.get("avg_odds_under25"), row.get("ev_under"), row.get("kelly_under"))

    def _attach_meta(o: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        if o is None: return None
        o["p_top1"] = p_top1; o["pgap"] = p_gap
        if o["market"] == "1X2":
            outc = o["outcome"]
            if outc == top1_out: o["agreement"] = "aligned"
            elif outc == top2_out: o["agreement"] = "top2"
            else: o["agreement"] = "contrarian"
            o["p_home"], o["p_draw"], o["p_away"] = p_home, p_draw, p_away
        else:
            o["agreement"] = "neutral"
        return o

    for o in [_attach_meta(x) for x in (o1, o2, o3, o4, o5)]:
        if o is not None:
            offers.append(o)

    offers.sort(key=lambda x: (x["model_score"], x["ev"] if x["ev"] is not None else -1), reverse=True)
    return offers


def _decision_meta(notes_raw: Optional[str], p_home: Optional[float], p_away: Optional[float], p_draw: Optional[float]) -> Dict[str, Any]:
    notes = (str(notes_raw or "")).strip()
    p_h = _safe_float(p_home)
    p_a = _safe_float(p_away)
    p_d = _safe_float(p_draw)

    close_gap = BET_DECISION_DISPLAY["close_gap"]
    close_draw = BET_DECISION_DISPLAY["close_draw_prob"]

    close_flag = False
    if p_h is not None and p_a is not None:
        try:
            close_flag = abs(float(p_h) - float(p_a)) <= close_gap
        except Exception:
            close_flag = False

    notes_lower = notes.lower()
    draw_switch = "switch=draw_close" in notes_lower
    total_switch = "switch=total" in notes_lower
    filtered_flag = ("suppress_close_low_ev" in notes_lower) or ("filtered_by_tau" in notes_lower)

    tags: List[str] = []
    if draw_switch:
        tags.append("Draw switch")
    if total_switch:
        tags.append("Total switch")
    if filtered_flag:
        tags.append("Filtered close")

    if not tags:
        if close_flag and (p_d is not None) and (p_d >= close_draw):
            tags.append("Close flagged")

    if not tags:
        tags.append("Baseline")

    return {
        "profile": ", ".join(tags),
        "tags": tags,
        "close_flag": close_flag,
        "draw_switch": draw_switch,
        "total_switch": total_switch,
        "filtered_flag": filtered_flag,
        "notes": notes if notes else None,
    }


def _passes_research_policy(offer: Dict[str, Any], row: pd.Series) -> bool:
    return _passes_portfolio_whitelist(offer, row)


def _passes_watch_policy(offer: Dict[str, Any], row: pd.Series) -> bool:
    if _passes_portfolio_whitelist(offer, row):
        return False
    market = str(offer.get("market") or "").upper()
    outcome = str(offer.get("outcome") or "").lower()
    odds = _safe_float(offer.get("odds"))
    ev = _safe_float(offer.get("ev"))
    p = _safe_float(offer.get("p"))
    edge = _safe_float(offer.get("edge"))
    if odds is None or ev is None or p is None:
        return False
    if ev <= 0:
        return False
    if p >= 0.90 or p <= 0.10:
        return False
    if market == "1X2":
        if odds < 1.55 or odds > 4.00:
            return False
        if outcome == "draw":
            if edge is None or edge < 0:
                return False
            if (_safe_float(row.get("p_draw")) or 0.0) < 0.26:
                return False
        else:
            if edge is None or edge < 0.02:
                return False
            if str(offer.get("agreement") or "").lower() == "contrarian":
                return False
            if p < 0.48:
                return False
        return True
    if market == "OU25":
        if ev < 0.03 or p < 0.54:
            return False
        league = str(row.get("league") or "").strip()
        if league == "Premier League" and outcome == "under":
            over_odds = _safe_float(row.get("avg_odds_over25"))
            if (over_odds is not None and over_odds <= 1.70) and odds >= 2.00:
                return False
        return True
    return False


def _watch_score(offer: Dict[str, Any], row: pd.Series) -> float:
    market = str(offer.get("market") or "").upper()
    outcome = str(offer.get("outcome") or "").lower()
    ev = _safe_float(offer.get("ev")) or 0.0
    edge = _safe_float(offer.get("edge")) or 0.0
    p = _safe_float(offer.get("p")) or 0.0
    odds = _safe_float(offer.get("odds")) or 0.0

    if market == "1X2":
        market_p = {
            "home": _safe_float(offer.get("implied")),
            "draw": _safe_float(offer.get("implied")),
            "away": _safe_float(offer.get("implied")),
        }.get(outcome)
        disagreement = abs((p if p is not None else 0.0) - (market_p if market_p is not None else 0.0))
        moderation_bonus = max(0.0, 0.16 - disagreement)
        draw_bonus = 0.03 if outcome == "draw" and (_safe_float(row.get("p_draw")) or 0.0) >= 0.30 else 0.0
        long_odds_penalty = max(0.0, odds - 3.4) * 0.015
        return float(0.55 * ev + 0.22 * edge + 0.13 * moderation_bonus + 0.10 * min(p, 0.72) + draw_bonus - long_odds_penalty)

    over_odds = _safe_float(row.get("avg_odds_over25"))
    under_odds = _safe_float(row.get("avg_odds_under25"))
    market_p = None
    if outcome == "over" and over_odds and under_odds:
        imp_over = 1.0 / over_odds
        imp_under = 1.0 / under_odds
        market_p = imp_over / (imp_over + imp_under)
    elif outcome == "under" and over_odds and under_odds:
        imp_over = 1.0 / over_odds
        imp_under = 1.0 / under_odds
        market_p = imp_under / (imp_over + imp_under)
    disagreement = abs((p if p is not None else 0.0) - (market_p if market_p is not None else 0.0))
    moderation_bonus = max(0.0, 0.14 - disagreement)
    contrarian_penalty = 0.0
    if str(row.get("league") or "").strip() == "Premier League" and outcome == "under" and over_odds is not None and over_odds <= 1.75:
        contrarian_penalty = 0.05
    long_odds_penalty = max(0.0, odds - 2.4) * 0.02
    return float(0.52 * ev + 0.24 * edge + 0.14 * moderation_bonus + 0.10 * min(p, 0.68) - contrarian_penalty - long_odds_penalty)


def _choose_best_offer(filtered: List[Dict[str, Any]]) -> Dict[str, Any]:
    ranked = sorted(filtered, key=lambda x: (x["model_score"], x["ev"]), reverse=True)
    best = ranked[0]

    if best["market"] != "1X2":
        best_1x2 = next(
            (
                o for o in ranked
                if o["market"] == "1X2"
                and str(o.get("outcome")).lower() == "home"
                and str(o.get("model_class")).lower() == "strong"
                and (o.get("ev") is not None and o["ev"] >= RESEARCH_POLICY["prefer_1x2_home_min_ev"])
                and (o.get("odds") is not None and RESEARCH_POLICY["prefer_1x2_home_min_odds"] <= o["odds"] <= RESEARCH_POLICY["prefer_1x2_home_max_odds"])
            ),
            None,
        )
        if best_1x2 is not None:
            score_gap = float(best["model_score"] - best_1x2["model_score"])
            ev_gap = float(best["ev"] - best_1x2["ev"])
            if score_gap <= RESEARCH_POLICY["prefer_1x2_score_gap"] and ev_gap <= RESEARCH_POLICY["prefer_1x2_ev_gap"]:
                return best_1x2

    return best


def _choose_watch_offer(filtered: List[Dict[str, Any]]) -> Dict[str, Any]:
    return sorted(filtered, key=lambda x: (x.get("watch_score", -999.0), x["ev"], x["model_score"]), reverse=True)[0]

# аккуратный «подрезатель» (мягче прежнего)
def _prune_offers_simple(offers: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    if not offers: return out

    # контекст blowout
    p_top1_vals = [o.get("p_top1") for o in offers if o.get("p_top1") is not None]
    pgap_vals   = [o.get("pgap") for o in offers if o.get("pgap") is not None]
    blowout = (max(p_top1_vals) >= 0.62 if p_top1_vals else False) or (max(pgap_vals) >= 0.22 if pgap_vals else False)

    for o in offers:
        mkt, outc = o["market"], o["outcome"]
        ev = o.get("ev"); odds = o.get("odds"); p = o.get("p")
        if mkt == "OU25":
            if ev is None or ev < 0.05: continue
            if p is None or p < 0.52: continue
            out.append(o); continue
        if mkt == "1X2":
            if odds is None or odds >= 7.0: continue                # жёстко отрезаем сильно длинные
            if o.get("agreement") == "contrarian": continue         # без контры
            if blowout and o.get("agreement") != "aligned": continue
            if outc == "draw":
                if any(v is None for v in (o.get("p_home"), o.get("p_away"), o.get("p_draw"))): continue
                if abs(o["p_home"] - o["p_away"]) > 0.06: continue  # ничья — только «близкие» матчи
                if o["p_draw"] < 0.24: continue
                if odds > 5.7: continue
                if ev is None or ev <= 0: continue
                out.append(o); continue
            # П1/П2
            if o.get("agreement") == "aligned" and p is not None and p < 0.52: continue
            if o.get("agreement") == "top2":
                if p is None or p < 0.45: continue
                if o.get("pgap") is None or o["pgap"] > 0.07: continue
            if ev is None or ev <= 0: continue
            out.append(o)
    out.sort(key=lambda x: (x["model_score"], x["ev"] if x.get("ev") is not None else -1), reverse=True)
    return out

# ====================== Endpoint ======================

@router.get("/best-picks")
def best_picks(
    from_date: str,
    to_date: str,
    league: str = Query(default=None, description="Опционально: ограничить одной лигой"),
    season: str = Query(default=None, description="Опционально: год сезона, напр. 2025"),

    pre_match_only: bool = Query(default=True, description="Брать предикты только с ts_generated <= kickoff"),
    min_books: int = Query(default=3, ge=0, description="Мин. число букмекеров (0 = не фильтровать)"),
    ev_min_1x2: float = Query(default=0.06, ge=0.0),
    ev_min_ou: float  = Query(default=0.06, ge=0.0),
    top_n: int = Query(default=40, ge=1, le=200),

    return_fixtures: bool = Query(default=False, description="Вернуть все матчи с очищенными offers"),
):
    try:
        # Ключевое: выбираем ПОСЛЕДНЮЮ запись по ts_generated на fixture
        # и, если pre_match_only=True, отсекаем post-kickoff.
        pred_cols = _prediction_columns()
        best_bet_type_expr = _select_expr(pred_cols, "best_bet_type", cast="text")
        best_bet_outcome_expr = _select_expr(pred_cols, "best_bet_outcome", cast="text")
        best_bet_ev_expr = _select_expr(pred_cols, "best_bet_ev")
        best_bet_odds_expr = _select_expr(pred_cols, "best_bet_odds")
        bet_decision_notes_expr = _select_expr(pred_cols, "bet_decision_notes", cast="text")

        has_odds_view = _odds_view_available()
        odds_home_expr = "p.avg_odds_home"
        odds_draw_expr = "p.avg_odds_draw"
        odds_away_expr = "p.avg_odds_away"
        odds_over_expr = "p.avg_odds_over25"
        odds_under_expr = "p.avg_odds_under25"
        odds_join_sql = ""
        if has_odds_view:
            odds_home_expr = "COALESCE(p.avg_odds_home, v.avg_odds_home)"
            odds_draw_expr = "COALESCE(p.avg_odds_draw, v.avg_odds_draw)"
            odds_away_expr = "COALESCE(p.avg_odds_away, v.avg_odds_away)"
            odds_over_expr = "COALESCE(p.avg_odds_over25, v.avg_odds_over25)"
            odds_under_expr = "COALESCE(p.avg_odds_under25, v.avg_odds_under25)"
            odds_join_sql = "LEFT JOIN football.v_ml_epl_training v ON v.fixture_id = b.fixture_id"

        q = f"""
        WITH base AS (
          SELECT
            s.fixture_id::bigint AS fixture_id,
            s.round,
            s.date::date AS date,
            s.league_name AS league,
            s.season::text AS season,
            s.home_team, s.away_team,
            s.home_team_id, s.away_team_id,
            s.date AS kickoff_ts
          FROM football.api_football_schedule s
          WHERE s.date::date BETWEEN :from_date AND :to_date
            AND (:season IS NULL OR s.season::text = :season)
            AND (:league IS NULL OR s.league_name = :league)
        ),
        preds_latest AS (
          SELECT *
          FROM (
            SELECT
              p.*,
              ROW_NUMBER() OVER (PARTITION BY p.fixture_id ORDER BY p.ts_generated DESC NULLS LAST) AS rn
            FROM football.ml_predictions p
            JOIN base b ON b.fixture_id = p.fixture_id
            WHERE (:pre_only = FALSE OR p.ts_generated <= b.kickoff_ts)
          ) z
          WHERE z.rn = 1
        )
        SELECT
          b.fixture_id, b.date, b.league, b.season, b.round,
          b.home_team, b.away_team, b.home_team_id, b.away_team_id,
          p.p_home, p.p_draw, p.p_away,
          p.p_over25, p.p_under25,
          p.n_bookmakers,
          {odds_home_expr} AS avg_odds_home,
          {odds_draw_expr} AS avg_odds_draw,
          {odds_away_expr} AS avg_odds_away,
          {odds_over_expr} AS avg_odds_over25,
          {odds_under_expr} AS avg_odds_under25,
          p.ev_home, p.ev_draw, p.ev_away, p.ev_over, p.ev_under,
          p.kelly_home, p.kelly_draw, p.kelly_away, p.kelly_over, p.kelly_under,
          p.bet_rating, p.bet_reason,
          {best_bet_type_expr},
          {best_bet_outcome_expr},
          {best_bet_ev_expr},
          {best_bet_odds_expr},
          {bet_decision_notes_expr}
        FROM base b
        LEFT JOIN preds_latest p ON p.fixture_id = b.fixture_id
        {odds_join_sql}
        ORDER BY b.date ASC, b.league, b.home_team;
        """

        def _run_query(sql: str) -> pd.DataFrame:
            with engine.connect() as conn:
                return pd.read_sql(
                    text(sql), conn,
                    params={
                        "from_date": from_date,
                        "to_date": to_date,
                        "league": league,
                        "season": season,
                        "pre_only": pre_match_only
                    }
                )

        try:
            df = _run_query(q)
        except Exception:
            print("[best-picks] primary query failed:")
            print(traceback.format_exc())
            # fallback: если odds-view недоступна/ломается — повторяем без JOIN/COALESCE
            if has_odds_view:
                q_fallback = f"""
                WITH base AS (
                  SELECT
                    s.fixture_id::bigint AS fixture_id,
                    s.round,
                    s.date::date AS date,
                    s.league_name AS league,
                    s.season::text AS season,
                    s.home_team, s.away_team,
                    s.home_team_id, s.away_team_id,
                    s.date AS kickoff_ts
                  FROM football.api_football_schedule s
                  WHERE s.date::date BETWEEN :from_date AND :to_date
                    AND (:season IS NULL OR s.season::text = :season)
                    AND (:league IS NULL OR s.league_name = :league)
                ),
                preds_latest AS (
                  SELECT *
                  FROM (
                    SELECT
                      p.*,
                      ROW_NUMBER() OVER (PARTITION BY p.fixture_id ORDER BY p.ts_generated DESC NULLS LAST) AS rn
                    FROM football.ml_predictions p
                    JOIN base b ON b.fixture_id = p.fixture_id
                    WHERE (:pre_only = FALSE OR p.ts_generated <= b.kickoff_ts)
                  ) z
                  WHERE z.rn = 1
                )
                SELECT
                  b.fixture_id, b.date, b.league, b.season, b.round,
                  b.home_team, b.away_team, b.home_team_id, b.away_team_id,
                  p.p_home, p.p_draw, p.p_away,
                  p.p_over25, p.p_under25,
                  p.n_bookmakers,
                  p.avg_odds_home, p.avg_odds_draw, p.avg_odds_away,
                  p.avg_odds_over25, p.avg_odds_under25,
                  p.ev_home, p.ev_draw, p.ev_away, p.ev_over, p.ev_under,
                  p.kelly_home, p.kelly_draw, p.kelly_away, p.kelly_over, p.kelly_under,
                  p.bet_rating, p.bet_reason,
                  {best_bet_type_expr},
                  {best_bet_outcome_expr},
                  {best_bet_ev_expr},
                  {best_bet_odds_expr},
                  {bet_decision_notes_expr}
                FROM base b
                LEFT JOIN preds_latest p ON p.fixture_id = b.fixture_id
                ORDER BY b.date ASC, b.league, b.home_team;
                """
                try:
                    df = _run_query(q_fallback)
                except Exception:
                    print("[best-picks] fallback query failed:")
                    print(traceback.format_exc())
                    raise
            else:
                raise

        df = df.where(pd.notnull(df), None)
        if df.empty:
            return JSONResponse(content=jsonable_encoder({
                "picks": [],
                "fixtures": [] if return_fixtures else None,
                "class_rules": CLASS_RULES
            }))

        rows: List[Dict[str, Any]] = []
        watch_rows: List[Dict[str, Any]] = []
        for _, r in df.iterrows():
            books = int(_safe_float(r.get("n_bookmakers")) or 0)
            if min_books and books < min_books:
                continue

            auto_offers = []
            for o in build_prod_auto_offers(r):
                market_ev_min = ev_min_1x2 if o["market"] == "1X2" else ev_min_ou
                if o.get("market") == "1X2" or ((o.get("ev") is not None) and (o["ev"] >= market_ev_min)):
                    auto_offers.append(o)
            watch_filtered: List[Dict[str, Any]] = []
            if not auto_offers:
                continue

            best = choose_primary_offer(auto_offers)
            if best is None:
                continue
            active_offers = auto_offers
            portfolio_tier = "AUTO"

            decision_meta = _decision_meta(
                r.get("bet_decision_notes"),
                r.get("p_home"),
                r.get("p_away"),
                r.get("p_draw"),
            )

            decision_tags = list(decision_meta.get("tags", []))
            decision_close_flag = bool(decision_meta.get("close_flag"))
            decision_draw_switch = bool(decision_meta.get("draw_switch"))
            decision_total_switch = bool(decision_meta.get("total_switch"))

            outcome_lower = str(best["outcome"]).lower()
            market_lower = str(best["market"]).lower()

            if decision_meta.get("notes") in (None, ""):
                if market_lower == "1x2" and outcome_lower == "draw" and decision_close_flag:
                    decision_draw_switch = True
                if market_lower == "ou25" and best.get("ev") is not None and best["ev"] >= 0.02:
                    decision_total_switch = True

            if decision_draw_switch and "Draw switch" not in decision_tags:
                decision_tags = [t for t in decision_tags if t.lower() != "baseline"]
                decision_tags.append("Draw switch")
            if decision_total_switch and "Total switch" not in decision_tags:
                decision_tags = [t for t in decision_tags if t.lower() != "baseline"]
                decision_tags.append("Total switch")
            if decision_close_flag and "Close flagged" not in decision_tags:
                decision_tags.append("Close flagged")
            if not decision_tags:
                decision_tags = ["Baseline"]

            decision_profile_val = decision_meta.get("profile")
            if not decision_profile_val or decision_profile_val.strip() in ("", "Baseline"):
                decision_profile_val = ", ".join(decision_tags)

            best_bet_type_val = r.get("best_bet_type")
            best_bet_outcome_val = r.get("best_bet_outcome")
            best_bet_ev_val = _safe_float(r.get("best_bet_ev"))
            best_bet_odds_val = _safe_float(r.get("best_bet_odds"))

            row_payload = {
                "fixture_id": int(r["fixture_id"]),
                "date": str(pd.to_datetime(r["date"]).date()),
                "league": r["league"],
                "season": r["season"],
                "round": r.get("round"),
                "home_team": r["home_team"],
                "away_team": r["away_team"],
                "home_team_id": int(r["home_team_id"]) if r.get("home_team_id") is not None else None,
                "away_team_id": int(r["away_team_id"]) if r.get("away_team_id") is not None else None,

                "market": best["market"],
                "outcome": best["outcome"],
                "label": best["label"],
                "agreement": best.get("agreement"),
                "pgap": best.get("pgap"),

                "p": round(best["p"], 4),
                "odds": round(best["odds"], 2),
                "ev": round(best["ev"], 4),
                "kelly": round(best["kelly"], 4) if best.get("kelly") is not None else None,
                "n_bookmakers": books,
                "bet_rating": (str(r.get("bet_rating")).lower().strip() if r.get("bet_rating") is not None else "none"),
                "edge_prob": best.get("edge"),
                "score": round(best["model_score"], 6),
                "watch_score": best.get("watch_score"),
                "portfolio_segment": best.get("portfolio_segment"),
                "portfolio_tier": portfolio_tier,
                "bet_reason": r.get("bet_reason"),
                "offers": active_offers,
                "best_bet_type": (str(best_bet_type_val) if best_bet_type_val is not None else None),
                "best_bet_outcome": (str(best_bet_outcome_val) if best_bet_outcome_val is not None else None),
                "best_bet_ev": best_bet_ev_val,
                "best_bet_odds": best_bet_odds_val,
                "bet_decision_notes": decision_meta.get("notes"),
                "decision_profile": decision_profile_val,
                "decision_tags": decision_tags,
                "decision_close_flag": decision_close_flag,
                "decision_draw_switch": decision_draw_switch,
                "decision_total_switch": decision_total_switch,
            }
            rows.append(row_payload)

        if not rows and not watch_rows:
            return JSONResponse(content=jsonable_encoder({
                "picks": [],
                "watch_picks": [],
                "fixtures": [] if return_fixtures else None,
                "class_rules": CLASS_RULES
            }))

        picks_df = pd.DataFrame(rows).replace({np.nan: None})
        if not picks_df.empty:
            picks_df = picks_df.sort_values(by=["score", "ev", "p", "pgap"], ascending=[False, False, False, True])
            picks_df = picks_df.head(top_n).reset_index(drop=True)
            picks_list = picks_df.to_dict(orient="records")
        else:
            picks_list = []

        watch_df = pd.DataFrame(watch_rows).replace({np.nan: None})
        if not watch_df.empty:
            watch_df = watch_df.sort_values(by=["score", "ev", "p", "pgap"], ascending=[False, False, False, True])
            watch_df = watch_df.head(top_n).reset_index(drop=True)
            watch_list = watch_df.to_dict(orient="records")
        else:
            watch_list = []

        fixtures_payload = None
        if return_fixtures:
            fixtures_payload = []
            for _, r2 in df.iterrows():
                auto_off = []
                for o in build_prod_auto_offers(r2):
                    market_ev_min = ev_min_1x2 if o["market"] == "1X2" else ev_min_ou
                    if o.get("market") == "1X2" or ((o.get("ev") is not None) and (o["ev"] >= market_ev_min)):
                        auto_off.append(o)
                watch_off: List[Dict[str, Any]] = []
                if not auto_off:
                    continue
                off = auto_off
                best_bet_type_val = r2.get("best_bet_type")
                best_bet_outcome_val = r2.get("best_bet_outcome")
                best_bet_ev_val = _safe_float(r2.get("best_bet_ev"))
                best_bet_odds_val = _safe_float(r2.get("best_bet_odds"))
                decision_meta_r2 = _decision_meta(
                    r2.get("bet_decision_notes"),
                    r2.get("p_home"),
                    r2.get("p_away"),
                    r2.get("p_draw"),
                )
                decision_tags_r2 = list(decision_meta_r2.get("tags", []))
                decision_close_flag_r2 = bool(decision_meta_r2.get("close_flag"))
                decision_draw_switch_r2 = bool(decision_meta_r2.get("draw_switch"))
                decision_total_switch_r2 = bool(decision_meta_r2.get("total_switch"))

                if decision_meta_r2.get("notes") in (None, ""):
                    if best_bet_type_val and str(best_bet_type_val).upper() == "1X2" and str(best_bet_outcome_val).capitalize() == "Draw" and decision_close_flag_r2:
                        decision_draw_switch_r2 = True
                    best_bet_type_upper = str(best_bet_type_val or "").upper()
                    if best_bet_type_upper in {"OVER25", "UNDER25"} and (best_bet_ev_val is not None and best_bet_ev_val >= 0.02):
                        decision_total_switch_r2 = True

                if decision_draw_switch_r2 and "Draw switch" not in decision_tags_r2:
                    decision_tags_r2 = [t for t in decision_tags_r2 if t.lower() != "baseline"]
                    decision_tags_r2.append("Draw switch")
                if decision_total_switch_r2 and "Total switch" not in decision_tags_r2:
                    decision_tags_r2 = [t for t in decision_tags_r2 if t.lower() != "baseline"]
                    decision_tags_r2.append("Total switch")
                if decision_close_flag_r2 and "Close flagged" not in decision_tags_r2:
                    decision_tags_r2.append("Close flagged")
                if not decision_tags_r2:
                    decision_tags_r2 = ["Baseline"]
                decision_profile_r2 = decision_meta_r2.get("profile")
                if not decision_profile_r2 or decision_profile_r2.strip() in ("", "Baseline"):
                    decision_profile_r2 = ", ".join(decision_tags_r2)
                fixtures_payload.append({
                    "fixture_id": int(r2["fixture_id"]),
                    "date": str(pd.to_datetime(r2["date"]).date()),
                    "league": r2["league"],
                    "season": r2["season"],
                    "round": r2.get("round"),
                    "home_team": r2["home_team"],
                    "away_team": r2["away_team"],
                    "home_team_id": int(r2["home_team_id"]) if r2.get("home_team_id") is not None else None,
                    "away_team_id": int(r2["away_team_id"]) if r2.get("away_team_id") is not None else None,
                    "n_bookmakers": int(_safe_float(r2.get("n_bookmakers")) or 0),
                    "offers": off,
                    "auto_offers": auto_off,
                    "watch_offers": watch_off,
                    "portfolio_mode": "AUTO",
                    "watch_reason": None,
                    "portfolio_segments": [o.get("portfolio_segment") for o in auto_off if o.get("portfolio_segment")],
                    "watch_segments": [o.get("portfolio_segment") for o in watch_off if o.get("portfolio_segment")],
                    "best_bet_type": (str(best_bet_type_val) if best_bet_type_val is not None else None),
                    "best_bet_outcome": (str(best_bet_outcome_val) if best_bet_outcome_val is not None else None),
                    "best_bet_ev": best_bet_ev_val,
                    "best_bet_odds": best_bet_odds_val,
                    "bet_decision_notes": decision_meta_r2.get("notes"),
                    "decision_profile": decision_profile_r2,
                    "decision_tags": decision_tags_r2,
                    "decision_close_flag": decision_close_flag_r2,
                    "decision_draw_switch": decision_draw_switch_r2,
                    "decision_total_switch": decision_total_switch_r2,
                })

        return JSONResponse(content=jsonable_encoder({
            "picks": picks_list,
            "watch_picks": watch_list,
            "fixtures": fixtures_payload,
            "class_rules": CLASS_RULES
        }))

    except Exception as e:
        print("[best-picks] handler failed:")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
