import argparse
from datetime import UTC, datetime, timedelta

import numpy as np
import pandas as pd
from sqlalchemy import MetaData, Table, create_engine, text
from sqlalchemy.dialects.postgresql import insert as pg_insert

from config import DB_URL
from prod_portfolio_v6 import build_prod_auto_offers, choose_primary_offer

SCHEMA = "football"
TABLE = "ml_predictions"
MODEL_VERSION = "portfolio_v6_predictor_totals"
LEAGUES = (39, 61, 78, 135, 140)
HISTORY_LOOKBACK_DAYS = 90
ROLLING_SEGMENT_DAYS = 45
MIN_SEGMENT_BETS = 5
MIN_SEGMENT_ROI = 0.0
MIN_SEGMENT_AVG_EV = 0.0
MAX_SEGMENT_CALIB_GAP = 0.08

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


def _safe_float(x):
    try:
        if x is None:
            return None
        v = float(x)
        if pd.isna(v):
            return None
        return v
    except Exception:
        return None


def _bucket_odds(odds):
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


def _bucket_outcome_edge(edge):
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


def _bucket_total_edge(edge):
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


def _bucket_draw_risk(p_draw):
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


def _bucket_total_prob(p_model):
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


def _bet_rating(ev):
    ev = _safe_float(ev)
    if ev is None:
        return None
    if ev >= 0.12:
        return "Strong"
    if ev >= 0.06:
        return "Medium"
    if ev >= 0.03:
        return "Weak"
    return None


def _default_dates():
    now = datetime.now(UTC).date()
    lookback = int(pd.get_option("display.max_rows") or 0)  # dummy to avoid lint complaints
    lookback = int(__import__("os").getenv("PORTFOLIO_LOOKBACK_DAYS", "3"))
    lookahead = int(__import__("os").getenv("PORTFOLIO_LOOKAHEAD_DAYS", "45"))
    return now - timedelta(days=lookback), now + timedelta(days=lookahead)


def parse_args():
    default_from, default_to = _default_dates()
    p = argparse.ArgumentParser()
    p.add_argument("--date-from", default=str(default_from))
    p.add_argument("--date-to", default=str(default_to))
    return p.parse_args()


def _fetch_window(engine, date_from: str, date_to: str) -> pd.DataFrame:
    q = text(
        """
        SELECT
          p.fixture_id,
          s.date::date AS match_date,
          s.league_id,
          s.league_name AS league,
          s.round,
          s.season::text AS season,
          s.home_team,
          s.away_team,
          p.p_home, p.p_draw, p.p_away,
          p.p_over25, p.p_under25,
          v.avg_odds_home, v.avg_odds_draw, v.avg_odds_away,
          v.avg_odds_over25, v.avg_odds_under25,
          v.n_bookmakers
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s ON s.fixture_id = p.fixture_id
        JOIN football.v_ml_epl_training v ON v.fixture_id = p.fixture_id
        WHERE s.date::date BETWEEN :date_from AND :date_to
          AND s.league_id = ANY(:league_ids)
        ORDER BY s.date::date, s.fixture_id
        """
    )
    with engine.connect() as conn:
        df = pd.read_sql(
            q,
            conn,
            params={"date_from": date_from, "date_to": date_to, "league_ids": list(LEAGUES)},
        )
    return df


def _settle_profit(market: str, outcome: str, odds: float, home_goals, away_goals):
    if pd.isna(home_goals) or pd.isna(away_goals):
        return np.nan
    hg = int(home_goals)
    ag = int(away_goals)
    odds = float(odds)
    if market == "TOTAL":
        tg = hg + ag
        if outcome == "Over2.5":
            return odds - 1.0 if tg > 2.5 else -1.0
        return odds - 1.0 if tg < 2.5 else -1.0
    won = (
        (outcome == "Home" and hg > ag)
        or (outcome == "Draw" and hg == ag)
        or (outcome == "Away" and ag > hg)
    )
    return odds - 1.0 if won else -1.0


