# api/ucl.py
from fastapi import APIRouter, Query
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from typing import List, Dict, Any, Optional
import os
from datetime import datetime
from api.core.config import settings

DB_URL = os.getenv("DB_URL", settings.DATABASE_URL)
engine: Engine = create_engine(DB_URL, pool_pre_ping=True)

# Без префикса. Теги нужны, чтобы блок красиво появился в /docs
router = APIRouter(
    prefix="/api",
    tags=["UEFA Champions League"],
    responses={404: {"description": "Not found"}}
)

LEAGUE_ID_UCL = 2

# ---- названия стадий ----
QUAL_ROUNDS = [
    "Preliminary Round",
    "1st Qualifying Round",
    "2nd Qualifying Round",
    "3rd Qualifying Round",
    "Play-offs",  # квалификационный плей-офф перед Swiss
]

# Swiss у разных провайдеров: "League Phase" или "League Stage - N"
LEAGUE_STAGE_PREFIXES = ["League Phase", "League Stage -"]

KNOCKOUT_PLAYOFFS = "Knockout Round Play-offs"  # после Swiss: места 9–24
KO_ROUNDS = ["Round of 16", "Quarter-finals", "Semi-finals", "Final"]

FINISHED_STATUSES = (
    "Match Finished",
    "Match Finished After Penalty",
    "After Extra Time",
)

def rows_to_dicts(res) -> List[Dict[str, Any]]:
    return [dict(r) for r in res.mappings().all()]

def fetch_matches(
    season: int,
    rounds_like: Optional[str] = None,
    rounds_in: Optional[List[str]] = None,
    rounds_like_any: Optional[List[str]] = None,
) -> List[Dict[str, Any]]:
    where = ["league_id = :league_id", "season = :season"]
    params: Dict[str, Any] = {"league_id": LEAGUE_ID_UCL, "season": season}

    if rounds_like:
        where.append("round ILIKE :r_like")
        params["r_like"] = f"{rounds_like}%"

    if rounds_like_any:
        ors = []
        for i, pref in enumerate(rounds_like_any):
            ors.append(f"round ILIKE :r_like_{i}")
            params[f"r_like_{i}"] = f"{pref}%"
        if ors:
            where.append("(" + " OR ".join(ors) + ")")

    if rounds_in:
        where.append("round = ANY(:r_arr)")
        params["r_arr"] = rounds_in

    sql = f"""
        SELECT
          fixture_id, date, timezone, status, round, season,
          home_team_id, home_team, away_team_id, away_team,
          COALESCE(score_fulltime_home, home_goals) AS gh,
          COALESCE(score_fulltime_away, away_goals) AS ga,
          score_penalty_home, score_penalty_away
        FROM football.api_football_schedule
        WHERE {' AND '.join(where)}
        ORDER BY date NULLS LAST, fixture_id
    """
    with engine.connect() as conn:
        res = conn.execute(text(sql), params)
        return rows_to_dicts(res)


