from fastapi import APIRouter, Query
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from typing import Dict, Any, List, Optional

from api.core.config import settings

router = APIRouter(
    prefix="/api",
    tags=["International Cups"],
    responses={404: {"description": "Not found"}},
)

engine: Engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

SUPPORTED_CUPS: Dict[str, Dict[str, Any]] = {
    "UEFA Champions League": {
        "league_id": 2,
        "rounds": [
            {"code": "KPO", "name": "1/16 финала", "match_rounds": ["Play-offs", "Knockout Round Play-offs"]},
            {"code": "R16", "name": "1/8 финала", "match_rounds": ["Round of 16"]},
            {"code": "QF", "name": "1/4 финала", "match_rounds": ["Quarter-finals"]},
            {"code": "SF", "name": "1/2 финала", "match_rounds": ["Semi-finals"]},
            {"code": "F", "name": "Финал", "match_rounds": ["Final"]},
        ],
    },
    "UEFA Europa League": {
        "league_id": 3,
        "rounds": [
            {"code": "KPO", "name": "1/16 финала", "match_rounds": ["Play-offs", "Knockout Round Play-offs"]},
            {"code": "R16", "name": "1/8 финала", "match_rounds": ["Round of 16"]},
            {"code": "QF", "name": "1/4 финала", "match_rounds": ["Quarter-finals"]},
            {"code": "SF", "name": "1/2 финала", "match_rounds": ["Semi-finals"]},
            {"code": "F", "name": "Финал", "match_rounds": ["Final"]},
        ],
    },
    "World Cup": {
        "league_id": 1,
        "rounds": [
            {"code": "R16", "name": "1/8 финала", "match_rounds": ["Round of 16"]},
            {"code": "QF", "name": "1/4 финала", "match_rounds": ["Quarter-finals"]},
            {"code": "SF", "name": "1/2 финала", "match_rounds": ["Semi-finals"]},
            {"code": "F", "name": "Финал", "match_rounds": ["Final"]},
        ],
    },
    "Euro Championship": {
        "league_id": 4,
        "rounds": [
            {"code": "R16", "name": "1/8 финала", "match_rounds": ["Round of 16"]},
            {"code": "QF", "name": "1/4 финала", "match_rounds": ["Quarter-finals"]},
            {"code": "SF", "name": "1/2 финала", "match_rounds": ["Semi-finals"]},
            {"code": "F", "name": "Финал", "match_rounds": ["Final"]},
        ],
    },
}

FINISHED_STATUSES = (
    "Match Finished",
    "Match Finished After Penalty",
    "After Extra Time",
    "Full Time",
)


def _rows_to_dicts(res) -> List[Dict[str, Any]]:
    return [dict(r) for r in res.mappings().all()]


def _fetch_matches(league_id: int, season: int, rounds: List[str]) -> List[Dict[str, Any]]:
    sql = text(
        """
        SELECT
          fixture_id,
          date,
          timezone,
          status,
          round,
          season,
          home_team_id,
          home_team,
          away_team_id,
          away_team,
          score_fulltime_home,
          score_fulltime_away,
          COALESCE(score_fulltime_home, home_goals) AS gh,
          COALESCE(score_fulltime_away, away_goals) AS ga,
          home_goals AS final_home,
          away_goals AS final_away,
          score_penalty_home,
          score_penalty_away
        FROM football.api_football_schedule
        WHERE league_id = :league_id
          AND season = :season
          AND round = ANY(:rounds)
        ORDER BY date NULLS LAST, fixture_id
        """
    )
    with engine.connect() as conn:
        return _rows_to_dicts(
            conn.execute(
                sql,
                {
                    "league_id": league_id,
                    "season": season,
                    "rounds": rounds,
                },
            )
        )


