# api/graf_picks.py
from fastapi import APIRouter, Query
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
from sqlalchemy import create_engine, text
from datetime import date, timedelta
from typing import Optional, List, Dict, Any
import pandas as pd

router = APIRouter(
    prefix="/api",
    tags=["Графические прогнозы"],
    responses={404: {"description": "Not found"}}
)

DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"
engine = create_engine(DB_URL)

# ---------------- helpers ----------------
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

def _kelly_fraction(p: Optional[float], odds: Optional[float]) -> Optional[float]:
    p = _safe_float(p); odds = _safe_float(odds)
    if p is None or odds is None:
        return None
    b = odds - 1.0
    if b <= 0:
        return None
    q = 1.0 - p
    return (b * p - q) / b

def _classify_signal(p, odds, ev, kelly):
    p = _safe_float(p); odds = _safe_float(odds); ev = _safe_float(ev)
    kelly_calc = _kelly_fraction(p, odds) if kelly is None else _safe_float(kelly)
    implied = (1.0 / odds) if (odds and odds > 0) else None
    edge = (p - implied) if (p is not None and implied is not None) else None
    if p is None or odds is None or ev is None:
        label = "nobet"
    elif ev < 0 or (kelly_calc is not None and kelly_calc <= 0):
        label = "avoid"
    else:
        e = ev; ed = edge or 0.0
        if e >= 0.15 or (e >= 0.10 and ed >= 0.05):
            label = "strong"
        elif e >= 0.07 and ed >= 0.03:
            label = "medium"
        elif e >= 0.03:
            label = "weak"
        else:
            label = "nobet"
    score = 0.6 * (ev or 0.0) + 0.3 * (edge or 0.0) + 0.1 * (kelly_calc or 0.0)
    return {"class": label, "implied": implied, "edge": edge, "score": float(score)}

def _offer_1x2(outcome: str, row: pd.Series, top1_out: Optional[str], top2_out: Optional[str], p_gap: Optional[float]):
    p = _safe_float(row.get({"home":"p_home","draw":"p_draw","away":"p_away"}[outcome]))
    odds = _safe_float(row.get({"home":"avg_odds_home","draw":"avg_odds_draw","away":"avg_odds_away"}[outcome]))
    ev = _safe_float(row.get({"home":"ev_home","draw":"ev_draw","away":"ev_away"}[outcome]))
    kelly = _safe_float(row.get({"home":"kelly_home","draw":"kelly_draw","away":"kelly_away"}[outcome]))
    if p is None or odds is None:
        return None
    cls = _classify_signal(p, odds, ev, kelly)
    return {
        "market": "1X2",
        "outcome": outcome,
        "label": {"home":"П1","draw":"Х","away":"П2"}[outcome],
        "p": round(p, 4),
        "odds": round(odds, 2),
        "ev": round(ev, 4) if ev is not None else None,
        "kelly": round(kelly, 4) if kelly is not None else None,
        "implied": round(cls["implied"], 4) if cls["implied"] is not None else None,
        "edge": round(cls["edge"], 4) if cls["edge"] is not None else None,
        "model_class": cls["class"],
        "model_score": round(cls["score"], 6),
        "agreement": "aligned" if outcome == top1_out else ("top2" if outcome == top2_out else "contrarian"),
        "pgap": p_gap,
    }

def _offer_ou(side: str, row: pd.Series):
    # side: "over" | "under" (2.5)
    p = _safe_float(row.get({"over":"p_over25","under":"p_under25"}[side]))
    odds = _safe_float(row.get({"over":"avg_odds_over25","under":"avg_odds_under25"}[side]))
    ev = _safe_float(row.get({"over":"ev_over","under":"ev_under"}[side]))
    kelly = _safe_float(row.get({"over":"kelly_over","under":"kelly_under"}[side]))
    if p is None or odds is None:
        return None
    cls = _classify_signal(p, odds, ev, kelly)
    return {
        "market": "OU25",
        "outcome": side,
        "label": {"over":"ТБ2.5","under":"ТМ2.5"}[side],
        "p": round(p, 4),
        "odds": round(odds, 2),
        "ev": round(ev, 4) if ev is not None else None,
        "kelly": round(kelly, 4) if kelly is not None else None,
        "implied": round(cls["implied"], 4) if cls["implied"] is not None else None,
        "edge": round(cls["edge"], 4) if cls["edge"] is not None else None,
        "model_class": cls["class"],
        "model_score": round(cls["score"], 6),
        "agreement": "neutral",
        "pgap": None,
    }

