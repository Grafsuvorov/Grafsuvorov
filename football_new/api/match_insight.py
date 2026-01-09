# api/match_insight.py
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import JSONResponse
from sqlalchemy import create_engine, text
import pandas as pd
import numpy as np
from typing import Optional, Dict, Any, List
import math

router = APIRouter(
    prefix="/api",
    tags=["Аналитика матчей"],
    responses={404: {"description": "Not found"}}
)
DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"
engine = create_engine(DB_URL)

# ------------------- helpers -------------------

def _safe(x, typ=float, default=None):
    try:
        v = typ(x)
        if isinstance(v, float) and not math.isfinite(v):
            return default
        return v
    except Exception:
        return default

def implied(odds: Optional[float]) -> Optional[float]:
    odds = _safe(odds)
    return (1.0/odds) if (odds and odds > 0) else None

def ev(p: Optional[float], odds: Optional[float]) -> Optional[float]:
    p = _safe(p); odds = _safe(odds)
    if p is None or odds is None or odds <= 1.0: return None
    return p*odds - 1.0

def w_points(res: str, w: float = 1.0) -> float:
    return {"W": 3*w, "D": 1*w, "L": 0.0}.get(res, 0.0)

def classify_res(hg, ag, is_home) -> str:
    if hg is None or ag is None: return ""
    if is_home:
        return "W" if hg > ag else "L" if hg < ag else "D"
    else:
        return "W" if ag > hg else "L" if ag < hg else "D"

def _fmt_pct(x, d=0):
    x = _safe(x, float, None)
    return f"{x*100:.{d}f}%" if x is not None else "—"

def _fmt_num(x, d=2):
    x = _safe(x, float, None)
    return f"{x:.{d}f}" if x is not None else "—"

# ------------------- league tuning -------------------

TUNING = {
    "default": dict(
        odds_hardcap_1x2=7.5,
        odds_max_1x2=6.5,
        odds_max_draw=5.5,
        min_p_draw=0.26,
        draw_close_gap=0.06,
        blowout_p1=0.62,
        blowout_gap=0.22,
        min_p_aligned=0.52,
        min_p_top2=0.45,
        max_pgap_top2=0.07,
        min_p_total=0.52,
        min_ev_total=0.05,
    ),
    "bundesliga": dict(
        odds_hardcap_1x2=7.0, odds_max_1x2=6.0, odds_max_draw=5.5,
        min_p_draw=0.26, draw_close_gap=0.05, blowout_p1=0.60, blowout_gap=0.20,
        min_p_aligned=0.54, min_p_top2=0.48, max_pgap_top2=0.07,
        min_p_total=0.52, min_ev_total=0.05,
    ),
    "la liga": dict(
        odds_hardcap_1x2=7.0, odds_max_1x2=6.0, odds_max_draw=5.5,
        min_p_draw=0.25, draw_close_gap=0.055, blowout_p1=0.61, blowout_gap=0.21,
        min_p_aligned=0.53, min_p_top2=0.47, max_pgap_top2=0.07,
        min_p_total=0.52, min_ev_total=0.05,
    ),
}

def league_tuning(name: Optional[str]) -> Dict[str, float]:
    n = (name or "").lower()
    if "bundes" in n or "german" in n:
        return TUNING["bundesliga"]
    if "la liga" in n or "laliga" in n or "primera" in n or "spain" in n:
        return TUNING["la liga"]
    return TUNING["default"]

# ------------------- SQL -------------------

SQL_FIXTURE = """
SELECT s.fixture_id, s.date AT TIME ZONE 'UTC' AS date_utc, s.season, s.round,
       s.league_name AS league, s.league_id,
       s.home_team_id, s.home_team, s.away_team_id, s.away_team,
       s.home_goals, s.away_goals
FROM football.api_football_schedule s
WHERE s.fixture_id = :fid
"""

SQL_LAST_MATCHES = """
SELECT date::timestamp AT TIME ZONE 'UTC' AS date_utc,
       home_team_id, away_team_id, home_team, away_team,
       home_goals, away_goals
FROM football.api_football_schedule
WHERE (home_team_id = :tid OR away_team_id = :tid)
  AND date < :dt
  AND home_goals IS NOT NULL AND away_goals IS NOT NULL
ORDER BY date DESC
LIMIT :lim
"""