def _passes_candidate_sanity(row: pd.Series, candidate: dict) -> bool:
    ev = _safe_float(candidate.get("ev"))
    edge = _safe_float(candidate.get("edge"))
    odds = _safe_float(candidate.get("odds"))
    if ev is None or ev <= 0:
        return False
    if odds is None or odds <= 1.01:
        return False

    market = candidate["market"]
    outcome = candidate["outcome"]
    league = str(row.get("league") or "")

    if market == "1X2":
        # Draws with negative/near-zero edge are too fragile in fresh windows.
        if outcome == "Draw" and edge is not None and edge <= 0:
            return False
        # Side bets should not be tiny disagreement signals.
        if outcome in {"Home", "Away"} and edge is not None and edge < 0.02:
            return False

    if market == "TOTAL":
        p_model = _safe_float(candidate.get("p"))
        if p_model is not None and p_model <= 0.52:
            return False
        if outcome == "Under2.5":
            over_odds = _safe_float(row.get("avg_odds_over25"))
            if league == "Premier League" and over_odds is not None and over_odds <= 1.70 and odds >= 2.00:
                return False

    return True


def _pick_best(row: pd.Series) -> dict:
    auto_candidates = build_prod_auto_offers(row)
    if not auto_candidates:
        return {
            "best_bet_type": "NONE",
            "best_bet_outcome": "NONE",
            "best_bet_odds": None,
            "best_bet_ev": None,
            "best_bet_edge": None,
            "bet_rating": None,
            "bet_reason": None,
            "bet_decision_notes": "portfolio_v6:none",
        }
    best = choose_primary_offer(auto_candidates)
    assert best is not None
    mode = "auto"
    return {
        "best_bet_type": "TOTAL" if best["market"] == "OU25" else best["market"],
        "best_bet_outcome": best["outcome"].capitalize() if best["market"] == "1X2" else ("Over2.5" if best["outcome"] == "over" else "Under2.5"),
        "best_bet_odds": float(best["odds"]),
        "best_bet_ev": float(best["ev"]),
        "best_bet_edge": float(best["edge"]),
        "bet_rating": _bet_rating(best["ev"]),
        "bet_reason": f"portfolio_v6 | {mode} | {best['market']} | {best['outcome']} | odds={best['odds']:.2f} | EV={best['ev']:.3f}",
        "bet_decision_notes": "portfolio_v6:auto:" + "|".join(str(x) for x in best.get("portfolio_segment", [])),
    }


def main():
    args = parse_args()
    engine = create_engine(DB_URL)
    date_from = pd.to_datetime(args.date_from)
    date_to = pd.to_datetime(args.date_to)
    hist_from = (date_from - pd.Timedelta(days=HISTORY_LOOKBACK_DAYS)).date().isoformat()
    df_all = _fetch_window(engine, hist_from, date_to.date().isoformat())
    if df_all.empty:
        print("No fixtures in window")
        return
    df_all["match_date"] = pd.to_datetime(df_all["match_date"], errors="coerce")

    target = df_all[(df_all["match_date"] >= date_from) & (df_all["match_date"] <= date_to)].copy()
    pick_rows = [{"fixture_id": int(r["fixture_id"]), **_pick_best(r)} for _, r in target.iterrows()]
    picks = pd.DataFrame(
        pick_rows,
        columns=[
            "fixture_id",
            "best_bet_type",
            "best_bet_outcome",
            "best_bet_odds",
            "best_bet_ev",
            "best_bet_edge",
            "bet_rating",
            "bet_reason",
            "bet_decision_notes",
        ],
    )

    meta = MetaData()
    with engine.begin() as conn:
        table = Table(TABLE, meta, schema=SCHEMA, autoload_with=conn)
        cols = set(table.c.keys())
        for _, row in picks.iterrows():
            data = {k: row[k] for k in row.index if k in cols and pd.notna(row[k])}
            stmt = pg_insert(table).values(**data)
            stmt = stmt.on_conflict_do_update(
                index_elements=[table.c.fixture_id],
                set_={k: stmt.excluded[k] for k in data if k != "fixture_id"},
            )
            conn.execute(stmt)

    picks["model_version"] = MODEL_VERSION
    print(picks["best_bet_type"].value_counts(dropna=False).to_dict() if "best_bet_type" in picks.columns else {})
    print(f"Updated fixtures: {len(picks)}")


if __name__ == "__main__":
    main()
