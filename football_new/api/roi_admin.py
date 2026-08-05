import os
from datetime import date
from pathlib import Path
import re
from typing import Optional, List, Dict, Any

import numpy as np
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import create_engine, text

from api.auth_dwh import get_current_user_dwh
from api.core.config import settings

router = APIRouter(prefix="/api/roi-admin", tags=["roi-admin"])

DB_URL = os.getenv("DB_URL", settings.DATABASE_URL)
engine = create_engine(DB_URL, pool_pre_ping=True)


def _default_season_year(today: Optional[date] = None) -> int:
    current = today or date.today()
    return current.year if current.month >= 7 else current.year - 1


def _default_roi_date_from() -> str:
    return f"{_default_season_year()}-08-01"


def _default_roi_date_to() -> str:
    return f"{_default_season_year() + 1}-06-30"

# -----------------------
# Access control
# -----------------------

def _allowed_emails() -> List[str]:
    raw = os.getenv("ROI_ADMIN_EMAILS", "")
    if not raw:
        env_path = Path(__file__).resolve().parent / ".env"
        if env_path.exists():
            try:
                for line in env_path.read_text(encoding="utf-8").splitlines():
                    if not line or line.strip().startswith("#") or "=" not in line:
                        continue
                    key, value = line.split("=", 1)
                    if key.strip() == "ROI_ADMIN_EMAILS":
                        raw = value.strip()
                        break
            except Exception:
                pass
    return [x.strip().lower() for x in raw.split(",") if x.strip()]


def require_roi_admin(user=Depends(get_current_user_dwh)):
    allowed = _allowed_emails()
    if not allowed:
        raise HTTPException(status_code=403, detail="ROI admin access is not configured.")
    if (user.email or "").lower() not in allowed:
        raise HTTPException(status_code=403, detail="ROI admin access denied.")
    return user


# -----------------------
# Decision rules (копия из frontend/model/decision)
# -----------------------

LEAGUE_OUTCOME_RULES = {
    39: {  # Premier League
        "ev_A": 0.16,
        "ev_B": 0.12,
        "min_odds_A": 1.90,
        "max_odds_A": 2.20,
        "min_odds_B": 2.00,
        "max_odds_B": 2.60,
        "allow_draw": True,
    },
    61: {  # Ligue 1
        "ev_A": 0.10,
        "ev_B": 0.10,
        "min_odds_A": 1.50,
        "max_odds_A": 2.20,
        "min_odds_B": 1.40,
        "max_odds_B": 2.80,
        "allow_draw": True,
    },
    78: {  # Bundesliga
        "ev_A": 0.08,
        "ev_B": 0.04,
        "min_odds_A": 2.10,
        "max_odds_A": 2.40,
        "min_odds_B": 2.00,
        "max_odds_B": 2.60,
        "allow_draw": True,
    },
    135: {  # Serie A
        "ev_A": 0.10,
        "ev_B": 0.04,
        "min_odds_A": 1.50,
        "max_odds_A": 2.20,
        "min_odds_B": 2.00,
        "max_odds_B": 2.60,
        "allow_draw": True,
    },
    140: {  # La Liga
        "ev_A": 0.14,
        "ev_B": 0.12,
        "min_odds_A": 1.50,
        "max_odds_A": 2.40,
        "min_odds_B": 2.00,
        "max_odds_B": 2.60,
        "allow_draw": True,
    },
}

DEFAULT_OUTCOME_RULE = {
    "ev_A": 0.20,
    "ev_B": 0.16,
    "min_odds_A": 1.90,
    "max_odds_A": 2.50,
    "min_odds_B": 2.10,
    "max_odds_B": 2.80,
    "allow_draw": False,
}