# =========================
# 3) Квалификация (двухматчевые серии)
# =========================
@router.get("/ucl/qualifiers")
def ucl_qualifiers(
    season: int = Query(..., ge=2000, le=2100),
    round_name: Optional[str] = Query(None, description="Напр.: '1st Qualifying Round'"),
) -> Dict[str, Any]:
    rounds = [round_name] if round_name else QUAL_ROUNDS
    matches = fetch_matches(season, rounds_in=rounds)
    ties: Dict[str, Dict[str, Any]] = {}

    for m in matches:
        a = min(m["home_team_id"], m["away_team_id"]); b = max(m["home_team_id"], m["away_team_id"])
        key = f"{m['round']}__{a}__{b}"
        leg = {
            "fixture_id": m["fixture_id"], "date": m["date"],
            "home_id": m["home_team_id"], "home": m["home_team"],
            "away_id": m["away_team_id"], "away": m["away_team"],
            "gh": m["gh"], "ga": m["ga"], "status": m["status"],
            "pen_home": m["score_penalty_home"], "pen_away": m["score_penalty_away"],
        }
        if key not in ties:
            ties[key] = {
                "round": m["round"],
                "team_a_id": a, "team_b_id": b,
                "team_a_name": m["home_team"] if m["home_team_id"] == a else m["away_team"],
                "team_b_name": m["home_team"] if m["home_team_id"] == b else m["away_team"],
                "legs": [leg],
            }
        else:
            ties[key]["legs"].append(leg)

    out_by_round: Dict[str, List[Dict[str, Any]]] = {}
    for key, t in ties.items():
        legs = sorted(t["legs"], key=lambda x: x["date"] or "")
        agg_a = agg_b = 0; finished = True; pen: Optional[Dict[str, Any]] = None

        for lg in legs:
            if (lg["status"] or "") not in FINISHED_STATUSES: finished = False
            if lg["home_id"] == t["team_a_id"]:
                if lg["gh"] is not None: agg_a += int(lg["gh"])
                if lg["ga"] is not None: agg_b += int(lg["ga"])
            else:
                if lg["gh"] is not None: agg_b += int(lg["gh"])
                if lg["ga"] is not None: agg_a += int(lg["ga"])
            if lg.get("pen_home") is not None or lg.get("pen_away") is not None:
                pen = {
                    "a": lg["pen_home"] if lg["home_id"] == t["team_a_id"] else lg["pen_away"],
                    "b": lg["pen_away"] if lg["home_id"] == t["team_a_id"] else lg["pen_home"],
                }

        winner_id = None
        if finished:
            if agg_a > agg_b: winner_id = t["team_a_id"]
            elif agg_b > agg_a: winner_id = t["team_b_id"]
            elif pen and pen["a"] is not None and pen["b"] is not None:
                winner_id = t["team_a_id"] if int(pen["a"]) > int(pen["b"]) else t["team_b_id"]

        rec = {
            "round": t["round"], "tie_id": key,
            "team_a_id": t["team_a_id"], "team_a": t["team_a_name"],
            "team_b_id": t["team_b_id"], "team_b": t["team_b_name"],
            "legs": legs,
            "aggregate": {"a": agg_a, "b": agg_b, "winner_team_id": winner_id},
        }
        out_by_round.setdefault(t["round"], []).append(rec)

    for rnd in out_by_round:
        out_by_round[rnd].sort(key=lambda r: (r["legs"][0]["date"] or ""))

    return {"rounds": [{"round": rnd, "ties": out_by_round[rnd]} for rnd in rounds if rnd in out_by_round]}

# =========================
# 4) Knockout Round Play-offs (после Swiss)
# =========================
@router.get("/ucl/playoffs")
def ucl_knockout_playoffs(season: int = Query(..., ge=2000, le=2100)) -> List[Dict[str, Any]]:
    matches = fetch_matches(season, rounds_in=[KNOCKOUT_PLAYOFFS])
    ties: Dict[str, Dict[str, Any]] = {}
    for m in matches:
        a = min(m["home_team_id"], m["away_team_id"]); b = max(m["home_team_id"], m["away_team_id"])
        key = f"{m['round']}__{a}__{b}"
        leg = {
            "fixture_id": m["fixture_id"], "date": m["date"],
            "home_id": m["home_team_id"], "home": m["home_team"],
            "away_id": m["away_team_id"], "away": m["away_team"],
            "gh": m["gh"], "ga": m["ga"], "status": m["status"],
            "pen_home": m["score_penalty_home"], "pen_away": m["score_penalty_away"],
        }
        if key not in ties:
            ties[key] = {"round": m["round"], "legs": [leg]}
        else:
            ties[key]["legs"].append(leg)

    out = []
    for key, t in ties.items():
        legs = sorted(t["legs"], key=lambda x: x["date"] or "")
        agg_left = agg_right = 0; finished = True; pen = None
        left_id = min(legs[0]["home_id"], legs[0]["away_id"])
        right_id = max(legs[0]["home_id"], legs[0]["away_id"])

        left_name = right_name = None
        for lg in legs:
            if lg["home_id"] == left_id:
                left_name = lg["home"]; right_name = lg["away"]; break
            if lg["away_id"] == left_id:
                left_name = lg["away"]; right_name = lg["home"]; break

        for lg in legs:
            if (lg["status"] or "") not in FINISHED_STATUSES: finished = False
            if lg["home_id"] == left_id:
                if lg["gh"] is not None: agg_left += int(lg["gh"])
                if lg["ga"] is not None: agg_right += int(lg["ga"])
            elif lg["away_id"] == left_id:
                if lg["ga"] is not None: agg_left += int(lg["ga"])
                if lg["gh"] is not None: agg_right += int(lg["gh"])
            if lg.get("pen_home") is not None or lg.get("pen_away") is not None:
                pen = lg

        winner_id = None
        if finished:
            if agg_left > agg_right: winner_id = left_id
            elif agg_right > agg_left: winner_id = right_id
            elif pen:
                ph = pen["pen_home"]; pa = pen["pen_away"]
                if ph is not None and pa is not None:
                    winner_id = pen["home_id"] if int(ph) > int(pa) else pen["away_id"]

        out.append({
            "tie_id": key,
            "left_team_id": left_id, "left_team": left_name,
            "right_team_id": right_id, "right_team": right_name,
            "legs": legs,
            "aggregate": {"left": agg_left, "right": agg_right, "winner_team_id": winner_id},
        })

    out.sort(key=lambda r: (r["legs"][0]["date"] or ""))
    return out