def _collect_best_1x2(row: pd.Series) -> Optional[Dict[str, Any]]:
    p_home = _safe_float(row.get("p_home")); p_draw = _safe_float(row.get("p_draw")); p_away = _safe_float(row.get("p_away"))
    probs = {"home": p_home, "draw": p_draw, "away": p_away}
    order = sorted(probs.items(), key=lambda kv: (kv[1] if kv[1] is not None else -1), reverse=True)
    top1_out = order[0][0] if order else None
    top2_out = order[1][0] if len(order) > 1 else None
    p_gap = (order[0][1] - order[1][1]) if (len(order) > 1 and order[0][1] is not None and order[1][1] is not None) else None
    offers = []
    for outc in ("home","draw","away"):
        o = _offer_1x2(outc, row, top1_out, top2_out, p_gap)
        if o: offers.append(o)
    if not offers: return None
    offers.sort(key=lambda x: (x["model_score"], x.get("ev") or -1), reverse=True)
    for o in offers:
        if (o.get("ev") or -1) > 0:
            return o
    return None

def _points_wdl_gfga(rows: List[Dict[str, Any]]) -> Dict[str, int]:
    w=d=l=gf=ga=pts=0
    for r in rows:
        a = int(r.get("goals_for") or 0)
        b = int(r.get("goals_against") or 0)
        gf += a; ga += b
        if a > b: w += 1; pts += 3
        elif a == b: d += 1; pts += 1
        else: l += 1
    return {"w5": w, "d5": d, "l5": l, "gf5": gf, "ga5": ga, "pts5": pts}