SQL_H2H = """
SELECT date::timestamp AT TIME ZONE 'UTC' AS date_utc,
       home_team_id, away_team_id, home_goals, away_goals
FROM football.api_football_schedule
WHERE ((home_team_id = :h AND away_team_id = :a) OR (home_team_id = :a AND away_team_id = :h))
  AND date < :dt
  AND home_goals IS NOT NULL AND away_goals IS NOT NULL
ORDER BY date DESC
LIMIT :lim
"""

SQL_PRED = """
SELECT *
FROM football.ml_predictions
WHERE fixture_id = :fid
"""

SQL_PLAYERS_FORM_A = """
SELECT player_id, player_name, team_id, date, goals, assists
FROM football.player_match_stats
WHERE team_id = :tid AND date < :dt
ORDER BY date DESC
LIMIT 100
"""

SQL_PLAYERS_FORM_B = """
SELECT ps.player_id, p.player_name, ps.team_id, ps.date, ps.goals, ps.assists
FROM football.api_football_players_stats ps
JOIN football.api_football_players p ON p.player_id = ps.player_id
WHERE ps.team_id = :tid AND ps.date < :dt
ORDER BY ps.date DESC
LIMIT 100
"""

def fetch_df(conn, sql, **params):
    return pd.read_sql(text(sql), conn, params=params)

# ------------------- mini-analytics -------------------

def lastN_form_string(df_team: pd.DataFrame, team_id: int, n: int = 5) -> str:
    if df_team.empty: return ""
    res = []
    for _, r in df_team.head(n).iterrows():
        is_home = int(r["home_team_id"]) == team_id
        hg = _safe(r["home_goals"], int, None); ag = _safe(r["away_goals"], int, None)
        res.append(classify_res(hg, ag, is_home))
    return "".join(res)

def avg_gf_ga(df_team: pd.DataFrame, team_id: int, n: int = 5) -> Dict[str, float]:
    if df_team.empty: return {"gf":0.0,"ga":0.0}
    rows = []
    for _, r in df_team.head(n).iterrows():
        is_home = int(r["home_team_id"]) == team_id
        hg = _safe(r["home_goals"], int, None); ag = _safe(r["away_goals"], int, None)
        gf = hg if is_home else ag
        ga = ag if is_home else hg
        rows.append((gf, ga))
    if not rows: return {"gf":0.0,"ga":0.0}
    gf = float(np.mean([x[0] for x in rows])); ga = float(np.mean([x[1] for x in rows]))
    return {"gf":gf, "ga":ga}

def totals_profile(df_team_home: pd.DataFrame, df_team_away: pd.DataFrame, n: int = 10) -> Dict[str, Optional[float]]:
    pool = []
    for df in (df_team_home.head(n), df_team_away.head(n)):
        for _, r in df.iterrows():
            hg = _safe(r["home_goals"], int, None); ag = _safe(r["away_goals"], int, None)
            if hg is None or ag is None: continue
            pool.append(hg + ag)
    if not pool:
        return {"avg_goals_last10": None, "under25_rate_last10": None}
    avg_goals = float(np.mean(pool))
    under_rate = float(np.mean([1.0 if t < 3 else 0.0 for t in pool]))
    return {"avg_goals_last10": avg_goals, "under25_rate_last10": under_rate}

def h2h_summary(df_h2h: pd.DataFrame, home_id: int) -> Dict[str, int]:
    w=d=l=0
    for _, r in df_h2h.iterrows():
        hg = _safe(r["home_goals"], int, None); ag = _safe(r["away_goals"], int, None)
        if int(r["home_team_id"]) == home_id:
            res = classify_res(hg, ag, True)
        else:
            res = classify_res(hg, ag, False)
        if res=="W": w+=1
        elif res=="D": d+=1
        elif res=="L": l+=1
    return {"home_wins": w, "draws": d, "away_wins": l}