LEAGUE_RULES = {
    78: {  # Bundesliga
        "edge_A": 0.06,
        "edge_B": 0.00,
        "min_odds_A": 1.55,
        "max_odds_A": 2.20,
        "min_odds_B": 1.55,
        "max_odds_B": 2.20,
    },
    135: {  # Serie A
        "edge_A": 0.12,
        "edge_B": 0.00,
        "min_odds_A": 1.55,
        "max_odds_A": 2.60,
        "min_odds_B": 1.65,
        "max_odds_B": 2.00,
    },
    39: {  # Premier League
        "edge_A": 0.12,
        "edge_B": 0.00,
        "min_odds_A": 1.65,
        "max_odds_A": 2.40,
        "min_odds_B": 1.50,
        "max_odds_B": 2.40,
        "exclude_edge_ranges": [(0.04, 0.08)],
    },
    140: {  # La Liga
        "edge_A": 0.08,
        "edge_B": 0.00,
        "min_odds_A": 1.60,
        "max_odds_A": 2.00,
        "min_odds_B": 1.60,
        "max_odds_B": 2.00,
        "exclude_edge_ranges": [(0.04, 0.08)],
    },
    61: {  # Ligue 1
        "edge_A": 0.06,
        "edge_B": 0.00,
        "min_odds_A": 1.55,
        "max_odds_A": 2.00,
        "min_odds_B": 1.70,
        "max_odds_B": 2.00,
    },
}

DEFAULT_RULE = {
    "edge_A": 0.15,
    "edge_B": 0.12,
    "min_odds_A": 1.60,
    "min_odds_B": 1.75,
}


def decide_outcome_bet(ev: float, odds: float, league_id: int, outcome: str) -> str:
    if ev is None or odds is None:
        return "NO BET"

    rules = LEAGUE_OUTCOME_RULES.get(league_id, DEFAULT_OUTCOME_RULE)

    if outcome == "Draw" and not rules.get("allow_draw", True):
        return "NO BET"

    max_odds_a = rules.get("max_odds_A")
    in_a = odds >= rules["min_odds_A"] and (max_odds_a is None or odds <= max_odds_a)
    if in_a and ev >= rules["ev_A"]:
        return "A"

    max_odds_b = rules.get("max_odds_B")
    in_b = odds >= rules["min_odds_B"] and (max_odds_b is None or odds <= max_odds_b)
    if in_b and ev >= rules["ev_B"]:
        return "B"

    return "NO BET"


def decide_total_bet(edge: float, odds: float, league_id: int, p_model: float) -> str:
    if not (edge and odds and p_model):
        return "NO BET"

    rules = LEAGUE_RULES.get(league_id, DEFAULT_RULE)
    for edge_min, edge_max in rules.get("exclude_edge_ranges", []):
        if edge_min <= edge < edge_max:
            return "NO BET"

    max_odds_a = rules.get("max_odds_A")
    in_a = odds >= rules["min_odds_A"] and (max_odds_a is None or odds <= max_odds_a)
    if in_a and edge >= rules["edge_A"]:
        return "A"

    max_odds_b = rules.get("max_odds_B")
    in_b = odds >= rules["min_odds_B"] and (max_odds_b is None or odds <= max_odds_b)
    if in_b and edge >= rules["edge_B"]:
        return "B"

    return "NO BET"


# -----------------------
# Helpers
# -----------------------

def _round_num(label: Optional[str]) -> Optional[int]:
    if not label:
        return None
    m = re.findall(r"\\d+", label)
    if not m:
        return None
    try:
        return int(m[-1])
    except Exception:
        return None


def _ev(p, odds):
    if p is None or odds is None:
        return None
    if odds <= 1:
        return None
    return p * odds - 1.0


def _profit_1x2(outcome: str, hg: int, ag: int, odds: float) -> float:
    if outcome == "Home":
        win = hg > ag
    elif outcome == "Draw":
        win = hg == ag
    else:
        win = hg < ag
    return (odds - 1.0) if win else -1.0


def _profit_total(side: str, hg: int, ag: int, odds: float) -> float:
    goals = hg + ag
    if side == "Over2.5":
        win = goals >= 3
    else:
        win = goals <= 2
    return (odds - 1.0) if win else -1.0


def _stake(tier: str) -> float:
    return 1.0 if tier == "A" else 0.4


def _load_matches(date_from: str, date_to: str, season: Optional[int], league_id: Optional[int]) -> List[Dict[str, Any]]:
    query = """
    SELECT
        p.fixture_id,
        s.league_id,
        s.league_name,
        s.season,
        s.round,
        s.date::date AS match_date,
        s.home_team,
        s.away_team,
        s.home_goals,
        s.away_goals,
        p.p_home,
        p.p_draw,
        p.p_away,
        p.p_over25,
        m.avg_odds_home,
        m.avg_odds_draw,
        m.avg_odds_away,
        m.avg_odds_over25,
        m.avg_odds_under25
    FROM football.ml_predictions p
    JOIN football.api_football_schedule s
      ON s.fixture_id = p.fixture_id
    JOIN football.v_ml_epl_training m
      ON m.fixture_id = p.fixture_id
    WHERE s.date BETWEEN :dfrom AND :dto
      AND s.home_goals IS NOT NULL
      AND s.away_goals IS NOT NULL
      AND (:season IS NULL OR s.season = :season)
      AND (:league_id IS NULL OR s.league_id = :league_id)
    """
    params = {"dfrom": date_from, "dto": date_to, "season": season, "league_id": league_id}
    with engine.connect() as conn:
        rows = conn.execute(text(query), params).mappings().all()
    return [dict(r) for r in rows]