# ---------------- endpoint ----------------
@router.get("/graf-picks")
def graf_picks(
    days_ahead: int = Query(default=5, ge=1, le=14),
    target_cards: int = Query(default=3, ge=1, le=6),

    # базовые пороги обычного режима
    singles_min_odds: float = Query(default=1.80),
    ev_min_single: float = Query(default=0.05),
    parlay_min_odds_per_leg: float = Query(default=1.35),
    ev_min_leg: float = Query(default=0.03),

    include_parlay: bool = Query(default=True),
    trust_single_book: bool = Query(default=True),
    min_books: int = Query(default=1, ge=0),
    attach_evidence: bool = Query(default=True),

    # строгий режим по умолчанию
    safest_only: bool = Query(default=True),
    autorelax: bool = Query(default=True),

    # строгие пороги (стартовые)
    strict_min_odds_single: float = Query(default=1.80),
    strict_min_ev_single: float   = Query(default=0.12),
    strict_min_books: int         = Query(default=3),
    strict_min_pgap: float        = Query(default=0.25),
    strict_min_edge: float        = Query(default=0.05),
    strict_require_aligned: bool  = Query(default=True),
    strict_forbid_draws: bool     = Query(default=True),

    strict_parlay_min_combined_odds: float = Query(default=2.0),
    strict_parlay_leg_min_ev: float        = Query(default=0.05),
    strict_parlay_leg_min_odds: float      = Query(default=1.35),
    strict_parlay_leg_max_odds: float      = Query(default=2.00),

    # «модельный двойник» — fallback (даже если по ногам низкие кф, но высокая p)
    model_parlay_enabled: bool = Query(default=True),
    model_parlay_min_combined_odds: float = Query(default=2.0),
    model_parlay_leg_min_p: float = Query(default=0.62),
    model_parlay_leg_min_pgap: float = Query(default=0.18),   # для 1X2
    model_parlay_leg_min_odds: float = Query(default=1.15),
    model_parlay_allow_small_negative_ev: bool = Query(default=True),
    model_parlay_forbid_draws: bool = Query(default=True),
    model_parlay_use_ou: bool = Query(default=True),

    # форма/H2H
    require_form_non_negative: bool = Query(default=True),
    require_h2h_non_negative:  bool = Query(default=True),
    min_h2h_matches_for_signal: int = Query(default=3),
):
    start = date.today()
    end   = start + timedelta(days=days_ahead)

    sql = """
    WITH base AS (
      SELECT s.fixture_id, s.round, s.date::date AS date, s.league_name AS league, s.season::text AS season,
             s.home_team, s.away_team, s.home_team_id, s.away_team_id
      FROM football.api_football_schedule s
      WHERE s.date::date BETWEEN :d1 AND :d2
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
      p.bet_rating, p.bet_reason
    FROM base b
    LEFT JOIN football.ml_predictions p ON p.fixture_id = b.fixture_id
    ORDER BY b.date ASC, b.league, b.home_team;
    """
    with engine.connect() as conn:
        df = pd.read_sql(text(sql), conn, params={"d1": str(start), "d2": str(end)})

    if df.empty:
        return JSONResponse(content={"mode":"empty","cards": [], "evidence": {}, "filters_used": {}, "filters_debug": {"info":"no-fixtures"}})

    df = df.where(pd.notnull(df), None)

    # ------- доказуха (форма, H2H) -------
    evidence_by_fixture: Dict[int, Dict[str, Any]] = {}
    evidence_form_by_team: Dict[int, Dict[str, Any]] = {}
    evidence_h2h_map: Dict[str, Dict[str, Any]] = {}

    with engine.begin() as conn:
        for r in df.itertuples(index=False):
            fid = int(r.fixture_id)
            cutoff = str(pd.to_datetime(r.date).date())
            home_id = int(r.home_team_id) if r.home_team_id is not None else None
            away_id = int(r.away_team_id) if r.away_team_id is not None else None
            if not home_id or not away_id:
                continue

            q_last5 = text("""
                WITH base AS (
                  SELECT s.date::date AS date, s.league_name AS league,
                         CASE WHEN s.home_team_id = :tid THEN s.away_team ELSE s.home_team END AS opponent,
                         CASE WHEN s.home_team_id = :tid THEN 'home' ELSE 'away' END AS venue,
                         CONCAT(s.home_goals,'-',s.away_goals) AS score,
                         CASE WHEN s.home_team_id = :tid THEN s.home_goals ELSE s.away_goals END AS goals_for,
                         CASE WHEN s.home_team_id = :tid THEN s.away_goals ELSE s.home_goals END AS goals_against,
                         s.fixture_id
                  FROM football.api_football_schedule s
                  WHERE (s.home_team_id = :tid OR s.away_team_id = :tid)
                    AND s.date::date < :cutoff
                    AND (
                         s.status ILIKE '%Match Finished%'
                      OR s.status ILIKE '%Full Time%'
                      OR s.status ILIKE '%FT%'
                      OR s.status ILIKE '%AET%'
                      OR s.status ILIKE '%PEN%'
                    )
                    AND s.season::text = :season
                  ORDER BY s.date DESC
                  LIMIT 5
                )
                SELECT * FROM base
                UNION ALL
                SELECT * FROM (
                  SELECT s.date::date AS date, s.league_name AS league,
                         CASE WHEN s.home_team_id = :tid THEN s.away_team ELSE s.home_team END AS opponent,
                         CASE WHEN s.home_team_id = :tid THEN 'home' ELSE 'away' END AS venue,
                         CONCAT(s.home_goals,'-',s.away_goals) AS score,
                         CASE WHEN s.home_team_id = :tid THEN s.home_goals ELSE s.away_goals END AS goals_for,
                         CASE WHEN s.home_team_id = :tid THEN s.away_goals ELSE s.home_goals END AS goals_against,
                         s.fixture_id
                  FROM football.api_football_schedule s
                  WHERE (s.home_team_id = :tid OR s.away_team_id = :tid)
                    AND s.date::date < :cutoff
                    AND (
                         s.status ILIKE '%Match Finished%'
                      OR s.status ILIKE '%Full Time%'
                      OR s.status ILIKE '%FT%'
                      OR s.status ILIKE '%AET%'
                      OR s.status ILIKE '%PEN%'
                    )
                    AND (SELECT COUNT(1) FROM base) < 3
                  ORDER BY s.date DESC
                  LIMIT GREATEST(0, 5 - (SELECT COUNT(1) FROM base))
                ) t2
            """)
            home_last5 = [dict(x) for x in conn.execute(q_last5, {"tid": home_id, "cutoff": cutoff, "season": str(r.season)}).mappings().all()]
            away_last5 = [dict(x) for x in conn.execute(q_last5, {"tid": away_id, "cutoff": cutoff, "season": str(r.season)}).mappings().all()]

            h2h_rows = conn.execute(text("""
                SELECT s.date::date AS date, s.league_name AS league, s.home_team, s.away_team,
                       CONCAT(s.home_goals,'-',s.away_goals) AS score, s.fixture_id
                FROM football.api_football_schedule s
                WHERE ((s.home_team_id = :h AND s.away_team_id = :a) OR (s.home_team_id = :a AND s.away_team_id = :h))
                  AND s.date::date < :cutoff
                  AND (
                       s.status ILIKE '%Match Finished%'
                    OR s.status ILIKE '%Full Time%'
                    OR s.status ILIKE '%FT%'
                    OR s.status ILIKE '%AET%'
                    OR s.status ILIKE '%PEN%'
                  )
                ORDER BY s.date DESC
                LIMIT 5
            """), {"h": home_id, "a": away_id, "cutoff": cutoff}).mappings().all()
            h2h = [dict(x) for x in h2h_rows]

            # H2H summary относительно текущего хозяина
            hW = d5 = aW = 0
            for x in h2h:
                try:
                    h, a = [int(t) for t in str(x["score"]).split("-")]
                    if x["home_team"] == r.home_team:
                        if h > a: hW += 1
                        elif h == a: d5 += 1
                        else: aW += 1
                    else:
                        if h > a: aW += 1
                        elif h == a: d5 += 1
                        else: hW += 1
                except Exception:
                    pass

            home_form = _points_wdl_gfga(home_last5)
            away_form = _points_wdl_gfga(away_last5)

            evidence_by_fixture[fid] = {
                "home_last5": home_last5, "away_last5": away_last5, "h2h_last5": h2h,
                "home_form_pts": home_form["pts5"], "away_form_pts": away_form["pts5"],
                "h2h_summary": {"m5": len(h2h), "hW": hW, "d5": d5, "aW": aW},
            }
            evidence_form_by_team[home_id] = home_form
            evidence_form_by_team[away_id] = away_form
            evidence_h2h_map[f"{home_id},{away_id}"] = {"m5": len(h2h), "hW": hW, "d5": d5, "aW": aW}

    # ------- черновые picks (лучший 1X2) + риск -------
    def _support_for_pick(pick_outcome: str, ev: Dict[str, Any]) -> Dict[str, int]:
        if not ev: return {"form": 0, "h2h": 0, "h2h_m": 0}
        fh = ev.get("home_form_pts"); fa = ev.get("away_form_pts")
        diff = (fh - fa) if (fh is not None and fa is not None) else 0
        if pick_outcome == "home":
            form_sup = 1 if diff >= 3 else (-1 if diff <= -3 else 0)
        elif pick_outcome == "away":
            form_sup = 1 if diff <= -3 else (-1 if diff >= 3 else 0)
        else:
            form_sup = 1 if abs(diff) <= 2 else 0
        h2h = ev.get("h2h_summary") or {"hW":0,"aW":0,"d5":0,"m5":0}
        m = h2h.get("m5") or 0
        if m < min_h2h_matches_for_signal:
            h2h_sup = 0
        else:
            if pick_outcome == "home":
                h2h_sup = 1 if (h2h["hW"] - h2h["aW"]) >= 1 else (-1 if (h2h["aW"] - h2h["hW"]) >= 1 else 0)
            elif pick_outcome == "away":
                h2h_sup = 1 if (h2h["aW"] - h2h["hW"]) >= 1 else (-1 if (h2h["hW"] - h2h["aW"]) >= 1 else 0)
            else:
                h2h_sup = 1 if (abs(h2h["hW"] - h2h["aW"]) <= 1 and h2h["d5"] >= 1) else 0
        return {"form": form_sup, "h2h": h2h_sup, "h2h_m": m}

    def _risk_label(best: Dict[str, Any], sup: Dict[str, int], n_books: int) -> str:
        lvl = 1
        evv = _safe_float(best.get("ev")) or 0.0
        pgap = _safe_float(best.get("pgap")) or 0.0
        odds = _safe_float(best.get("odds")) or 0.0
        agreement = best.get("agreement")
        if best.get("outcome") == "draw": lvl = max(lvl, 2)
        if agreement != "aligned": lvl = max(lvl, 2)
        if odds >= 3.0: lvl = max(lvl, 2)
        if odds >= 3.3 and agreement != "aligned": lvl = max(lvl, 3)
        if n_books is not None and n_books < 2: lvl = max(lvl, 2)
        if sup.get("form") == -1:
            if evv < 0.12 or pgap < 0.25: lvl = max(lvl, 3)
            else: lvl = max(lvl, 2)
        if sup.get("h2h") == -1: lvl = max(lvl, 2)
        return {1:"low",2:"medium",3:"high"}[lvl]

    picks: List[Dict[str, Any]] = []
    for _, r in df.iterrows():
        best = _collect_best_1x2(r)
        if not best: continue
        books = int(r.get("n_bookmakers")) if r.get("n_bookmakers") is not None else 0
        if not trust_single_book and books < min_books: continue

        ev = evidence_by_fixture.get(int(r["fixture_id"]))
        sup = _support_for_pick(best["outcome"], ev)
        risk = _risk_label(best, sup, books)

        probs = {
            "p_home": _safe_float(r.get("p_home")),
            "p_draw": _safe_float(r.get("p_draw")),
            "p_away": _safe_float(r.get("p_away")),
            "p_over25": _safe_float(r.get("p_over25")),
            "p_under25": _safe_float(r.get("p_under25")),
        }

        picks.append({
            "fixture_id": int(r["fixture_id"]),
            "date": str(pd.to_datetime(r["date"]).date()),
            "league": r["league"], "season": r["season"], "round": r.get("round"),
            "home_team": r["home_team"], "away_team": r["away_team"],
            "home_team_id": int(r["home_team_id"]) if r.get("home_team_id") is not None else None,
            "away_team_id": int(r["away_team_id"]) if r.get("away_team_id") is not None else None,
            **best,
            "form_support": sup["form"], "h2h_support": sup["h2h"], "h2h_matches": sup["h2h_m"],
            "risk": risk, "n_bookmakers": books,
            "model_probs": probs,
        })

    # ------- строгая фильтрация + автосмягчение -------
    filters_used = {"mode": "safest" if safest_only else "normal"}
    filters_debug: Dict[str, Any] = {}
    used_thresholds = {}

    def _apply_strict(ps: List[Dict[str,Any]],
                      th_min_odds: float, th_min_ev: float, th_min_books: int, th_min_pgap: float,
                      th_min_edge: float, require_aligned_flag: bool, forbid_draws_flag: bool) -> (List[Dict[str,Any]], List[Dict[str,Any]]):
        keep, rej = [], []
        for p in ps:
            reasons = []
            if forbid_draws_flag and p.get("outcome") == "draw":
                reasons.append("draw_forbidden")
            if require_aligned_flag and p.get("agreement") != "aligned":
                reasons.append("not_aligned")
            if (p.get("odds") or 0) < th_min_odds:
                reasons.append("odds_too_low")
            if (p.get("ev") or 0) < th_min_ev:
                reasons.append("ev_too_low")
            if (p.get("edge") or 0) < th_min_edge:
                reasons.append("edge_too_low")
            if (p.get("pgap") or 0) < th_min_pgap:
                reasons.append("pgap_too_low")
            if (p.get("n_bookmakers") or 0) < th_min_books:
                reasons.append("few_bookmakers")
            if require_form_non_negative and (p.get("form_support") or 0) < 0:
                reasons.append("form_against")
            if require_h2h_non_negative and (p.get("h2h_support") or 0) < 0:
                reasons.append("h2h_against")
            if reasons:
                q = dict(p); q["reasons"] = reasons; rej.append(q)
            else:
                keep.append(p)
        keep.sort(key=lambda x: (x["ev"], x.get("pgap") or 0, x.get("kelly") or 0), reverse=True)
        return keep, rej

    cards: List[Dict[str, Any]] = []

    if safest_only:
        stages = [
            ("strict@start", dict(th_min_odds=strict_min_odds_single, th_min_ev=strict_min_ev_single,
                                  th_min_books=strict_min_books, th_min_pgap=strict_min_pgap,
                                  th_min_edge=strict_min_edge, require_aligned_flag=strict_require_aligned,
                                  forbid_draws_flag=strict_forbid_draws)),
            ("relax_1_books2", dict(th_min_odds=strict_min_odds_single, th_min_ev=strict_min_ev_single,
                                    th_min_books=max(2, strict_min_books-1), th_min_pgap=strict_min_pgap,
                                    th_min_edge=strict_min_edge, require_aligned_flag=True, forbid_draws_flag=True)),
            ("relax_2_ev010", dict(th_min_odds=strict_min_odds_single, th_min_ev=0.10,
                                   th_min_books=max(2, strict_min_books-1), th_min_pgap=strict_min_pgap,
                                   th_min_edge=strict_min_edge, require_aligned_flag=True, forbid_draws_flag=True)),
            ("relax_3_pgap020", dict(th_min_odds=strict_min_odds_single, th_min_ev=0.10,
                                     th_min_books=max(2, strict_min_books-1), th_min_pgap=0.20,
                                     th_min_edge=strict_min_edge, require_aligned_flag=True, forbid_draws_flag=True)),
            ("relax_4_ev008", dict(th_min_odds=strict_min_odds_single, th_min_ev=0.08,
                                   th_min_books=max(2, strict_min_books-1), th_min_pgap=0.20,
                                   th_min_edge=strict_min_edge, require_aligned_flag=True, forbid_draws_flag=True)),
        ]
        all_rejected = []
        kept = []
        chosen_stage = None
        for name, th in stages:
            keep, rej = _apply_strict(picks, **th)
            all_rejected.extend([dict(x, stage=name) for x in rej])
            if keep and (not autorelax or len(keep) >= target_cards) or (name == stages[-1][0] and keep):
                kept = keep[:target_cards]
                chosen_stage = name
                used_thresholds = dict(stage=chosen_stage, **th)
                break

        for s in kept:
            cards.append({"type":"single", **s, "banter": f"Один прогноз — одна победа"})

        # строгий экспресс (если нужно добрать)
        if include_parlay and len(cards) < target_cards and kept:
            legs_candidates = []
            for p in kept:
                if (p.get("odds") or 0) < strict_parlay_leg_min_odds or (p.get("odds") or 0) > strict_parlay_leg_max_odds:
                    continue
                if (p.get("ev") or 0) < strict_parlay_leg_min_ev:
                    continue
                legs_candidates.append(p)

            best_pair = None; best_ev = -1.0
            def _parlay_metrics(legs: List[Dict[str, Any]]) -> Dict[str, Any]:
                prob=1.0; odds=1.0
                for leg in legs:
                    prob *= float(leg["p"]); odds *= float(leg["odds"])
                return {"p": prob, "odds": odds, "ev": prob*odds - 1.0, "kelly": _kelly_fraction(prob, odds)}

            n = len(legs_candidates)
            for i in range(n):
                for j in range(i+1, n):
                    a, b = legs_candidates[i], legs_candidates[j]
                    if a["fixture_id"] == b["fixture_id"]:
                        continue
                    tset = {a["home_team"], a["away_team"], b["home_team"], b["away_team"]}
                    if len(tset) < 4:
                        continue
                    agg = _parlay_metrics([a,b])
                    if (agg["odds"] or 0) < strict_parlay_min_combined_odds:
                        continue
                    if agg["ev"] is not None and agg["ev"] > best_ev:
                        best_ev = agg["ev"]; best_pair = (a,b,agg)

            if best_pair:
                a,b,agg = best_pair
                legs = [
                    {"fixture_id": a["fixture_id"], "label": a["label"], "p": a["p"], "odds": a["odds"],
                     "home_team": a["home_team"], "away_team": a["away_team"],
                     "title": f"{a['home_team']} vs {a['away_team']}", "league": a["league"]},
                    {"fixture_id": b["fixture_id"], "label": b["label"], "p": b["p"], "odds": b["odds"],
                     "home_team": b["home_team"], "away_team": b["away_team"],
                     "title": f"{b['home_team']} vs {b['away_team']}", "league": b["league"]},
                ]
                cards.append({
                    "type": "parlay",
                    "title": "Двойник (строгий)",
                    "legs": legs,
                    "parlay_metrics": {k: (round(v,4) if isinstance(v,float) and v is not None else v) for k,v in agg.items()},
                    "banter": "Двойник из двух согласованных исходов.",
                })

        filters_debug["rejected"] = all_rejected
        if not cards:
            used_thresholds = used_thresholds or {"stage":"none_passed"}

    else:
        # обычный режим (как было)
        singles = [
            p for p in picks
            if (p["ev"] is not None and p["ev"] >= ev_min_single and
                p["odds"] is not None and p["odds"] >= singles_min_odds)
        ]
        singles.sort(key=lambda x: (x["ev"], x["p"]), reverse=True)
        for s in singles[:target_cards]:
            cards.append({"type":"single", **s, "banter": f"ЖБ от Графа: {s['label']} — {s['home_team']} vs {s['away_team']}."})

        if include_parlay and len(cards) < target_cards:
            legs_candidates = [
                p for p in picks
                if (p["ev"] is not None and p["ev"] >= ev_min_leg and
                    p["odds"] is not None and p["odds"] >= parlay_min_odds_per_leg)
            ]
            best_pair = None; best_ev = -1
            def _parlay_metrics(legs: List[Dict[str, Any]]) -> Dict[str, Any]:
                prob=1.0; odds=1.0
                for leg in legs:
                    prob *= float(leg["p"]); odds *= float(leg["odds"])
                return {"p": prob, "odds": odds, "ev": prob*odds - 1.0, "kelly": _kelly_fraction(prob, odds)}
            n = len(legs_candidates)
            for i in range(n):
                for j in range(i + 1, n):
                    a, b = legs_candidates[i], legs_candidates[j]
                    if a["fixture_id"] == b["fixture_id"]:
                        continue
                    agg = _parlay_metrics([a, b])
                    if agg["ev"] is not None and agg["ev"] > best_ev:
                        best_ev = agg["ev"]; best_pair = (a, b, agg)
            if best_pair:
                a,b,agg = best_pair
                legs = [
                    {"fixture_id": a["fixture_id"], "label": a["label"], "p": a["p"], "odds": a["odds"],
                     "home_team": a["home_team"], "away_team": a["away_team"],
                     "title": f"{a['home_team']} vs {a['away_team']}", "league": a["league"]},
                    {"fixture_id": b["fixture_id"], "label": b["label"], "p": b["p"], "odds": b["odds"],
                     "home_team": b["home_team"], "away_team": b["away_team"],
                     "title": f"{b['home_team']} vs {b['away_team']}", "league": b["league"]},
                ]
                cards.append({
                    "type": "parlay",
                    "title": "Двойник",
                    "legs": legs,
                    "parlay_metrics": {k: (round(v,4) if isinstance(v,float) and v is not None else v) for k,v in agg.items()},
                    "banter": "Комбо как у Суворова: зашёл — и всех порвал ⚔️",
                })

    # ------- Fallback: МОДЕЛЬНЫЙ ДВОЙНИК (даже если кф ног низкий) -------
    model_parlay_debug = {"legs_total": 0, "legs_after_rules": 0, "picked_pair": None}
    if include_parlay and model_parlay_enabled:
        # собираем кандидатов из всей таблицы: 1X2 (только П1/П2) + OU2.5
        legs = []
        for _, r in df.iterrows():
            # 1X2: берём top1 исход и проверяем p/pgap/odds
            p_home = _safe_float(r.get("p_home")); p_draw = _safe_float(r.get("p_draw")); p_away = _safe_float(r.get("p_away"))
            order = sorted(
                [("home", p_home), ("draw", p_draw), ("away", p_away)],
                key=lambda kv: (kv[1] if kv[1] is not None else -1), reverse=True
            )
            if order and order[0][1] is not None:
                top1_out, top1_p = order[0]
                top2_p = order[1][1] if len(order) > 1 else None
                pgap = (top1_p - top2_p) if (top2_p is not None) else None
                if top1_out != "draw" or not model_parlay_forbid_draws:
                    leg1 = _offer_1x2(top1_out, r, top1_out, None, pgap)
                    if leg1:
                        model_odds_ok = (leg1["odds"] or 0) >= model_parlay_leg_min_odds
                        model_p_ok = (leg1["p"] or 0) >= model_parlay_leg_min_p
                        model_pgap_ok = (pgap or 0) >= model_parlay_leg_min_pgap if pgap is not None else False
                        ev_ok = (leg1.get("ev") or -1) >= ( -0.01 if model_parlay_allow_small_negative_ev else 0.0 )
                        if model_odds_ok and (model_p_ok or model_pgap_ok) and ev_ok and leg1["agreement"] == "aligned":
                            legs.append({
                                "fixture_id": int(r["fixture_id"]),
                                "home_team": r["home_team"], "away_team": r["away_team"], "league": r["league"],
                                **leg1
                            })

            # OU2.5: берём сторону с большей p
            if model_parlay_use_ou:
                pov = _safe_float(r.get("p_over25")); pun = _safe_float(r.get("p_under25"))
                if pov is not None or pun is not None:
                    side = "over" if (pov or 0) >= (pun or 0) else "under"
                    leg2 = _offer_ou(side, r)
                    if leg2:
                        model_odds_ok = (leg2["odds"] or 0) >= model_parlay_leg_min_odds
                        model_p_ok = (leg2["p"] or 0) >= model_parlay_leg_min_p
                        ev_ok = (leg2.get("ev") or -1) >= ( -0.01 if model_parlay_allow_small_negative_ev else 0.0 )
                        if model_odds_ok and model_p_ok and ev_ok:
                            legs.append({
                                "fixture_id": int(r["fixture_id"]),
                                "home_team": r["home_team"], "away_team": r["away_team"], "league": r["league"],
                                **leg2
                            })

        model_parlay_debug["legs_total"] = len(legs)

        # убираем дубли по одному и тому же рынку/матчу (оставляем лучший score)
        keyd: Dict[str, Dict[str, Any]] = {}
        for leg in legs:
            k = f"{leg['fixture_id']}|{leg['market']}|{leg['outcome']}"
            if k not in keyd or (leg.get("model_score") or 0) > (keyd[k].get("model_score") or 0):
                keyd[k] = leg
        legs = list(keyd.values())

        # выбираем пару с макс EV комбо и кф >= 2.0, разные матчи и без пересечения команд
        best_pair = None; best_ev = -1.0
        def _parlay_metrics(legs_in: List[Dict[str, Any]]) -> Dict[str, Any]:
            prob=1.0; odds=1.0
            for l in legs_in:
                prob *= float(l["p"]); odds *= float(l["odds"])
            return {"p": prob, "odds": odds, "ev": prob*odds - 1.0, "kelly": _kelly_fraction(prob, odds)}

        L = len(legs)
        for i in range(L):
            for j in range(i+1, L):
                a,b = legs[i], legs[j]
                if a["fixture_id"] == b["fixture_id"]:
                    continue
                teamset = {a["home_team"], a["away_team"], b["home_team"], b["away_team"]}
                if len(teamset) < 4:
                    continue
                agg = _parlay_metrics([a,b])
                if (agg["odds"] or 0) < model_parlay_min_combined_odds:
                    continue
                if agg["ev"] is not None and agg["ev"] > best_ev:
                    best_ev = agg["ev"]; best_pair = (a,b,agg)

        model_parlay_debug["legs_after_rules"] = len(legs)
        if best_pair and (len(cards) < target_cards or not any(c.get("type") == "parlay" for c in cards)):
            a,b,agg = best_pair
            model_parlay_debug["picked_pair"] = {
                "a": {"fixture_id": a["fixture_id"], "market": a["market"], "label": a["label"], "p": a["p"], "odds": a["odds"]},
                "b": {"fixture_id": b["fixture_id"], "market": b["market"], "label": b["label"], "p": b["p"], "odds": b["odds"]},
                "agg": {k: (round(v,4) if isinstance(v,float) and v is not None else v) for k,v in agg.items()}
            }
            legs_out = [
                {"fixture_id": a["fixture_id"], "label": a["label"], "p": a["p"], "odds": a["odds"],
                 "home_team": a["home_team"], "away_team": a["away_team"],
                 "title": f"{a['home_team']} vs {a['away_team']}", "league": a["league"]},
                {"fixture_id": b["fixture_id"], "label": b["label"], "p": b["p"], "odds": b["odds"],
                 "home_team": b["home_team"], "away_team": b["away_team"],
                 "title": f"{b['home_team']} vs {b['away_team']}", "league": b["league"]},
            ]
            cards.append({
                "type": "parlay",
                "title": "Двойник (модельный)",
                "legs": legs_out,
                "parlay_metrics": {k: (round(v,4) if isinstance(v,float) and v is not None else v) for k,v in agg.items()},
                "banter": "Две цели — один залп. Граф одобряет",
            })

    # обрезаем до таргета (если вдруг перебор)
    cards = cards[:target_cards]

    evidence = {}
    if attach_evidence:
        evidence = {
            "by_fixture": evidence_by_fixture,
            "form_last5": evidence_form_by_team,
            "h2h_last5": evidence_h2h_map,
        }

    return JSONResponse(
        content=jsonable_encoder({
            "mode": filters_used["mode"],
            "cards": cards,
            "evidence": evidence,
            "filters_used": {
                **filters_used,
                "model_parlay": {
                    "enabled": model_parlay_enabled,
                    "min_combined_odds": model_parlay_min_combined_odds,
                    "leg_min_p": model_parlay_leg_min_p,
                    "leg_min_pgap": model_parlay_leg_min_pgap,
                    "leg_min_odds": model_parlay_leg_min_odds,
                    "use_ou": model_parlay_use_ou,
                    "allow_small_negative_ev": model_parlay_allow_small_negative_ev,
                },
            },
            "filters_debug": {**filters_debug, "model_parlay_debug": model_parlay_debug},
            "used_thresholds": used_thresholds
        }))