def players_form_last5(conn, team_id: int, dt) -> List[Dict[str, Any]]:
    df = pd.DataFrame()
    try:
        df = fetch_df(conn, SQL_PLAYERS_FORM_A, tid=team_id, dt=dt)
    except Exception:
        pass
    if df.empty:
        try:
            df = fetch_df(conn, SQL_PLAYERS_FORM_B, tid=team_id, dt=dt)
        except Exception:
            df = pd.DataFrame()
    if df.empty: return []
    if "date" in df.columns:
        df = df.sort_values("date", ascending=False)
    grp = df.groupby(["player_id","player_name"], as_index=False).head(5)
    if "goals" not in grp.columns: grp["goals"] = 0
    agg = grp.groupby(["player_id","player_name"], as_index=False).agg(g_last5=("goals","sum"))
    agg = agg.sort_values("g_last5", ascending=False).head(3)
    out = []
    for _, r in agg.iterrows():
        out.append({"player_id": int(_safe(r["player_id"], int, 0)),
                    "name": r["player_name"],
                    "g_last5": int(_safe(r["g_last5"], int, 0))})
    return out

# ------------------- model guard & dual choice -------------------

def _label_for(market: str, outcome: str) -> str:
    if market == "1X2":
        return {"home":"П1","draw":"Х","away":"П2"}.get(outcome, "—")
    if market == "OU25":
        return {"over":"ТБ 2.5","under":"ТМ 2.5"}.get(outcome, "—")
    return "—"