def _compute_decisions(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    out = []
    for r in rows:
        lid = int(r["league_id"])
        hg = int(r["home_goals"])
        ag = int(r["away_goals"])

        # ---- 1X2 best EV ----
        options = []
        for outcome, p, odds in [
            ("Home", r.get("p_home"), r.get("avg_odds_home")),
            ("Draw", r.get("p_draw"), r.get("avg_odds_draw")),
            ("Away", r.get("p_away"), r.get("avg_odds_away")),
        ]:
            if p is None or odds is None:
                continue
            ev = _ev(float(p), float(odds))
            if ev is None:
                continue
            options.append((outcome, float(p), float(odds), ev))
        best = max(options, key=lambda x: x[3]) if options else None

        outcome_pick = None
        outcome_tier = "NO BET"
        outcome_profit = None
        outcome_ev = None
        outcome_odds = None
        if best:
            outcome_pick, _, outcome_odds, outcome_ev = best
            outcome_tier = decide_outcome_bet(outcome_ev, outcome_odds, lid, outcome_pick)
            if outcome_tier in ("A", "B"):
                outcome_profit = _profit_1x2(outcome_pick, hg, ag, outcome_odds) * _stake(outcome_tier)

        # ---- Totals ----
        over_odds = r.get("avg_odds_over25")
        under_odds = r.get("avg_odds_under25")
        p_over = r.get("p_over25")
        total_side = None
        total_tier = "NO BET"
        total_profit = None
        total_edge = None
        total_odds = None
        if p_over is not None and over_odds and under_odds:
            imp_over = 1.0 / float(over_odds)
            imp_under = 1.0 / float(under_odds)
            overround = imp_over + imp_under
            p_market = imp_over / overround if overround > 0 else None
            p_model = float(p_over)
            if lid == 140 and p_market is not None:
                p_model = 0.9 * p_model + 0.1 * p_market
            total_edge = (p_model - p_market) if p_market is not None else None
            total_side = "Over2.5" if p_model >= 0.5 else "Under2.5"
            total_odds = float(over_odds) if total_side == "Over2.5" else float(under_odds)
            total_tier = decide_total_bet(total_edge, total_odds, lid, p_model)
            if total_tier in ("A", "B"):
                total_profit = _profit_total(total_side, hg, ag, total_odds) * _stake(total_tier)

        out.append(
            {
                **r,
                "round_num": _round_num(r.get("round")),
                "outcome_pick": outcome_pick,
                "outcome_ev": outcome_ev,
                "outcome_odds": outcome_odds,
                "outcome_tier": outcome_tier,
                "outcome_profit": outcome_profit,
                "total_pick": total_side,
                "total_edge": total_edge,
                "total_odds": total_odds,
                "total_tier": total_tier,
                "total_profit": total_profit,
            }
        )
    return out


# -----------------------
# Endpoints
# -----------------------

@router.get("/summary")
def roi_summary(
    season: Optional[int] = Query(None),
    league_id: Optional[int] = Query(None),
    date_from: str = Query(_default_roi_date_from()),
    date_to: str = Query(_default_roi_date_to()),
    user=Depends(require_roi_admin),
):
    rows = _compute_decisions(_load_matches(date_from, date_to, season, league_id))
    by_league: Dict[int, Dict[str, Any]] = {}

    for r in rows:
        lid = int(r["league_id"])
        league = r.get("league_name") or str(lid)
        lrec = by_league.setdefault(lid, {"league_id": lid, "league": league, "rounds": {}})
        round_label = r.get("round") or "—"
        rrec = lrec["rounds"].setdefault(
            round_label,
            {
                "round": round_label,
                "round_num": r.get("round_num"),
                "first_date": r.get("match_date"),
                "matches": 0,
                "outcome": {"bets": 0, "stake": 0.0, "profit": 0.0},
                "total": {"bets": 0, "stake": 0.0, "profit": 0.0},
            },
        )
        if r.get("match_date") and (rrec.get("first_date") is None or r.get("match_date") < rrec.get("first_date")):
            rrec["first_date"] = r.get("match_date")
        rrec["matches"] += 1

        if r.get("outcome_tier") in ("A", "B"):
            stake = _stake(r["outcome_tier"])
            rrec["outcome"]["bets"] += 1
            rrec["outcome"]["stake"] += stake
            profit = float(r.get("outcome_profit") or 0.0)
            rrec["outcome"]["profit"] += profit
            rrec["outcome"].setdefault("wins", 0)
            rrec["outcome"].setdefault("losses", 0)
            rrec["outcome"].setdefault("pushes", 0)
            rrec["outcome"].setdefault("profit_base_sum", 0.0)
            if stake > 0:
                base_profit = profit / stake
                rrec["outcome"]["profit_base_sum"] += base_profit
                if base_profit > 0:
                    rrec["outcome"]["wins"] += 1
                elif base_profit < 0:
                    rrec["outcome"]["losses"] += 1
                else:
                    rrec["outcome"]["pushes"] += 1

        if r.get("total_tier") in ("A", "B"):
            stake = _stake(r["total_tier"])
            rrec["total"]["bets"] += 1
            rrec["total"]["stake"] += stake
            profit = float(r.get("total_profit") or 0.0)
            rrec["total"]["profit"] += profit
            rrec["total"].setdefault("wins", 0)
            rrec["total"].setdefault("losses", 0)
            rrec["total"].setdefault("pushes", 0)
            rrec["total"].setdefault("profit_base_sum", 0.0)
            if stake > 0:
                base_profit = profit / stake
                rrec["total"]["profit_base_sum"] += base_profit
                if base_profit > 0:
                    rrec["total"]["wins"] += 1
                elif base_profit < 0:
                    rrec["total"]["losses"] += 1
                else:
                    rrec["total"]["pushes"] += 1

    leagues_out = []
    for _, lrec in sorted(by_league.items(), key=lambda x: x[0]):
        rounds = []
        for _, rr in lrec["rounds"].items():
            for market in ("outcome", "total"):
                stake = rr[market]["stake"]
                rr[market]["roi"] = (rr[market]["profit"] / stake) if stake else None
                bets = rr[market]["bets"]
                base_sum = rr[market].get("profit_base_sum", 0.0)
                rr[market]["roi_flat"] = (base_sum / bets) if bets else None
            rounds.append(rr)
        rounds.sort(key=lambda x: (x.get("first_date") is None, x.get("first_date"), x.get("round_num") is None, x.get("round_num"), x.get("round")))
        leagues_out.append({"league_id": lrec["league_id"], "league": lrec["league"], "rounds": rounds})

    return {"date_from": date_from, "date_to": date_to, "season": season, "leagues": leagues_out}


@router.get("/matches")
def roi_matches(
    season: Optional[int] = Query(None),
    league_id: Optional[int] = Query(None),
    round_label: Optional[str] = Query(None),
    date_from: str = Query(_default_roi_date_from()),
    date_to: str = Query(_default_roi_date_to()),
    user=Depends(require_roi_admin),
):
    rows = _compute_decisions(_load_matches(date_from, date_to, season, league_id))
    if round_label:
        rows = [r for r in rows if (r.get("round") or "—") == round_label]

    out = []
    for r in rows:
        out.append(
            {
                "fixture_id": r["fixture_id"],
                "date": str(r.get("match_date")),
                "league_id": r["league_id"],
                "league": r.get("league_name"),
                "round": r.get("round"),
                "home_team": r.get("home_team"),
                "away_team": r.get("away_team"),
                "score": f"{r.get('home_goals')}-{r.get('away_goals')}",
                "outcome": {
                    "pick": r.get("outcome_pick"),
                    "odds": r.get("outcome_odds"),
                    "ev": r.get("outcome_ev"),
                    "tier": r.get("outcome_tier"),
                    "profit": r.get("outcome_profit"),
                },
                "total": {
                    "pick": r.get("total_pick"),
                    "odds": r.get("total_odds"),
                    "edge": r.get("total_edge"),
                    "tier": r.get("total_tier"),
                    "profit": r.get("total_profit"),
                },
            }
        )

    return {"rows": out}