# =========================
# 5) Бракет 1/8 → Финал
# =========================
@router.get("/ucl/bracket")
def ucl_bracket(season: int = Query(..., ge=2000, le=2100)) -> Dict[str, Any]:
    matches = fetch_matches(season, rounds_in=KO_ROUNDS)
    by_round: Dict[str, List[Dict[str, Any]]] = {r: [] for r in KO_ROUNDS}

    ties: Dict[str, Dict[str, Any]] = {}
    for m in matches:
        rnd = m["round"]
        a = min(m["home_team_id"], m["away_team_id"]); b = max(m["home_team_id"], m["away_team_id"])
        key = f"{rnd}__{a}__{b}"
        leg = {
            "fixture_id": m["fixture_id"], "date": m["date"],
            "home_id": m["home_team_id"], "home": m["home_team"],
            "away_id": m["away_team_id"], "away": m["away_team"],
            "gh": m["gh"], "ga": m["ga"], "status": m["status"],
            "pen_home": m["score_penalty_home"], "pen_away": m["score_penalty_away"],
        }
        if key not in ties:
            ties[key] = {"round": rnd, "legs": [leg]}
        else:
            ties[key]["legs"].append(leg)

    for key, t in ties.items():
        rnd = t["round"]; legs = sorted(t["legs"], key=lambda x: x["date"] or "")

        if rnd == "Final":
            lg = legs[0]
            left_id, right_id = lg["home_id"], lg["away_id"]
            agg_left, agg_right = int(lg["gh"] or 0), int(lg["ga"] or 0)
            winner_id = None
            finished = (lg["status"] or "") in FINISHED_STATUSES
            if finished:
                if agg_left > agg_right: winner_id = left_id
                elif agg_right > agg_left: winner_id = right_id
                elif lg["pen_home"] is not None and lg["pen_away"] is not None:
                    winner_id = left_id if int(lg["pen_home"]) > int(lg["pen_away"]) else right_id

            by_round[rnd].append({
                "id": key,
                "left_id": left_id, "left": lg["home"],
                "right_id": right_id, "right": lg["away"],
                "legs": legs,
                "agg_left": agg_left, "agg_right": agg_right,
                "winner_team_id": winner_id,
                "status": lg["status"],
            })
            continue

        left_id = min(legs[0]["home_id"], legs[0]["away_id"])
        right_id = max(legs[0]["home_id"], legs[0]["away_id"])
        left_name = right_name = None
        for lg in legs:
            if lg["home_id"] == left_id:
                left_name = lg["home"]; right_name = lg["away"]; break
            if lg["away_id"] == left_id:
                left_name = lg["away"]; right_name = lg["home"]; break

        agg_left = agg_right = 0; finished = True; pen = None
        for lg in legs:
            if (lg["status"] or "") not in FINISHED_STATUSES: finished = False
            if lg["home_id"] == left_id:
                if lg["gh"] is not None: agg_left += int(lg["gh"])
                if lg["ga"] is not None: agg_right += int(lg["ga"])
            else:
                if lg["gh"] is not None: agg_right += int(lg["gh"])
                if lg["ga"] is not None: agg_left += int(lg["ga"])
            if lg.get("pen_home") is not None or lg.get("pen_away") is not None:
                pen = lg

        winner_id = None
        if finished:
            if agg_left > agg_right: winner_id = left_id
            elif agg_right > agg_left: winner_id = right_id
            elif pen:
                ph, pa = pen["pen_home"], pen["pen_away"]
                if ph is not None and pa is not None:
                    winner_id = pen["home_id"] if int(ph) > int(pa) else pen["away_id"]

        by_round[rnd].append({
            "id": key,
            "left_id": left_id, "left": left_name,
            "right_id": right_id, "right": right_name,
            "legs": legs,
            "agg_left": agg_left, "agg_right": agg_right,
            "winner_team_id": winner_id,
            "status": "Finished" if finished else "Scheduled",
        })

    for rnd in KO_ROUNDS:
        by_round[rnd].sort(key=lambda r: (r["legs"][0]["date"] or ""))

    return {
        "rounds": [
            {"code": "R16", "name": "1/8 финала", "matches": by_round["Round of 16"]},
            {"code": "QF",  "name": "1/4 финала", "matches": by_round["Quarter-finals"]},
            {"code": "SF",  "name": "1/2 финала", "matches": by_round["Semi-finals"]},
            {"code": "F",   "name": "Финал",      "matches": by_round["Final"]},
        ]
    }