def guard_dual(rec_raw: Dict[str, Any], league_name: str) -> Dict[str, Any]:
    lt = league_tuning(league_name)

    # ---- пороги / правила ----
    SIDE_MIN_EV = 0.02          # если EV стороны >= 2% — берём сторону
    DRAW_MIN_EV = 0.05          # ничья только с EV >= 5%
    DRAW_PRIORITY_MARGIN = 0.06 # ничья должна выигрывать у лучшей стороны минимум на 6 п.п. EV
    PROB_GAP_MIN = 0.03         # минимальный зазор p_top1 - p_top2, чтобы не отдавать ничью в «почти равных»

    def _eff_min_p_aligned(p_gap: Optional[float]) -> float:
        # динамический порог для выбора стороны по вероятности
        base = lt["min_p_aligned"]  # обычно 0.52
        if p_gap is None:
            return base
        if p_gap >= 0.10:
            return max(0.48, base - 0.04)
        if p_gap >= 0.06:
            return max(0.50, base - 0.02)
        return base

    # ---- извлечение входов ----
    pH, pD, pA = rec_raw.get("p_home"), rec_raw.get("p_draw"), rec_raw.get("p_away")
    odH, odD, odA = rec_raw.get("od_home"), rec_raw.get("od_draw"), rec_raw.get("od_away")

    evH = rec_raw.get("ev_home"); evH = evH if evH is not None else ev(pH, odH)
    evD = rec_raw.get("ev_draw"); evD = evD if evD is not None else ev(pD, odD)
    evA = rec_raw.get("ev_away"); evA = evA if evA is not None else ev(pA, odA)

    pOver, pUnder = rec_raw.get("p_over25"), rec_raw.get("p_under25")
    odOver, odUnder = rec_raw.get("od_over25"), rec_raw.get("od_under25")
    evOver = rec_raw.get("ev_over") if rec_raw.get("ev_over") is not None else ev(pOver, odOver)
    evUnder = rec_raw.get("ev_under") if rec_raw.get("ev_under") is not None else ev(pUnder, odUnder)

    probs = dict(home=pH, draw=pD, away=pA)
    odds  = dict(home=odH, draw=odD, away=odA)
    evs   = dict(home=evH, draw=evD, away=evA)

    # ---- упорядочим по вероятности ----
    order = sorted(probs.items(), key=lambda kv: (kv[1] if kv[1] is not None else -1), reverse=True)
    top1, top2 = order[0][0], order[1][0]
    p_gap = (order[0][1]-order[1][1]) if all(x[1] is not None for x in order[:2]) else None
    p_top1 = order[0][1]

    blowout = (p_top1 is not None and p_top1 >= lt["blowout_p1"]) or (p_gap is not None and p_gap >= lt["blowout_gap"])

    # ---- ограничения на ничью ----
    draw_ok = (
        pD is not None and pH is not None and pA is not None and
        abs(pH - pA) <= lt["draw_close_gap"] and
        pD >= lt["min_p_draw"] and
        _safe(odds["draw"]) is not None and odds["draw"] <= lt["odds_max_draw"]
    )

    # ---- кандидаты 1X2 (сides только) ----
    candidates_1x2: List[Dict[str, Any]] = []

    eff_min_p = _eff_min_p_aligned(p_gap)

    # aligned (лидер по p) — только стороны
    if top1 in ("home", "away") and probs.get(top1) is not None and probs[top1] >= eff_min_p:
        cand = dict(market="1X2", outcome=top1, p=probs[top1], odds=odds[top1], ev=evs.get(top1),
                    agreement="aligned", pgap=p_gap, label=_label_for("1X2", top1))
        if not (odds.get(top1) is not None and odds[top1] >= lt["odds_hardcap_1x2"] and (probs[top1] is None or probs[top1] < 0.18)):
            candidates_1x2.append(cand)

    # top2 (если не blowout) — только стороны
    if not blowout and top2 in ("home", "away") and probs.get(top2) is not None and probs[top2] >= lt["min_p_top2"]:
        if p_gap is not None and p_gap <= lt["max_pgap_top2"]:
            cand = dict(market="1X2", outcome=top2, p=probs[top2], odds=odds[top2], ev=evs.get(top2),
                        agreement="top2", pgap=p_gap, label=_label_for("1X2", top2))
            if not (odds.get(top2) is not None and odds[top2] >= lt["odds_hardcap_1x2"] and (probs[top2] is None or probs[top2] < 0.18)):
                candidates_1x2.append(cand)

    # ничья — отдельный кандидат
    draw_candidate = None
    if draw_ok and evs.get("draw") is not None and evs["draw"] >= DRAW_MIN_EV:
        draw_candidate = dict(market="1X2", outcome="draw", p=pD, odds=odds["draw"], ev=evs["draw"],
                              agreement=("aligned" if top1=="draw" else ("top2" if top2=="draw" else "contrarian")),
                              pgap=p_gap, label=_label_for("1X2","draw"))

    # ---- выбор по 1X2 ----
    rec_outcome = None
    side_candidates = [c for c in candidates_1x2 if c.get("outcome") in ("home", "away")]
    side_with_ev = [c for c in side_candidates if c.get("ev") is not None]

    # 1) если есть сторона с EV >= порога — берём её
    if side_with_ev:
        best_side_ev = sorted(side_with_ev, key=lambda c: (c.get("ev") or -1, c.get("p") or -1), reverse=True)[0]
        if (best_side_ev.get("ev") or 0) >= SIDE_MIN_EV:
            rec_outcome = best_side_ev

    # 2) иначе, ничья только если сильно лучше по EV
    if rec_outcome is None and draw_candidate and side_candidates:
        best_side = sorted(side_candidates, key=lambda c: (c.get("ev") if c.get("ev") is not None else -1, c.get("p") or -1), reverse=True)[0]
        side_ev = best_side.get("ev") if best_side else None
        if side_ev is not None and draw_candidate["ev"] >= (side_ev + DRAW_PRIORITY_MARGIN):
            rec_outcome = draw_candidate

    # 3) иначе — вероятностный фоллбэк на сторону (динамический порог + минимальный p-gap)
    if rec_outcome is None and top1 in ("home", "away") and (probs.get(top1) or 0) >= eff_min_p:
        if (p_gap is None) or (p_gap >= PROB_GAP_MIN) or not draw_candidate:
            rec_outcome = dict(market="1X2", outcome=top1, p=probs[top1], odds=odds[top1], ev=evs.get(top1),
                               agreement="prob_only", pgap=p_gap, label=_label_for("1X2", top1))

    # 4) если всё ещё ничего — можно рассмотреть ничью при близкой игре (чуть мягче)
    if rec_outcome is None and draw_candidate and abs((pH or 0) - (pA or 0)) <= lt["draw_close_gap"]:
        rec_outcome = draw_candidate

    # ---- тоталы (как были) ----
    candidates_tot: List[Dict[str, Any]] = []
    if pOver is not None and odOver is not None:
        e = evOver
        if pOver >= lt["min_p_total"] and e is not None and e >= lt["min_ev_total"]:
            candidates_tot.append(dict(market="OU25", outcome="over", p=pOver, odds=odOver, ev=e, label=_label_for("OU25","over")))
    if pUnder is not None and odUnder is not None:
        e = evUnder
        if pUnder >= lt["min_p_total"] and e is not None and e >= lt["min_ev_total"]:
            candidates_tot.append(dict(market="OU25", outcome="under", p=pUnder, odds=odUnder, ev=e, label=_label_for("OU25","under")))

    rec_total = None
    if candidates_tot:
        rec_total = sorted(candidates_tot, key=lambda c: (c.get("ev") or -1, c.get("p") or -1), reverse=True)[0]

    return {"outcome": rec_outcome, "total": rec_total, "blowout": blowout}

