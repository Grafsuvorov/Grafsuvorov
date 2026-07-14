# api/match_stats_v3.py
from fastapi import APIRouter, HTTPException, Query, Response
from sqlalchemy import create_engine, text, bindparam
import pandas as pd
import math
import logging
from datetime import date, timedelta
from api.core.config import settings
# === IMPORTS НУЖНЫ ВВЕРХУ ФАЙЛА ===
from typing import Optional




# router, engine, _sanitize уже объявлены у тебя выше


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("uvicorn")
router = APIRouter(
    prefix="/api",
    tags=["Статистика матчей v3"],
    responses={404: {"description": "Not found"}}
)
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)


# =========================
# Helpers
# =========================
def _label_outcome(p_home, p_draw, p_away):
    if p_home is None or p_draw is None or p_away is None:
        return None
    arr = [("П1", p_home), ("Х", p_draw), ("П2", p_away)]
    return max(arr, key=lambda x: x[1])[0]


def _label_total25(p_over25):
    if p_over25 is None:
        return None
    return "Больше 2.5" if p_over25 >= 0.5 else "Меньше 2.5"


def _sanitize(records):
    out = []
    for r in records:
        for k, v in list(r.items()):
            if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
                r[k] = None
        out.append(r)
    return out


# =========================
# API — matches (results + predictions)
# =========================
@router.get("/matches_v3")
def get_matches_v3(
    response: Response,
    from_date: Optional[str] = Query(default=None, description="Дата начала выборки YYYY-MM-DD"),
    to_date: Optional[str] = Query(default=None, description="Дата конца выборки YYYY-MM-DD"),
    league: Optional[str] = Query(default=None, description="Premier League | La Liga | Bundesliga | Serie A | Ligue 1"),
    season: Optional[str] = Query(default=None, description="Год сезона, напр. 2025"),
    fixture_id: Optional[int] = Query(default=None, description="Filter by fixture id"),
    include_upcoming: bool = Query(
        default=False,
        description="Возвращать также будущие матчи (статусы Not Started и т.п.)",
    ),
    include_understat: bool = Query(
        default=False,
        description="Добавить understat xG и лидеров по xG игроков (дороже по времени).",
    ),
    limit: int = Query(
        default=500,
        ge=1,
        le=1000,
        description="Максимум матчей в ответе. Защищает публичный API от слишком больших ответов.",
    ),
    slim: bool = Query(
        default=False,
        description="Облегчённый ответ без тяжёлых match stats joins для списочных страниц.",
    ),
):
    """
    Матчи за период + прогнозы/рынок/сигналы (если уже в ml_predictions) + полная мат.статистика (home_/away_).
    Лига в БД: 'Premier League' | 'La Liga' | 'Bundesliga' | 'Serie A' | 'Ligue 1'
    Сезон — простой год (2020…2025).
    Возвращает ТОЛЬКО сыгранные матчи (по статусам), в т.ч.:
      - round — строковая метка тура (напр. 'Regular Season - 3')
      - home_goals / away_goals — численные голы FT
      - score — строка 'X-Y' (для удобства)
      - result — 1/-1/0 (П1/П2/Х)
    """
    try:
        computed_from = from_date
        computed_to = to_date

        fixture_date_iso = None

        with engine.connect() as conn:
            if fixture_id:
                fixture_date = conn.execute(
                    text("SELECT s.date::date FROM football.api_football_schedule s WHERE s.fixture_id = :fixture_id LIMIT 1"),
                    {"fixture_id": fixture_id},
                ).scalar()
                if fixture_date is not None:
                    fixture_date_iso = fixture_date.isoformat()

            if not computed_from or not computed_to:
                has_scope = any([league, season, fixture_id])
                if not has_scope:
                    today = date.today()
                    computed_from = computed_from or (today - timedelta(days=14)).isoformat()
                    computed_to = computed_to or (today + timedelta(days=30)).isoformat()

            if not computed_from or not computed_to:
                params = {"league": league, "season": season, "fixture_id": fixture_id}
                defaults = conn.execute(
                    text(
                        """
                        SELECT
                            MIN(s.date::date) AS start_date,
                            MAX(CASE WHEN p.fixture_id IS NOT NULL THEN s.date::date END) AS last_prediction_date,
                            MAX(s.date::date) AS last_schedule_date
                        FROM football.api_football_schedule s
                        LEFT JOIN football.ml_predictions p
                               ON p.fixture_id = s.fixture_id
                        WHERE (:league IS NULL OR s.league_name = :league)
                          AND (:season IS NULL OR s.season::text = :season)
                          AND (:fixture_id IS NULL OR s.fixture_id = :fixture_id)
                        """
                    ),
                    params,
                ).mappings().first()

                start_date = defaults.get("start_date") if defaults else None
                last_prediction_date = defaults.get("last_prediction_date") if defaults else None
                last_schedule_date = defaults.get("last_schedule_date") if defaults else None

                if not computed_from:
                    if fixture_date_iso:
                        computed_from = fixture_date_iso
                    elif start_date is not None:
                        computed_from = start_date.isoformat()
                    else:
                        computed_from = "1900-01-01"

                if not computed_to:
                    fallback_date = (
                        fixture_date_iso
                        or (last_prediction_date.isoformat() if last_prediction_date else None)
                        or (last_schedule_date.isoformat() if last_schedule_date else None)
                        or (start_date.isoformat() if start_date else None)
                    )
                    computed_to = fallback_date or "2100-01-01"

        from_date = computed_from
        to_date = computed_to

        if from_date:
            response.headers["X-Range-From"] = from_date
        if to_date:
            response.headers["X-Range-To"] = to_date
        if fixture_id:
            response.headers["X-Fixture-Id"] = str(fixture_id)

        q = """
        WITH base AS (
          SELECT
            s.fixture_id,
            (s.date + interval '3 hours')::date AS date,
            (s.date + interval '3 hours') AS kickoff_at,
            s.league_name AS league,
            s.season::text AS season,
            s.venue_name AS venue,
            s.round AS round_label,
            NULLIF(REGEXP_REPLACE(COALESCE(s.round,''), '[^0-9]', '', 'g'), '')::int AS week,
            to_char(s.date + interval '3 hours', 'DD.MM HH24:MI') AS datetime,
            s.home_team, s.away_team,
            s.home_team_id, s.away_team_id,
            s.home_goals,
            s.away_goals,
            s.score_fulltime_home, s.score_fulltime_away,
            COALESCE(s.status,'') AS status,
            COALESCE(s.status_short, s.status, '') AS status_short,
            s.elapsed
          FROM football.api_football_schedule s
          WHERE s.date::date BETWEEN :from_date AND :to_date
            AND (:league IS NULL OR s.league_name = :league)
            AND (:season IS NULL OR s.season::text = :season)
        ),
        live_evt AS (
          SELECT DISTINCT ON (e.fixture_id)
            e.fixture_id,
            e.elapsed,
            e.extra
          FROM football.api_football_match_events e
          JOIN base b
            ON b.fixture_id = e.fixture_id
          WHERE e.elapsed IS NOT NULL
          ORDER BY e.fixture_id, e.elapsed DESC, COALESCE(e.extra, 0) DESC
        )
        SELECT
          b.fixture_id, b.date, b.kickoff_at, b.league, b.season,
          b.round_label,
          b.week,
          b.datetime,
          b.round_label AS round,
          b.home_team, b.away_team,
          b.home_team_id, b.away_team_id,
          b.status,
          b.status_short,
          COALESCE(b.elapsed, live_evt.elapsed) AS elapsed,
          live_evt.extra,
          venue,
          -- численные голы FT (для фронта)
          COALESCE(b.home_goals, b.score_fulltime_home) AS home_goals,
          COALESCE(b.away_goals, b.score_fulltime_away) AS away_goals,

          -- удобная строка и знак результата
          CASE 
            WHEN COALESCE(b.home_goals, b.score_fulltime_home) IS NULL OR COALESCE(b.away_goals, b.score_fulltime_away) IS NULL THEN NULL
            ELSE CONCAT(COALESCE(b.home_goals, b.score_fulltime_home)::text, '-', COALESCE(b.away_goals, b.score_fulltime_away)::text)
          END AS score,
          CASE 
            WHEN COALESCE(b.home_goals, b.score_fulltime_home) IS NULL OR COALESCE(b.away_goals, b.score_fulltime_away) IS NULL THEN NULL
            WHEN COALESCE(b.home_goals, b.score_fulltime_home) >  COALESCE(b.away_goals, b.score_fulltime_away) THEN 1
            WHEN COALESCE(b.home_goals, b.score_fulltime_home) <  COALESCE(b.away_goals, b.score_fulltime_away) THEN -1
            ELSE 0
          END AS result,

          -- вероятности / рынок / value
          p.p_home, p.p_draw, p.p_away,
          p.p_over25, p.p_under25,
          p.n_bookmakers,
          p.avg_odds_home, p.avg_odds_draw, p.avg_odds_away,
          p.avg_odds_over25, p.avg_odds_under25,
          p.ev_home, p.ev_draw, p.ev_away, p.ev_over, p.ev_under,
          p.edge_home, p.edge_draw, p.edge_away, p.edge_over, p.edge_under,
          p.kelly_home, p.kelly_draw, p.kelly_away, p.kelly_over, p.kelly_under,
          p.best_bet_type, p.best_bet_outcome, p.best_bet_odds, p.best_bet_ev, p.best_bet_edge,
          p.bet_rating, p.bet_reason,

          -- ===== HOME STATS (ms_h) =====
          ms_h.team_id            AS home_team_stats_id,
          ms_h.team_name          AS home_team_stats_name,
          ms_h.shots_on_goal      AS home_shots_on_goal,
          ms_h.shots_off_goal     AS home_shots_off_goal,
          ms_h.total_shots        AS home_total_shots,
          ms_h.blocked_shots      AS home_blocked_shots,
          ms_h.shots_insidebox    AS home_shots_insidebox,
          ms_h.shots_outsidebox   AS home_shots_outsidebox,
          ms_h.possession         AS home_possession,
          ms_h.passes             AS home_passes,
          ms_h.passes_accurate    AS home_passes_accurate,
          ms_h.passes_percentage  AS home_passes_percentage,
          ms_h.fouls              AS home_fouls,
          ms_h.corners            AS home_corners,
          ms_h.offsides           AS home_offsides,
          ms_h.yellow_cards       AS home_yellow_cards,
          ms_h.red_cards          AS home_red_cards,
          ms_h.saves              AS home_saves,
          ms_h.tackles            AS home_tackles,
          ms_h.attacks            AS home_attacks,
          ms_h.dangerous_attacks  AS home_dangerous_attacks,
          ms_h.expected_goals     AS home_expected_goals,
          ms_h.goals_prevented    AS home_goals_prevented,

          -- ===== AWAY STATS (ms_a) =====
          ms_a.team_id            AS away_team_stats_id,
          ms_a.team_name          AS away_team_stats_name,
          ms_a.shots_on_goal      AS away_shots_on_goal,
          ms_a.shots_off_goal     AS away_shots_off_goal,
          ms_a.total_shots        AS away_total_shots,
          ms_a.blocked_shots      AS away_blocked_shots,
          ms_a.shots_insidebox    AS away_shots_insidebox,
          ms_a.shots_outsidebox   AS away_shots_outsidebox,
          ms_a.possession         AS away_possession,
          ms_a.passes             AS away_passes,
          ms_a.passes_accurate    AS away_passes_accurate,
          ms_a.passes_percentage  AS away_passes_percentage,
          ms_a.fouls              AS away_fouls,
          ms_a.corners            AS away_corners,
          ms_a.offsides           AS away_offsides,
          ms_a.yellow_cards       AS away_yellow_cards,
          ms_a.red_cards          AS away_red_cards,
          ms_a.saves              AS away_saves,
          ms_a.tackles            AS away_tackles,
          ms_a.attacks            AS away_attacks,
          ms_a.dangerous_attacks  AS away_dangerous_attacks,
          ms_a.expected_goals     AS away_expected_goals,
          ms_a.goals_prevented    AS away_goals_prevented

        FROM base b
        LEFT JOIN football.api_football_match_stats ms_h
               ON ms_h.fixture_id = b.fixture_id AND ms_h.team_id = b.home_team_id
        LEFT JOIN football.api_football_match_stats ms_a
               ON ms_a.fixture_id = b.fixture_id AND ms_a.team_id = b.away_team_id
        LEFT JOIN live_evt
               ON live_evt.fixture_id = b.fixture_id
        LEFT JOIN football.ml_predictions p
               ON p.fixture_id = b.fixture_id
        WHERE (
            :fixture_id IS NOT NULL
            OR :include_upcoming
            OR UPPER(COALESCE(b.status_short, b.status, '')) IN ('1H','2H','HT','ET','BT','P','LIVE')
            OR UPPER(COALESCE(b.status, '')) IN ('FIRST HALF','SECOND HALF','HALF TIME','HALFTIME','BREAK TIME','EXTRA TIME','PENALTY','PENALTIES','LIVE')
            OR b.status IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
            OR (
                COALESCE(b.home_goals, b.score_fulltime_home) IS NOT NULL
                AND COALESCE(b.away_goals, b.score_fulltime_away) IS NOT NULL
                AND b.kickoff_at <= (CURRENT_TIMESTAMP - INTERVAL '2 hours')
            )
            OR p.fixture_id IS NOT NULL
        )
        ORDER BY b.date DESC, b.league, b.home_team
        LIMIT :limit;
        """

        q_slim = """
        WITH base AS (
          SELECT
            s.fixture_id,
            (s.date + interval '3 hours')::date AS date,
            (s.date + interval '3 hours') AS kickoff_at,
            s.league_name AS league,
            s.season::text AS season,
            s.venue_name AS venue,
            s.round AS round_label,
            NULLIF(REGEXP_REPLACE(COALESCE(s.round,''), '[^0-9]', '', 'g'), '')::int AS week,
            to_char(s.date + interval '3 hours', 'DD.MM HH24:MI') AS datetime,
            s.home_team, s.away_team,
            s.home_team_id, s.away_team_id,
            s.home_goals,
            s.away_goals,
            s.score_fulltime_home, s.score_fulltime_away,
            COALESCE(s.status,'') AS status,
            COALESCE(s.status_short, s.status, '') AS status_short,
            s.elapsed
          FROM football.api_football_schedule s
          WHERE s.date::date BETWEEN :from_date AND :to_date
            AND (:league IS NULL OR s.league_name = :league)
            AND (:season IS NULL OR s.season::text = :season)
        ),
        live_evt AS (
          SELECT DISTINCT ON (e.fixture_id)
            e.fixture_id,
            e.elapsed,
            e.extra
          FROM football.api_football_match_events e
          JOIN base b
            ON b.fixture_id = e.fixture_id
          WHERE e.elapsed IS NOT NULL
          ORDER BY e.fixture_id, e.elapsed DESC, COALESCE(e.extra, 0) DESC
        )
        SELECT
          b.fixture_id, b.date, b.kickoff_at, b.league, b.season,
          b.round_label,
          b.week,
          b.datetime,
          b.round_label AS round,
          b.home_team, b.away_team,
          b.home_team_id, b.away_team_id,
          b.status,
          b.status_short,
          COALESCE(b.elapsed, live_evt.elapsed) AS elapsed,
          live_evt.extra,
          venue,
          COALESCE(b.home_goals, b.score_fulltime_home) AS home_goals,
          COALESCE(b.away_goals, b.score_fulltime_away) AS away_goals,
          CASE 
            WHEN COALESCE(b.home_goals, b.score_fulltime_home) IS NULL OR COALESCE(b.away_goals, b.score_fulltime_away) IS NULL THEN NULL
            ELSE CONCAT(COALESCE(b.home_goals, b.score_fulltime_home)::text, '-', COALESCE(b.away_goals, b.score_fulltime_away)::text)
          END AS score,
          CASE 
            WHEN COALESCE(b.home_goals, b.score_fulltime_home) IS NULL OR COALESCE(b.away_goals, b.score_fulltime_away) IS NULL THEN NULL
            WHEN COALESCE(b.home_goals, b.score_fulltime_home) >  COALESCE(b.away_goals, b.score_fulltime_away) THEN 1
            WHEN COALESCE(b.home_goals, b.score_fulltime_home) <  COALESCE(b.away_goals, b.score_fulltime_away) THEN -1
            ELSE 0
          END AS result,
          p.p_home, p.p_draw, p.p_away,
          p.p_over25, p.p_under25,
          p.n_bookmakers,
          p.avg_odds_home, p.avg_odds_draw, p.avg_odds_away,
          p.avg_odds_over25, p.avg_odds_under25,
          p.ev_home, p.ev_draw, p.ev_away, p.ev_over, p.ev_under,
          p.edge_home, p.edge_draw, p.edge_away, p.edge_over, p.edge_under,
          p.kelly_home, p.kelly_draw, p.kelly_away, p.kelly_over, p.kelly_under,
          p.best_bet_type, p.best_bet_outcome, p.best_bet_odds, p.best_bet_ev, p.best_bet_edge,
          p.bet_rating, p.bet_reason
        FROM base b
        LEFT JOIN live_evt
               ON live_evt.fixture_id = b.fixture_id
        LEFT JOIN football.ml_predictions p
               ON p.fixture_id = b.fixture_id
        WHERE (
            :fixture_id IS NOT NULL
            OR :include_upcoming
            OR UPPER(COALESCE(b.status_short, b.status, '')) IN ('1H','2H','HT','ET','BT','P','LIVE')
            OR UPPER(COALESCE(b.status, '')) IN ('FIRST HALF','SECOND HALF','HALF TIME','HALFTIME','BREAK TIME','EXTRA TIME','PENALTY','PENALTIES','LIVE')
            OR b.status IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
            OR (
                COALESCE(b.home_goals, b.score_fulltime_home) IS NOT NULL
                AND COALESCE(b.away_goals, b.score_fulltime_away) IS NOT NULL
                AND b.kickoff_at <= (CURRENT_TIMESTAMP - INTERVAL '2 hours')
            )
            OR p.fixture_id IS NOT NULL
        )
        ORDER BY b.date DESC, b.league, b.home_team
        LIMIT :limit;
        """

        with engine.connect() as conn:
            df = pd.read_sql(
                text(q_slim if slim else q), conn,
                params={
                    "from_date": from_date,
                    "to_date": to_date,
                    "league": league,
                    "season": season,
                    "fixture_id": fixture_id,
                    "include_upcoming": include_upcoming,
                    "limit": limit,
                }
            )

        # Поля, которые ждёт фронт
        df["outcome_p1"] = df["p_home"]
        df["outcome_x"]  = df["p_draw"]
        df["outcome_p2"] = df["p_away"]
        df["total_o25"]  = df["p_over25"]
        df["total_u25"]  = df["p_under25"]

        # Метки
        df["outcome_label"] = df.apply(lambda r: _label_outcome(r.get("p_home"), r.get("p_draw"), r.get("p_away")), axis=1)
        df["total_label"]   = df.apply(lambda r: _label_total25(r.get("p_over25")), axis=1)

        # Сила/решение
        def to_strength(v):
            if pd.isna(v): return "none"
            s = str(v).strip().lower()
            return s if s in ("weak","medium","strong") else "none"

        df["signal_strength"] = df["bet_rating"].apply(to_strength)
        df["rec_decision"]    = df["signal_strength"].apply(lambda s: "BET" if s in ("weak","medium","strong") else "SKIP")

        # Лучший исход → подпись/вероятность/коэф/Келли
        def pick_label(row):
            t, o = row.get("best_bet_type"), row.get("best_bet_outcome")
            if t == "1X2":
                return {"home":"П1","draw":"Х","away":"П2"}.get(o)
            if t == "OU25":
                return {"over":"ТБ2.5","under":"ТМ2.5"}.get(o)
            return None

        def pick_prob(row):
            t, o = row.get("best_bet_type"), row.get("best_bet_outcome")
            if t == "1X2":
                return {"home":row.get("p_home"), "draw":row.get("p_draw"), "away":row.get("p_away")}.get(o)
            if t == "OU25":
                return {"over":row.get("p_over25"), "under":row.get("p_under25")}.get(o)
            return None

        def pick_odds(row):
            t, o = row.get("best_bet_type"), row.get("best_bet_outcome")
            if t == "1X2":
                return {"home":row.get("avg_odds_home"), "draw":row.get("avg_odds_draw"), "away":row.get("avg_odds_away")}.get(o)
            if t == "OU25":
                return {"over":row.get("avg_odds_over25"), "under":row.get("avg_odds_under25")}.get(o)
            return None

        def pick_kelly(row):
            t, o = row.get("best_bet_type"), row.get("best_bet_outcome")
            if t == "1X2":
                return {"home":row.get("kelly_home"), "draw":row.get("kelly_draw"), "away":row.get("kelly_away")}.get(o)
            if t == "OU25":
                return {"over":row.get("kelly_over"), "under":row.get("kelly_under")}.get(o)
            return None

        def signal_type(row):
            t, o = row.get("best_bet_type"), row.get("best_bet_outcome")
            if t == "1X2":
                probs = {"home":row.get("p_home"), "draw":row.get("p_draw"), "away":row.get("p_away")}
                argmax = max(probs, key=lambda k: probs[k] if probs[k] is not None else -1)
                return "align" if o == argmax else "contrarian"
            if t == "OU25":
                over = row.get("p_over25")
                if pd.isna(over): return None
                return "align" if ((o == "over" and over >= 0.5) or (o == "under" and over < 0.5)) else "contrarian"
            return None

        df["signal_market"] = df["best_bet_type"]
        df["signal_pick"]   = df.apply(pick_label,  axis=1)
        df["signal_p"]      = df.apply(pick_prob,   axis=1)
        df["signal_odds"]   = df.apply(pick_odds,   axis=1)
        df["signal_value"]  = df["best_bet_ev"]
        df["signal_edge"]   = df["best_bet_edge"]
        df["kelly_frac"]    = df.apply(pick_kelly,  axis=1)
        df["signal_type"]   = df.apply(signal_type, axis=1)

        # Пояснение
        def explain(row):
            if row.get("rec_decision") == "BET":
                if pd.notna(row.get("bet_reason")) and str(row.get("bet_reason")).strip():
                    return row.get("bet_reason")
                parts = []
                p = row.get("signal_p"); odds = row.get("signal_odds")
                ev = row.get("signal_value"); edge = row.get("signal_edge")
                books = row.get("n_bookmakers")
                if p is not None and odds is not None:
                    parts.append(f"p={p:.2f} | odds={odds:.2f}")
                if ev is not None:
                    parts.append(f"EV={ev:.3f}")
                if edge is not None:
                    parts.append(f"edge={(edge*100):.2f}%")
                if not pd.isna(books):
                    parts.append(f"books={int(books)}")
                return " | ".join(parts) if parts else "Value bet"

            # SKIP — причины
            if all(pd.isna(x) for x in [row.get("avg_odds_home"), row.get("avg_odds_draw"), row.get("avg_odds_away"),
                                        row.get("avg_odds_over25"), row.get("avg_odds_under25")]):
                return "No odds"
            if (row.get("n_bookmakers") or 0) < 2:
                return "Too few bookmakers"
            evs = [
                row.get("ev_home") or 0, row.get("ev_draw") or 0, row.get("ev_away") or 0,
                row.get("ev_over") or 0, row.get("ev_under") or 0
            ]
            if max(evs) <= 0:
                return "No positive EV"
            msg = row.get("bet_reason")
            return msg if (pd.notna(msg) and str(msg).strip()) else "нет сигнала"

        df["rec_reason"] = df.apply(explain, axis=1)

        # Optional enrichment from Understat:
        # - home_understat_xg / away_understat_xg
        # - understat_top_players_home / understat_top_players_away
        # - understat_shots (for pitch heatmap)
        # By default disabled for speed on large schedules.
        do_understat = bool(include_understat or fixture_id is not None)
        if do_understat and not df.empty:
            fixture_ids = [int(x) for x in df["fixture_id"].dropna().astype(int).unique().tolist()]
            if fixture_ids:
                league_map_sql = text(
                    """
                    WITH fx_raw AS (
                      SELECT
                        s.fixture_id,
                        s.date::date AS dt,
                        s.season,
                        s.league_name,
                        s.home_team,
                        s.away_team,
                        CASE s.league_name
                          WHEN 'Premier League' THEN 'EPL'
                          WHEN 'La Liga' THEN 'La_liga'
                          WHEN 'Bundesliga' THEN 'Bundesliga'
                          WHEN 'Serie A' THEN 'Serie_A'
                          WHEN 'Ligue 1' THEN 'Ligue_1'
                          ELSE NULL
                        END AS understat_code
                      FROM football.api_football_schedule s
                      WHERE s.fixture_id IN :fixture_ids
                    ),
                    fx AS (
                      SELECT
                        f.fixture_id,
                        f.dt,
                        f.season,
                        f.league_name,
                        f.home_team,
                        f.away_team,
                        f.understat_code,
                        COALESCE(
                          hm.canonical_team_name,
                          regexp_replace(lower(f.home_team), '[^a-z0-9]+', '', 'g')
                        ) AS home_team_key,
                        COALESCE(
                          am.canonical_team_name,
                          regexp_replace(lower(f.away_team), '[^a-z0-9]+', '', 'g')
                        ) AS away_team_key
                      FROM fx_raw f
                      LEFT JOIN football.team_cross_source_map hm
                        ON hm.season = f.season
                       AND hm.league_name = f.league_name
                       AND hm.api_team_name = f.home_team
                      LEFT JOIN football.team_cross_source_map am
                        ON am.season = f.season
                       AND am.league_name = f.league_name
                       AND am.api_team_name = f.away_team
                    ),
                    linked AS (
                      SELECT
                        fx.fixture_id,
                        lm.match_id,
                        lm.home_xg::double precision AS home_understat_xg,
                        lm.away_xg::double precision AS away_understat_xg
                      FROM fx
                      JOIN football.understat_league_matches lm
                        ON lm.league_code = fx.understat_code
                       AND lm.season = fx.season
                       AND lm.match_dt_utc::date = fx.dt
                      LEFT JOIN football.team_cross_source_map hm
                        ON hm.season = fx.season
                       AND hm.league_name = fx.league_name
                       AND hm.understat_team_name = lm.home_team_name
                      LEFT JOIN football.team_cross_source_map am
                        ON am.season = fx.season
                       AND am.league_name = fx.league_name
                       AND am.understat_team_name = lm.away_team_name
                      WHERE COALESCE(
                              hm.canonical_team_name,
                              regexp_replace(lower(lm.home_team_name), '[^a-z0-9]+', '', 'g')
                            ) = fx.home_team_key
                        AND COALESCE(
                              am.canonical_team_name,
                              regexp_replace(lower(lm.away_team_name), '[^a-z0-9]+', '', 'g')
                            ) = fx.away_team_key
                    ),
                    players AS (
                      SELECT
                        l.fixture_id,
                        p.side,
                        p.player_id,
                        p.player_name,
                        p.minutes,
                        p.goals,
                        p.assists,
                        p.shots,
                        p.key_passes,
                        p.xg::double precision AS xg,
                        p.xa::double precision AS xa
                      FROM linked l
                      JOIN football.understat_match_players p
                        ON p.match_id = l.match_id
                      WHERE COALESCE(p.minutes, 0) > 0
                    )
                    SELECT
                      l.fixture_id,
                      l.home_understat_xg,
                      l.away_understat_xg,
                      p.side,
                      p.player_id,
                      p.player_name,
                      p.minutes,
                      p.goals,
                      p.assists,
                      p.shots,
                      p.key_passes,
                      p.xg,
                      p.xa
                    FROM linked l
                    LEFT JOIN players p
                      ON p.fixture_id = l.fixture_id
                    ORDER BY l.fixture_id, p.side, p.xg DESC NULLS LAST, p.minutes DESC;
                    """
                ).bindparams(bindparam("fixture_ids", expanding=True))

                with engine.connect() as conn:
                    u_rows = conn.execute(league_map_sql, {"fixture_ids": fixture_ids}).mappings().all()

                shots_sql = text(
                    """
                    WITH fx_raw AS (
                      SELECT
                        s.fixture_id,
                        s.date::date AS dt,
                        s.season,
                        s.league_name,
                        s.home_team,
                        s.away_team,
                        CASE s.league_name
                          WHEN 'Premier League' THEN 'EPL'
                          WHEN 'La Liga' THEN 'La_liga'
                          WHEN 'Bundesliga' THEN 'Bundesliga'
                          WHEN 'Serie A' THEN 'Serie_A'
                          WHEN 'Ligue 1' THEN 'Ligue_1'
                          ELSE NULL
                        END AS understat_code
                      FROM football.api_football_schedule s
                      WHERE s.fixture_id IN :fixture_ids
                    ),
                    fx AS (
                      SELECT
                        f.fixture_id,
                        f.dt,
                        f.season,
                        f.league_name,
                        f.home_team,
                        f.away_team,
                        f.understat_code,
                        COALESCE(
                          hm.canonical_team_name,
                          regexp_replace(lower(f.home_team), '[^a-z0-9]+', '', 'g')
                        ) AS home_team_key,
                        COALESCE(
                          am.canonical_team_name,
                          regexp_replace(lower(f.away_team), '[^a-z0-9]+', '', 'g')
                        ) AS away_team_key
                      FROM fx_raw f
                      LEFT JOIN football.team_cross_source_map hm
                        ON hm.season = f.season
                       AND hm.league_name = f.league_name
                       AND hm.api_team_name = f.home_team
                      LEFT JOIN football.team_cross_source_map am
                        ON am.season = f.season
                       AND am.league_name = f.league_name
                       AND am.api_team_name = f.away_team
                    ),
                    linked AS (
                      SELECT
                        fx.fixture_id,
                        lm.match_id
                      FROM fx
                      JOIN football.understat_league_matches lm
                        ON lm.league_code = fx.understat_code
                       AND lm.season = fx.season
                       AND lm.match_dt_utc::date = fx.dt
                      LEFT JOIN football.team_cross_source_map hm
                        ON hm.season = fx.season
                       AND hm.league_name = fx.league_name
                       AND hm.understat_team_name = lm.home_team_name
                      LEFT JOIN football.team_cross_source_map am
                        ON am.season = fx.season
                       AND am.league_name = fx.league_name
                       AND am.understat_team_name = lm.away_team_name
                      WHERE COALESCE(
                              hm.canonical_team_name,
                              regexp_replace(lower(lm.home_team_name), '[^a-z0-9]+', '', 'g')
                            ) = fx.home_team_key
                        AND COALESCE(
                              am.canonical_team_name,
                              regexp_replace(lower(lm.away_team_name), '[^a-z0-9]+', '', 'g')
                            ) = fx.away_team_key
                    )
                    SELECT
                      l.fixture_id,
                      s.shot_id,
                      s.side,
                      s.minute,
                      s.player_id,
                      s.player_name,
                      s.result,
                      s.situation,
                      s.shot_type,
                      s.last_action,
                      s.x::double precision AS x,
                      s.y::double precision AS y,
                      s.xg::double precision AS xg,
                      s.score_home_after,
                      s.score_away_after
                    FROM linked l
                    JOIN football.understat_match_shots s
                      ON s.match_id = l.match_id
                    ORDER BY l.fixture_id, s.minute NULLS LAST, s.shot_id;
                    """
                ).bindparams(bindparam("fixture_ids", expanding=True))

                with engine.connect() as conn:
                    shot_rows = conn.execute(shots_sql, {"fixture_ids": fixture_ids}).mappings().all()

                by_fixture = {}
                for r in u_rows:
                    fid = int(r["fixture_id"])
                    obj = by_fixture.setdefault(
                        fid,
                        {
                            "home_understat_xg": r.get("home_understat_xg"),
                            "away_understat_xg": r.get("away_understat_xg"),
                            "understat_top_players_home": [],
                            "understat_top_players_away": [],
                            "understat_shots": [],
                        },
                    )
                    side = r.get("side")
                    if side not in ("h", "a"):
                        continue
                    player = {
                        "player_id": r.get("player_id"),
                        "player_name": r.get("player_name"),
                        "minutes": r.get("minutes"),
                        "goals": r.get("goals"),
                        "assists": r.get("assists"),
                        "shots": r.get("shots"),
                        "key_passes": r.get("key_passes"),
                        "xg": r.get("xg"),
                        "xa": r.get("xa"),
                    }
                    if side == "h":
                        if len(obj["understat_top_players_home"]) < 8:
                            obj["understat_top_players_home"].append(player)
                    else:
                        if len(obj["understat_top_players_away"]) < 8:
                            obj["understat_top_players_away"].append(player)

                for s in shot_rows:
                    fid = int(s["fixture_id"])
                    obj = by_fixture.setdefault(
                        fid,
                        {
                            "home_understat_xg": None,
                            "away_understat_xg": None,
                            "understat_top_players_home": [],
                            "understat_top_players_away": [],
                            "understat_shots": [],
                        },
                    )
                    if len(obj["understat_shots"]) >= 500:
                        continue
                    obj["understat_shots"].append(
                        {
                            "shot_id": s.get("shot_id"),
                            "side": s.get("side"),
                            "minute": s.get("minute"),
                            "player_id": s.get("player_id"),
                            "player_name": s.get("player_name"),
                            "result": s.get("result"),
                            "situation": s.get("situation"),
                            "shot_type": s.get("shot_type"),
                            "last_action": s.get("last_action"),
                            "x": s.get("x"),
                            "y": s.get("y"),
                            "xg": s.get("xg"),
                            "score_home_after": s.get("score_home_after"),
                            "score_away_after": s.get("score_away_after"),
                        }
                    )

                if by_fixture:
                    df["home_understat_xg"] = df["fixture_id"].map(
                        lambda x: by_fixture.get(int(x), {}).get("home_understat_xg")
                        if pd.notna(x) else None
                    )
                    df["away_understat_xg"] = df["fixture_id"].map(
                        lambda x: by_fixture.get(int(x), {}).get("away_understat_xg")
                        if pd.notna(x) else None
                    )
                    df["understat_top_players_home"] = df["fixture_id"].map(
                        lambda x: by_fixture.get(int(x), {}).get("understat_top_players_home", [])
                        if pd.notna(x) else []
                    )
                    df["understat_top_players_away"] = df["fixture_id"].map(
                        lambda x: by_fixture.get(int(x), {}).get("understat_top_players_away", [])
                        if pd.notna(x) else []
                    )
                    df["understat_shots"] = df["fixture_id"].map(
                        lambda x: by_fixture.get(int(x), {}).get("understat_shots", [])
                        if pd.notna(x) else []
                    )

        df["date"] = pd.to_datetime(df["date"], errors="coerce").dt.strftime("%Y-%m-%d")
        return _sanitize(df.to_dict(orient="records"))

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =========================
# API — upcoming (calendar) - ПЕРЕНЕСЕНО В no_used_method
# =========================


# В файле у тебя уже есть:
# router = APIRouter(prefix="/api")
# engine = create_engine(DB_URL)
# _sanitize(...)
