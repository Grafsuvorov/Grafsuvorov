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

router = APIRouter(
    prefix="/api",
    tags=["Лучшие ставки"],
    responses={404: {"description": "Not found"}}
)

DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"
engine = create_engine(DB_URL)

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


def _prediction_columns() -> set[str]:
    try:
        insp = inspect(engine)
        cols = insp.get_columns("ml_predictions", schema="football")
        return {c["name"] for c in cols}
    except Exception:
        return set()


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
    ev_min_1x2: float = Query(default=0.04, ge=0.0),
    ev_min_ou: float  = Query(default=0.05, ge=0.0),
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

        with engine.connect() as conn:
            df = pd.read_sql(
                text(q), conn,
                params={
                    "from_date": from_date,
                    "to_date": to_date,
                    "league": league,
                    "season": season,
                    "pre_only": pre_match_only
                }
            )

        df = df.where(pd.notnull(df), None)
        if df.empty:
            return JSONResponse(content=jsonable_encoder({
                "picks": [],
                "fixtures": [] if return_fixtures else None,
                "class_rules": CLASS_RULES
            }))

        rows: List[Dict[str, Any]] = []
        for _, r in df.iterrows():
            offers_raw = _collect_offers(r)
            if not offers_raw:
                continue

            # мягкий server-side prune
            offers = _prune_offers_simple(offers_raw)
            if not offers:
                continue

            # базовые пороги + книги
            books = int(r.get("n_bookmakers")) if r.get("n_bookmakers") is not None else 0
            if min_books and books < min_books:
                continue

            # фильтруем offers по порогам EV (разные для рынков)
            filtered = []
            for o in offers:
                if o["market"] == "1X2" and (o.get("ev") is not None) and (o["ev"] >= ev_min_1x2):
                    filtered.append(o)
                elif o["market"] == "OU25" and (o.get("ev") is not None) and (o["ev"] >= ev_min_ou):
                    filtered.append(o)
            if not filtered:
                continue

            # берём лучший среди прошедших пороги
            best = sorted(filtered, key=lambda x: (x["model_score"], x["ev"]), reverse=True)[0]

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

            rows.append({
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
                "bet_reason": r.get("bet_reason"),
                "offers": filtered,
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
            })

        if not rows:
            return JSONResponse(content=jsonable_encoder({
                "picks": [],
                "fixtures": [] if return_fixtures else None,
                "class_rules": CLASS_RULES
            }))

        picks_df = pd.DataFrame(rows).replace({np.nan: None})
        picks_df = picks_df.sort_values(by=["score", "ev", "p", "pgap"], ascending=[False, False, False, True])
        picks_df = picks_df.head(top_n).reset_index(drop=True)
        picks_list = picks_df.to_dict(orient="records")

        fixtures_payload = None
        if return_fixtures:
            fixtures_payload = []
            for _, r2 in df.iterrows():
                off_raw = _collect_offers(r2)
                if not off_raw: continue
                off = _prune_offers_simple(off_raw)
                if not off: continue
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
                    "n_bookmakers": int(r2["n_bookmakers"]) if r2.get("n_bookmakers") is not None else 0,
                    "offers": off,
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
            "fixtures": fixtures_payload,
            "class_rules": CLASS_RULES
        }))

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