# ------------------- текст (NLG) -------------------

def _trend_word(x: Optional[float]) -> str:
    if x is None: return "неясная"
    if x >= 0.60: return "хорошая"
    if x >= 0.45: return "средняя"
    return "слабая"

def _shape_sentence(team_tag: str, form_idx: Optional[float], gf: Optional[float], ga: Optional[float], form_str: str) -> str:
    t = _trend_word(form_idx)
    gf_s = _fmt_num(gf,1); ga_s = _fmt_num(ga,1)
    base = f"{team_tag}: {t} форма ({form_str or '—'}), в среднем {gf_s} заб. / {ga_s} проп. за матч."
    return base

def narrative_for_outcome(ctx: Dict[str, Any], rec: Optional[Dict[str, Any]]) -> str:
    if not rec: return "По исходам: рабочего варианта с положительным EV не найдено."
    h,a = ctx["home"], ctx["away"]
    line = rec.get("label","—")
    bits = [f"Исход: {line} (p={_fmt_pct(rec.get('p'),0)}, odds={_fmt_num(rec.get('odds'),2)}, EV={_fmt_pct(rec.get('ev'),0)})."]
    bits.append(_shape_sentence(ctx['home_name'], h.get("form_index"), h.get("gf"), h.get("ga"), h.get("form_str")))
    bits.append(_shape_sentence(ctx['away_name'], a.get("form_index"), a.get("gf"), a.get("ga"), a.get("form_str")))
    try:
        if (h.get("form_index") is not None) and (a.get("form_index") is not None):
            diff = h["form_index"] - a["form_index"]
            if rec.get("outcome")=="home" and diff >= 0.10:
                bits.append("Хозяева выглядят стабильнее в последних играх.")
            if rec.get("outcome")=="away" and diff <= -0.10:
                bits.append("Гости в лучшей текущей форме.")
    except Exception:
        pass
    h2h = ctx.get("h2h") or {}
    if h2h.get("home_wins",0)+h2h.get("draws",0)+h2h.get("away_wins",0) >= 3:
        bits.append(f"H2H: {h2h.get('home_wins',0)}–{h2h.get('draws',0)}–{h2h.get('away_wins',0)} со стороны хозяев.")
    th = ctx["key_players"].get("home",[])
    ta = ctx["key_players"].get("away",[])
    if th:
        s = ", ".join([f"{p['name']} {p['g_last5']} гол(ов) за 5 игр" for p in th])
        bits.append(f"Лидеры хозяев: {s}.")
    if ta:
        s = ", ".join([f"{p['name']} {p['g_last5']} гол(ов)" for p in ta])
        bits.append(f"Лидеры гостей: {s}.")
    return " ".join(bits)