def _build_round_matches(matches: List[Dict[str, Any]], round_names: List[str]) -> List[Dict[str, Any]]:
    round_names_set = set(round_names)
    ties: Dict[str, Dict[str, Any]] = {}
    for match in matches:
        if match["round"] not in round_names_set:
            continue
        left_id = min(match["home_team_id"], match["away_team_id"])
        right_id = max(match["home_team_id"], match["away_team_id"])
        key = f"{match['round']}__{left_id}__{right_id}"
        leg = {
            "fixture_id": match["fixture_id"],
            "date": match["date"],
            "home_id": match["home_team_id"],
            "home": match["home_team"],
            "away_id": match["away_team_id"],
            "away": match["away_team"],
            "ft_home": match["score_fulltime_home"],
            "ft_away": match["score_fulltime_away"],
            "final_home": match["final_home"],
            "final_away": match["final_away"],
            "gh": match["gh"],
            "ga": match["ga"],
            "status": match["status"],
            "pen_home": match["score_penalty_home"],
            "pen_away": match["score_penalty_away"],
        }
        if key not in ties:
            ties[key] = {"round": match["round"], "legs": [leg]}
        else:
            ties[key]["legs"].append(leg)

    out: List[Dict[str, Any]] = []
    for key, tie in ties.items():
        legs = sorted(tie["legs"], key=lambda x: x["date"] or "")
        left_id = min(legs[0]["home_id"], legs[0]["away_id"])
        right_id = max(legs[0]["home_id"], legs[0]["away_id"])

        left_name: Optional[str] = None
        right_name: Optional[str] = None
        agg_left = 0
        agg_right = 0
        display_left = None
        display_right = None
        ft_left = None
        ft_right = None
        winner_id = None
        finished = True
        pens = None

        for leg in legs:
            if leg["home_id"] == left_id:
                left_name = leg["home"]
                right_name = leg["away"]
                ft_left = leg["ft_home"] if leg["ft_home"] is not None else leg["gh"]
                ft_right = leg["ft_away"] if leg["ft_away"] is not None else leg["ga"]
                display_left = leg["final_home"] if leg["final_home"] is not None else leg["gh"]
                display_right = leg["final_away"] if leg["final_away"] is not None else leg["ga"]
                if leg["gh"] is not None:
                    agg_left += int(leg["gh"])
                if leg["ga"] is not None:
                    agg_right += int(leg["ga"])
            else:
                left_name = leg["away"]
                right_name = leg["home"]
                ft_left = leg["ft_away"] if leg["ft_away"] is not None else leg["ga"]
                ft_right = leg["ft_home"] if leg["ft_home"] is not None else leg["gh"]
                display_left = leg["final_away"] if leg["final_away"] is not None else leg["ga"]
                display_right = leg["final_home"] if leg["final_home"] is not None else leg["gh"]
                if leg["ga"] is not None:
                    agg_left += int(leg["ga"])
                if leg["gh"] is not None:
                    agg_right += int(leg["gh"])
            if (leg["status"] or "") not in FINISHED_STATUSES:
                finished = False
            if leg.get("pen_home") is not None or leg.get("pen_away") is not None:
                pens = leg

        if finished:
            winner_left_score = display_left if display_left is not None else agg_left
            winner_right_score = display_right if display_right is not None else agg_right
            if winner_left_score > winner_right_score:
                winner_id = left_id
            elif winner_right_score > winner_left_score:
                winner_id = right_id
            elif pens and pens.get("pen_home") is not None and pens.get("pen_away") is not None:
                if pens["home_id"] == left_id:
                    winner_id = left_id if int(pens["pen_home"]) > int(pens["pen_away"]) else right_id
                else:
                    winner_id = left_id if int(pens["pen_away"]) > int(pens["pen_home"]) else right_id

        out.append(
            {
                "id": key,
                "left_id": left_id,
                "left": left_name,
                "right_id": right_id,
                "right": right_name,
                "agg_left": agg_left,
                "agg_right": agg_right,
                "display_left": display_left if display_left is not None else agg_left,
                "display_right": display_right if display_right is not None else agg_right,
                "ft_left": ft_left,
                "ft_right": ft_right,
                "winner_team_id": winner_id,
                "first_fixture_id": legs[0]["fixture_id"] if legs else None,
                "pen_left": (
                    pens["pen_home"] if pens and pens["home_id"] == left_id else
                    pens["pen_away"] if pens else None
                ),
                "pen_right": (
                    pens["pen_away"] if pens and pens["home_id"] == left_id else
                    pens["pen_home"] if pens else None
                ),
                "legs": legs,
            }
        )

    out.sort(key=lambda row: (row["legs"][0]["date"] or ""))
    return out


@router.get("/cup/bracket")
def cup_bracket(
    league: str = Query(..., description="World Cup или Euro Championship"),
    season: int = Query(..., ge=2000, le=2100),
) -> Dict[str, Any]:
    config = SUPPORTED_CUPS.get(league)
    if not config:
        return {"rounds": []}

    all_round_names = [
        rnd_name
        for round_meta in config["rounds"]
        for rnd_name in round_meta["match_rounds"]
    ]
    matches = _fetch_matches(config["league_id"], season, all_round_names)

    return {
        "rounds": [
            {
                "code": round_meta["code"],
                "name": round_meta["name"],
                "matches": _build_round_matches(matches, round_meta["match_rounds"]),
            }
            for round_meta in config["rounds"]
        ]
    }
