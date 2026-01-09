# fill_match_predictions.py
import numpy as np
import pandas as pd
import joblib

from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy.dialects.postgresql import insert as pg_insert

from data.build_dataset import build_dataset
from features.elo import build_elo_features
from features.form import build_form_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.streaks import build_streak_features
from features.momentum import build_momentum_features
from features.build_matrix import build_feature_matrix
from features.league import build_league_context_features
from models.inference import predict_outcomes, predict_totals
from config import (
    DB_URL,
    ALLOWED_BET_TYPES_BY_LEAGUE,
    MIN_EV_BY_TYPE,
    MIN_EV_BY_LEAGUE_BET,
    MIN_BET_ODDS,
)


# =========================
# CONFIG
# =========================
MODEL_VERSION = "xgb_v5_safe_prod_style"

DATE_FROM = "2025-11-01"
DATE_TO   = "2026-01-08"

SCHEMA = "football"
TABLE  = "ml_predictions"


# =========================
# HELPERS
# =========================
def ev(p, o):
    return p * o - 1 if np.isfinite(p) and np.isfinite(o) and o > 1 else np.nan

def fair(p):
    return 1 / p if np.isfinite(p) and p > 0 else np.nan

def edge(p, o):
    return ev(p, o)


def _bet_allowed(league_id, bet_type):
    allowed = ALLOWED_BET_TYPES_BY_LEAGUE.get(int(league_id) if pd.notna(league_id) else -1, set())
    return ("*" in allowed) or (bet_type in allowed)


def _ev_threshold(league_id, bet_type):
    lid = int(league_id) if pd.notna(league_id) else None
    if lid is not None and lid in MIN_EV_BY_LEAGUE_BET:
        return MIN_EV_BY_LEAGUE_BET[lid].get(bet_type, MIN_EV_BY_TYPE.get(bet_type, 0.0))
    return MIN_EV_BY_TYPE.get(bet_type, 0.0)


def pick_best(row):
    """Продовая логика выбора ставки"""
    candidates = []
    league_id = row.get("league_id")

    def add(t, name, p, o):
        e = ev(p, o)
        if (not np.isfinite(e)) or (o is None) or (o < MIN_BET_ODDS):
            return
        if not _bet_allowed(league_id, t):
            return
        if e < _ev_threshold(league_id, t):
            return
        candidates.append((t, name, o, e))

    add("1X2", "Home",  row.p_home, row.avg_odds_home)
    add("1X2", "Draw",  row.p_draw, row.avg_odds_draw)
    add("1X2", "Away",  row.p_away, row.avg_odds_away)

    if np.isfinite(row.p_over25):
        add("TOTAL", "Over2.5",  row.p_over25, row.avg_odds_over25)
        add("TOTAL", "Under2.5", row.p_under25, row.avg_odds_under25)

    if not candidates:
        return pd.Series([None, None, None, None], index=["best_bet_type", "best_bet_outcome", "best_bet_odds", "best_bet_ev"])

    best = max(candidates, key=lambda x: x[3])
    return pd.Series(best, index=[
        "best_bet_type",
        "best_bet_outcome",
        "best_bet_odds",
        "best_bet_ev"
    ])



# =========================
# MAIN
# =========================
def main():
    engine = create_engine(DB_URL)

    print("=== BUILD DATASET ===")
    df_all = build_dataset(return_all=True)
    df_all["date_utc"] = pd.to_datetime(df_all["date_utc"], utc=True)

    mask = (
        (df_all.date_utc >= pd.to_datetime(DATE_FROM, utc=True)) &
        (df_all.date_utc <= pd.to_datetime(DATE_TO,   utc=True))
    )
    df_base = df_all.loc[mask].copy()
    print("Rows in date window:", len(df_base))
    if df_base.empty:
        return

    # =========================
    # LOAD ODDS (PROD SOURCE)
    # =========================
    print("=== LOAD ODDS from football.v_ml_epl_training ===")
    odds_cols = [
        "fixture_id", "n_bookmakers",
        "avg_odds_home", "avg_odds_draw", "avg_odds_away",
        "avg_odds_over25", "avg_odds_under25",
        "p_home_norm", "p_draw_norm", "p_away_norm",
        "overround_1x2"
    ]

    df_odds = pd.read_sql(
        f"""
        SELECT {",".join(odds_cols)}
        FROM football.v_ml_epl_training
        WHERE fixture_id = ANY(%(ids)s)
        """,
        engine,
        params={"ids": df_base.fixture_id.tolist()}
    )

    df_base = df_base.merge(df_odds, on="fixture_id", how="left")

    # =========================
    # FEATURES
    # =========================
    print("=== BUILD FEATURES ===")
    feats = [
        build_elo_features(df_all, mode="inference"),
        build_form_features(df_all, mode="inference"),
        build_h2h_features(df_all, mode="inference"),
        build_h2h_recent_features(df_all, window=5),
        build_streak_features(df_all, window=6),
        build_momentum_features(df_all, short_span=3, long_span=8),
        build_league_context_features(df_all, window=60),
    ]

    df_feat = build_feature_matrix(df_all, feats)
    df_feat = df_feat.loc[df_feat.fixture_id.isin(df_base.fixture_id)]

    # =========================
    # PREDICT
    # =========================
    outcome_model = joblib.load("models/xgb_outcome_model.pkl")
    total_model   = joblib.load("models/xgb_over25_model.pkl")

    P = predict_outcomes(df_feat, outcome_model)
    p_over = predict_totals(df_feat, total_model)

    df_pred = pd.DataFrame({
        "fixture_id": df_feat.fixture_id.values,
        "p_home": P[:, 2],
        "p_draw": P[:, 1],
        "p_away": P[:, 0],
        "p_over25": p_over,
        "p_under25": 1 - p_over
    })

    # =========================
    # ASSEMBLE
    # =========================
    df = df_base.merge(df_pred, on="fixture_id", how="left")

    best = df.apply(pick_best, axis=1)
    df = pd.concat([df, best], axis=1)

    df["bet_reason"] = df.apply(
        lambda r: f"p={max(r.p_home,r.p_draw,r.p_away):.2f} | odds={r.best_bet_odds:.2f} | EV={r.best_bet_ev:.3f}"
        if pd.notna(r.best_bet_outcome) else None,
        axis=1
    )

    df["bet_rating"] = np.where(df.best_bet_ev >= 0.1, "Strong",
                        np.where(df.best_bet_ev >= 0.04, "Medium",
                        np.where(df.best_bet_ev >= 0.01, "Weak", None)))

    df["model_version"] = MODEL_VERSION
    df["alpha_blend"] = 0.0

    # =========================
    # UPSERT
    # =========================
    meta = MetaData()
    with engine.begin() as conn:
        table = Table(TABLE, meta, schema=SCHEMA, autoload_with=conn)
        cols = set(table.c.keys())

        for _, row in df.iterrows():
            data = {k: row[k] for k in cols if k in row and pd.notna(row[k])}

            stmt = pg_insert(table).values(**data)
            stmt = stmt.on_conflict_do_update(
                index_elements=[table.c.fixture_id],
                set_={k: stmt.excluded[k] for k in data if k != "fixture_id"}
            )
            conn.execute(stmt)

    print("DONE")


if __name__ == "__main__":
    main()