def narrative_for_total(ctx: Dict[str, Any], rec: Optional[Dict[str, Any]], totals_hint: Dict[str, Any]) -> str:
    if not rec: return "По тоталам: подходящего варианта с положительным EV не найдено."
    line = rec.get("label","—")
    avg_goals = totals_hint.get("avg_goals_last10")
    under_rate = totals_hint.get("under25_rate_last10")
    bits = [f"Тотал: {line} (p={_fmt_pct(rec.get('p'),0)}, odds={_fmt_num(rec.get('odds'),2)}, EV={_fmt_pct(rec.get('ev'),0)})."]
    if rec.get("outcome")=="over":
        tips = []
        if avg_goals is not None and avg_goals >= 2.7: tips.append(f"средний тотал последних матчей ≈ {_fmt_num(avg_goals,1)}")
        h, a = ctx["home"], ctx["away"]
        try:
            if (h.get("gf") or 0) + (a.get("gf") or 0) >= 3.0: tips.append("обе команды регулярно создают моменты")
        except Exception:
            pass
        if tips: bits.append("Ожидаем результативный матч: " + ", ".join(tips) + ".")
        else: bits.append("Модель видит предпосылки к верховому матчу.")
    else:  # under
        tips = []
        if avg_goals is not None and avg_goals <= 2.3: tips.append(f"низкий средний тотал ≈ {_fmt_num(avg_goals,1)}")
        if under_rate is not None and under_rate >= 0.55: tips.append(f"доля ТМ2.5 в недавних матчах {_fmt_pct(under_rate,0)}")
        if tips: bits.append("Факторы в пользу низового тотала: " + ", ".join(tips) + ".")
        else: bits.append("Модель склоняется к осторожному матчу с малым числом голов.")
    return " ".join(bits)

# ------------------- SINGLE endpoint -------------------

@router.get("/match-insight")
def match_insight(fixture_id: int, last_n: int = Query(6, ge=3, le=10)):
    try:
        with engine.connect() as conn:
            fx = fetch_df(conn, SQL_FIXTURE, fid=fixture_id)
            if fx.empty:
                raise HTTPException(status_code=404, detail="fixture not found")
            f = fx.iloc[0]
            dt = pd.to_datetime(f["date_utc"])

            pred = fetch_df(conn, SQL_PRED, fid=fixture_id)
            if pred.empty:
                raise HTTPException(status_code=404, detail="prediction not found")
            p = pred.iloc[0]

            # probs/odds
            p_home=_safe(p.get("p_home")); p_draw=_safe(p.get("p_draw")); p_away=_safe(p.get("p_away"))
            od_home=_safe(p.get("avg_odds_home")); od_draw=_safe(p.get("avg_odds_draw")); od_away=_safe(p.get("avg_odds_away"))

            rec_raw = dict(
                p_home=p_home, p_draw=p_draw, p_away=p_away,
                od_home=od_home, od_draw=od_draw, od_away=od_away,
                # EV c fallback, если колонок ev_* нет или они NULL
                ev_home=_safe(p.get("ev_home")) if p.get("ev_home") is not None else ev(p_home, od_home),
                ev_draw=_safe(p.get("ev_draw")) if p.get("ev_draw") is not None else ev(p_draw, od_draw),
                ev_away=_safe(p.get("ev_away")) if p.get("ev_away") is not None else ev(p_away, od_away),
                p_over25=_safe(p.get("p_over25")), p_under25=_safe(p.get("p_under25")),
                od_over25=_safe(p.get("avg_odds_over25")), od_under25=_safe(p.get("avg_odds_under25")),
                ev_over=_safe(p.get("ev_over")), ev_under=_safe(p.get("ev_under")),
            )

            # форма/контекст
            home_id = int(f["home_team_id"]); away_id = int(f["away_team_id"])
            d_home = fetch_df(conn, SQL_LAST_MATCHES, tid=home_id, dt=dt, lim=last_n)
            d_away = fetch_df(conn, SQL_LAST_MATCHES, tid=away_id, dt=dt, lim=last_n)
            ag_h = avg_gf_ga(d_home, home_id, n=last_n); ag_a = avg_gf_ga(d_away, away_id, n=last_n)

            # быстрый индекс формы через очки (exponential weights)
            def _form_idx(df, tid):
                if df.empty: return 0.0
                rows = []
                for _, r in df.head(last_n).iterrows():
                    is_home = int(r["home_team_id"]) == tid
                    hg = _safe(r["home_goals"], int, None); ag = _safe(r["away_goals"], int, None)
                    rows.append(classify_res(hg, ag, is_home))
                wts = np.linspace(0.6, 1.0, num=len(rows))
                pts = sum(w_points(r, w) for r, w in zip(rows, wts))
                return pts / (3.0 * sum(wts))
            form_home_idx = _form_idx(d_home, home_id)
            form_away_idx = _form_idx(d_away, away_id)

            d_h2h = fetch_df(conn, SQL_H2H, h=home_id, a=away_id, dt=dt, lim=5)
            h2h = h2h_summary(d_h2h, home_id)

            th = players_form_last5(conn, home_id, dt)
            ta = players_form_last5(conn, away_id, dt)

        dual = guard_dual(rec_raw, f.get("league"))
        ctx = dict(
            league = f.get("league"),
            round  = f.get("round"),
            home_name = f.get("home_team"),
            away_name = f.get("away_team"),
            home  = dict(form_index=form_home_idx, gf=ag_h["gf"], ga=ag_h["ga"], form_str=lastN_form_string(d_home, home_id, n=last_n)),
            away  = dict(form_index=form_away_idx, gf=ag_a["gf"], ga=ag_a["ga"], form_str=lastN_form_string(d_away, away_id, n=last_n)),
            h2h   = h2h,
            key_players = {"home": th, "away": ta},
        )
        totals_hint = totals_profile(d_home, d_away, n=min(10, last_n*2))
        out_narr = dict(
            outcome = narrative_for_outcome(ctx, dual["outcome"]),
            total   = narrative_for_total(ctx, dual["total"], totals_hint),
        )

        out = dict(
            fixture_id = fixture_id,
            date_utc   = str(f["date_utc"]),
            league     = f.get("league"),
            round      = f.get("round"),
            home_team  = f.get("home_team"),
            away_team  = f.get("away_team"),

            # НОВОЕ: отдаём триаду вероятностей и кэфов 1X2 для фронта
            probs_1x2 = dict(home=rec_raw.get("p_home"),
                             draw=rec_raw.get("p_draw"),
                             away=rec_raw.get("p_away")),
            odds_1x2  = dict(home=rec_raw.get("od_home"),
                             draw=rec_raw.get("od_draw"),
                             away=rec_raw.get("od_away")),

            recommendations = dual,  # { outcome:{...}, total:{...}, blowout:bool }
            insights = dict(
                home=dict(name=f.get("home_team"), form_last5=ctx["home"]["form_str"], gf_last5=round(ctx["home"]["gf"],3), ga_last5=round(ctx["home"]["ga"],3)),
                away=dict(name=f.get("away_team"), form_last5=ctx["away"]["form_str"], gf_last5=round(ctx["away"]["gf"],3), ga_last5=round(ctx["away"]["ga"],3)),
                totals= dict(avg_goals_last10=totals_hint["avg_goals_last10"], under25_rate_last10=totals_hint["under25_rate_last10"]),
                h2h=h2h,
                top_scorers = ctx["key_players"],
            ),
            narrative = out_narr
        )
        return JSONResponse(out)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ------------------- BATCH endpoint (НОВЫЙ) -------------------

@router.get("/fixture-insights")
def fixture_insights(fixture_ids: str = Query(..., description="comma-separated fixture ids"),
                     last_n: int = Query(5, ge=3, le=10),
                     totals_n: int = Query(10, ge=6, le=20)):
    try:
        ids = [int(x) for x in str(fixture_ids).split(",") if x.strip()]
        if not ids:
            return JSONResponse({})
        out: Dict[str, Any] = {}
        with engine.connect() as conn:
            for fid in ids:
                try:
                    fx = fetch_df(conn, SQL_FIXTURE, fid=fid)
                    if fx.empty:
                        continue
                    f = fx.iloc[0]
                    dt = pd.to_datetime(f["date_utc"])
                    home_id = int(f["home_team_id"]); away_id = int(f["away_team_id"])

                    # preds
                    try:
                        pred = fetch_df(conn, SQL_PRED, fid=fid)
                        p = pred.iloc[0] if not pred.empty else pd.Series({})
                    except Exception:
                        p = pd.Series({})

                    p_home=_safe(p.get("p_home")); p_draw=_safe(p.get("p_draw")); p_away=_safe(p.get("p_away"))
                    od_home=_safe(p.get("avg_odds_home")); od_draw=_safe(p.get("avg_odds_draw")); od_away=_safe(p.get("avg_odds_away"))
                    rec_raw = dict(
                        p_home=p_home, p_draw=p_draw, p_away=p_away,
                        od_home=od_home, od_draw=od_draw, od_away=od_away,
                        ev_home=_safe(p.get("ev_home")) if p.get("ev_home") is not None else ev(p_home, od_home),
                        ev_draw=_safe(p.get("ev_draw")) if p.get("ev_draw") is not None else ev(p_draw, od_draw),
                        ev_away=_safe(p.get("ev_away")) if p.get("ev_away") is not None else ev(p_away, od_away),
                        p_over25=_safe(p.get("p_over25")), p_under25=_safe(p.get("p_under25")),
                        od_over25=_safe(p.get("avg_odds_over25")), od_under25=_safe(p.get("avg_odds_under25")),
                        ev_over=_safe(p.get("ev_over")), ev_under=_safe(p.get("ev_under")),
                    )

                    d_home = fetch_df(conn, SQL_LAST_MATCHES, tid=home_id, dt=dt, lim=max(last_n, totals_n))
                    d_away = fetch_df(conn, SQL_LAST_MATCHES, tid=away_id, dt=dt, lim=max(last_n, totals_n))

                    ag_h = avg_gf_ga(d_home, home_id, n=last_n); ag_a = avg_gf_ga(d_away, away_id, n=last_n)
                    def _form_idx(df, tid, n):
                        if df.empty: return 0.0
                        rows = []
                        for _, r in df.head(n).iterrows():
                            is_home = int(r["home_team_id"]) == tid
                            hg = _safe(r["home_goals"], int, None); ag = _safe(r["away_goals"], int, None)
                            rows.append(classify_res(hg, ag, is_home))
                        wts = np.linspace(0.6, 1.0, num=len(rows))
                        pts = sum(w_points(r, w) for r, w in zip(rows, wts))
                        return pts / (3.0 * sum(wts))
                    fh = _form_idx(d_home, home_id, last_n)
                    fa = _form_idx(d_away, away_id, last_n)

                    d_h2h = fetch_df(conn, SQL_H2H, h=home_id, a=away_id, dt=dt, lim=5)
                    h2h = h2h_summary(d_h2h, home_id)

                    th = players_form_last5(conn, home_id, dt)
                    ta = players_form_last5(conn, away_id, dt)

                    totals_hint = totals_profile(d_home, d_away, n=totals_n)
                    dual = guard_dual(rec_raw, f.get("league"))

                    ctx = dict(
                        league = f.get("league"),
                        round  = f.get("round"),
                        home_name = f.get("home_team"),
                        away_name = f.get("away_team"),
                        home  = dict(form_index=fh, gf=ag_h["gf"], ga=ag_h["ga"], form_str=lastN_form_string(d_home, home_id, n=last_n)),
                        away  = dict(form_index=fa, gf=ag_a["gf"], ga=ag_a["ga"], form_str=lastN_form_string(d_away, away_id, n=last_n)),
                        h2h   = h2h,
                        key_players = {"home": th, "away": ta},
                    )
                    out[str(fid)] = dict(
                        # НОВОЕ: триады для фронта
                        probs_1x2 = dict(home=rec_raw.get("p_home"),
                                         draw=rec_raw.get("p_draw"),
                                         away=rec_raw.get("p_away")),
                        odds_1x2  = dict(home=rec_raw.get("od_home"),
                                         draw=rec_raw.get("od_draw"),
                                         away=rec_raw.get("od_away")),

                        recommendations = dual,  # {outcome,total,blowout}
                        insights = dict(
                            home=dict(name=f.get("home_team"), form_last5=ctx["home"]["form_str"], gf_last5=round(ctx["home"]["gf"],3), ga_last5=round(ctx["home"]["ga"],3)),
                            away=dict(name=f.get("away_team"), form_last5=ctx["away"]["form_str"], gf_last5=round(ctx["away"]["gf"],3), ga_last5=round(ctx["away"]["ga"],3)),
                            totals= dict(avg_goals_last10=totals_hint["avg_goals_last10"], under25_rate_last10=totals_hint["under25_rate_last10"]),
                            h2h=h2h,
                            top_scorers = ctx["key_players"],
                        ),
                        narrative = dict(
                            outcome = narrative_for_outcome(ctx, dual["outcome"]),
                            total   = narrative_for_total(ctx, dual["total"], totals_hint),
                        ),
                    )
                except Exception:
                    continue

        return JSONResponse(out)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
