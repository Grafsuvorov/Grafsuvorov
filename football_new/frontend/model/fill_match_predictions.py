# fill_match_predictions.py
import argparse
import numpy as np
import pandas as pd
import joblib

from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy.dialects.postgresql import insert as pg_insert

from data.build_dataset import build_dataset
from data.loader import load_stats
from features.totals_features import build_totals_feature_list
from features.build_matrix import build_feature_matrix
from models.inference import predict_totals
from models.totals_auxiliary import apply_totals_auxiliary
from models.epl_totals_head import apply_epl_totals_head
from models.epl_totals_model import apply_epl_totals_model
from models.outcome_auxiliary import apply_outcome_auxiliary
from decision.totals_decision import decide_total_bet
from decision.outcomes_decision import decide_outcome_bet
from decision.outcome_policy import apply_outcome_league_policy
from decision.totals_policy import apply_total_league_policy, should_block_total_candidate
from config import (
    DB_URL,
    ALLOWED_BET_TYPES_BY_LEAGUE,
    MIN_EV_BY_TYPE,
    MIN_EV_BY_LEAGUE_BET,
    MIN_BET_ODDS,
    OUTCOME_MODEL_PATH,
    OUTCOME_AUX_MODEL_PATH,
    TOTALS_MODEL_PATH,
    TOTALS_AUX_MODEL_PATH,
    TOTALS_EPL_HEAD_MODEL_PATH,
    TOTALS_EPL_MODEL_PATH,
    ENABLE_TOTALS_EPL_HEAD,
    ENABLE_TOTALS_EPL_MODEL,
)


# =========================
# CONFIG
# =========================
MODEL_VERSION = "xgb_v6_league_policy"

DATE_FROM = "2026-01-29"
DATE_TO   = "2026-02-10"

print(DATE_TO)

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
        if t == "1X2":
            lid = int(league_id) if pd.notna(league_id) else -1
            tier = decide_outcome_bet(e, o, lid, name)
            if tier == "NO BET":
                return
        elif t == "TOTAL":
            if should_block_total_candidate(row, name):
                return
            if e < _ev_threshold(league_id, t):
                return
        elif e < _ev_threshold(league_id, t):
            return
        candidates.append((t, name, o, e))

    add("1X2", "Home",  row.p_home, row.avg_odds_home)
    add("1X2", "Draw",  row.p_draw, row.avg_odds_draw)
    add("1X2", "Away",  row.p_away, row.avg_odds_away)

    p_over = row.get("p_over25")
    p_under = row.get("p_under25")
    if p_over is not None and np.isfinite(p_over):
        add("TOTAL", "Over2.5",  p_over, row.get("avg_odds_over25"))
        add("TOTAL", "Under2.5", p_under, row.get("avg_odds_under25"))

    candidates = apply_total_league_policy(row, candidates)
    candidates = apply_outcome_league_policy(row, candidates)
    aux_bundle = row.get("_outcome_aux_bundle")
    if aux_bundle:
        candidates = apply_outcome_auxiliary(row.to_dict(), candidates, aux_bundle)

    if not candidates:
        return pd.Series(
            ["NONE", "NONE", np.nan, np.nan],
            index=["best_bet_type", "best_bet_outcome", "best_bet_odds", "best_bet_ev"],
        )

    best = max(candidates, key=lambda x: x[3])
    # Prefer 1X2 only in leagues/outcomes where the signal is historically stronger.
    eps = 0.01
    best_1x2 = max((c for c in candidates if c[0] == "1X2"), default=None, key=lambda x: x[3])
    if best_1x2 is not None and best[0] != "1X2":
        prefer_1x2 = False
        if league_id == 135 and best_1x2[1] == "Draw":
            prefer_1x2 = True
        elif league_id == 61 and best_1x2[1] == "Home":
            prefer_1x2 = True
        elif league_id == 78 and best_1x2[1] == "Away":
            prefer_1x2 = True
        if prefer_1x2 and (best[3] - best_1x2[3]) <= eps:
            best = best_1x2
    return pd.Series(best, index=[
        "best_bet_type",
        "best_bet_outcome",
        "best_bet_odds",
        "best_bet_ev"
    ])


def _compute_p_over_mkt(df: pd.DataFrame) -> pd.Series:
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")
    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    return imp_over / overround


def _merge_decision_context(df: pd.DataFrame, context: pd.DataFrame | None, columns: list[str]) -> pd.DataFrame:
    if context is None or context.empty:
        return df
    keep = ["fixture_id"] + [c for c in columns if c in context.columns]
    if len(keep) <= 1:
        return df
    ctx = context[keep].drop_duplicates("fixture_id")
    return df.merge(ctx, on="fixture_id", how="left")



# =========================
# MAIN
# =========================
def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--mode", choices=["totals", "outcomes", "both"], default="totals")
    p.add_argument("--date-from", dest="date_from", default=None)
    p.add_argument("--date-to", dest="date_to", default=None)
    return p.parse_args()


def main():
    args = parse_args()
    engine = create_engine(DB_URL)

    print("=== BUILD DATASET ===")
    df_all = build_dataset(return_all=True)
    df_all["date_utc"] = pd.to_datetime(df_all["date_utc"], errors="coerce")
    if pd.api.types.is_datetime64tz_dtype(df_all["date_utc"]):
        df_all["date_utc"] = df_all["date_utc"].dt.tz_localize(None)
    if "fixture_id" in df_all.columns:
        df_all["fixture_id"] = df_all["fixture_id"].astype(int)

    date_from = args.date_from or DATE_FROM
    date_to = args.date_to or DATE_TO

    mask = (
        (df_all.date_utc >= pd.to_datetime(date_from)) &
        (df_all.date_utc <= pd.to_datetime(date_to))
    )
    df_base = df_all.loc[mask].copy()
    if "fixture_id" in df_base.columns:
        df_base["fixture_id"] = df_base["fixture_id"].astype(int)
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
    if not df_odds.empty and "fixture_id" in df_odds.columns:
        df_odds["fixture_id"] = df_odds["fixture_id"].astype(int)

    df_base = df_base.merge(df_odds, on="fixture_id", how="left", suffixes=("", "_odds"))
    for col in [
        "avg_odds_home", "avg_odds_draw", "avg_odds_away",
        "avg_odds_over25", "avg_odds_under25",
    ]:
        odds_col = f"{col}_odds"
        if col in df_base.columns and odds_col in df_base.columns:
            df_base[col] = df_base[col].fillna(df_base[odds_col])
        elif col not in df_base.columns and odds_col in df_base.columns:
            df_base[col] = df_base[odds_col]
    for col in [
        "avg_odds_home", "avg_odds_draw", "avg_odds_away",
        "avg_odds_over25", "avg_odds_under25",
    ]:
        if col not in df_base.columns:
            df_base[col] = np.nan

    odds_missing = df_base[
        df_base[["avg_odds_home", "avg_odds_draw", "avg_odds_away",
                 "avg_odds_over25", "avg_odds_under25"]].isna().all(axis=1)
    ]
    if not odds_missing.empty:
        sample_ids = odds_missing["fixture_id"].head(10).tolist()
        print(f"[WARN] Missing odds for {len(odds_missing)} fixtures. Sample: {sample_ids}")

    df_pred = pd.DataFrame({"fixture_id": df_base.fixture_id.values})
    df_feat = None
    df_feat_out = None

    if args.mode in ("totals", "both"):
        # =========================
        # TOTALS FEATURES
        # =========================
        print("=== BUILD TOTALS FEATURES ===")
        match_stats = load_stats()
        if not match_stats.empty:
            match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()
        feats = build_totals_feature_list(df_all, match_stats, mode="inference")

        df_feat = build_feature_matrix(df_all, feats)
        from features.draw_diff import add_draw_diff_features
        df_feat = add_draw_diff_features(df_feat)
        df_feat = df_feat.loc[df_feat.fixture_id.isin(df_base.fixture_id)]

        # =========================
        # TOTALS PREDICT
        # =========================
        total_model = joblib.load(TOTALS_MODEL_PATH)
        try:
            total_aux_model = joblib.load(TOTALS_AUX_MODEL_PATH)
        except Exception:
            total_aux_model = None
        total_epl_head = None
        if ENABLE_TOTALS_EPL_HEAD:
            try:
                total_epl_head = joblib.load(TOTALS_EPL_HEAD_MODEL_PATH)
            except Exception:
                total_epl_head = None
        total_epl_model = None
        if ENABLE_TOTALS_EPL_MODEL:
            try:
                total_epl_model = joblib.load(TOTALS_EPL_MODEL_PATH)
            except Exception:
                total_epl_model = None
        if isinstance(total_model, dict) and "feature_cols" in total_model:
            print("INFER FEATURES:", len(total_model["feature_cols"]))
            print(sorted(total_model["feature_cols"]))

        p_over = predict_totals(df_feat, total_model)
        p_over = apply_totals_auxiliary(df_feat, p_over, total_aux_model)
        if total_epl_model is not None:
            p_over = apply_epl_totals_model(df_feat, p_over, total_epl_model)
        if total_epl_head is not None:
            p_over = apply_epl_totals_head(df_feat, p_over, total_epl_head)
        df_pred["p_over25"] = p_over
        df_pred["p_under25"] = 1 - p_over

    if args.mode in ("outcomes", "both"):
        # =========================
        # OUTCOMES FEATURES
        # =========================
        print("=== BUILD OUTCOMES FEATURES ===")
        from features.elo import build_elo_features
        from features.form_xg import build_form_xg_features
        from features.team_stats_form import build_team_stats_form
        from features.team_potential import build_team_potential_features
        from features.h2h import build_h2h_features
        from features.h2h_recent import build_h2h_recent_features
        from features.league import build_league_context_features
        from features.draw_diff import add_draw_diff_features
        from features.outcome_script import build_result_script_features, add_outcome_scenario_features
        from models.inference import predict_outcomes

        match_stats_out = load_stats()
        if not match_stats_out.empty:
            match_stats_out = match_stats_out[match_stats_out["fixture_id"].isin(df_all["fixture_id"])].copy()

        feats_out = [
            build_elo_features(df_all, mode="inference"),
            build_form_xg_features(df_all, match_stats_out, window=5),
            build_team_stats_form(df_all, match_stats_out, window=5),
            build_team_potential_features(df_all),
            build_h2h_features(df_all, mode="inference"),
            build_h2h_recent_features(df_all, window=5),
            build_league_context_features(df_all, window=60),
        ]
        df_feat_out = build_feature_matrix(df_all, feats_out)
        df_feat_out = add_draw_diff_features(df_feat_out)
        df_feat_out = df_feat_out.merge(build_result_script_features(df_all), on="fixture_id", how="left")
        df_feat_out = add_outcome_scenario_features(df_feat_out)
        df_feat_out = df_feat_out.loc[df_feat_out.fixture_id.isin(df_base.fixture_id)]

        outcome_model = joblib.load(OUTCOME_MODEL_PATH)
        try:
            outcome_aux_model = joblib.load(OUTCOME_AUX_MODEL_PATH)
        except Exception:
            outcome_aux_model = None
        P = predict_outcomes(df_feat_out, outcome_model)
        df_pred["p_home"] = P[:, 2]
        df_pred["p_draw"] = P[:, 1]
        df_pred["p_away"] = P[:, 0]
    else:
        outcome_aux_model = None

    # =========================
    # ASSEMBLE
    # =========================
    df = df_base.merge(df_pred, on="fixture_id", how="left")
    df = _merge_decision_context(
        df,
        df_feat if args.mode in ("totals", "both") else None,
        [
            "home_us_npxg_all_5",
            "away_us_npxg_all_5",
            "tp_match_openness",
            "tp_match_balance_abs",
            "home_xg_ema",
            "away_xg_ema",
        ],
    )
    df = _merge_decision_context(
        df,
        df_feat_out if args.mode in ("outcomes", "both") else None,
        [
            "tp_match_balance_abs",
            "tp_match_openness",
            "osc_draw_balance_elo_abs",
            "osc_draw_balance_control_abs",
            "osc_draw_balance_front_abs",
        ],
    )

    # Pre-compute market over/under probability for league adjustments
    df["p_market"] = _compute_p_over_mkt(df)

    if args.mode in ("outcomes", "both"):
        df["_outcome_aux_bundle"] = [outcome_aux_model] * len(df)
        best = df.apply(pick_best, axis=1)
        df = pd.concat([df, best], axis=1)
        if "_outcome_aux_bundle" in df.columns:
            df = df.drop(columns=["_outcome_aux_bundle"])

    if args.mode in ("outcomes", "both"):
        df["bet_reason"] = df.apply(
            lambda r: f"p={max(r.p_home,r.p_draw,r.p_away):.2f} | odds={r.best_bet_odds:.2f} | EV={r.best_bet_ev:.3f}"
            if pd.notna(r.best_bet_outcome) else None,
            axis=1
        )

        df["bet_rating"] = np.where(df.best_bet_ev >= 0.1, "Strong",
                            np.where(df.best_bet_ev >= 0.04, "Medium",
                            np.where(df.best_bet_ev >= 0.01, "Weak", None)))

    # totals decision layer (league-aware)
    if args.mode in ("totals", "both"):
        df["p_model"] = df["p_over25"]
        df["edge"] = df["p_model"] - df["p_market"]

        odds_side = np.where(
            df["p_model"] > 0.5,
            df["avg_odds_over25"],
            df["avg_odds_under25"],
        )
        df["odds"] = odds_side
        league_counts = (
            df_all[df_all["has_result"]]
            .groupby("league_id")["fixture_id"]
            .count()
            .to_dict()
        )
        df["sample_league_matches"] = df["league_id"].map(league_counts).fillna(0).astype(int)

        decisions = []
        for edge, odds, lid, p_model in zip(df["edge"], df["odds"], df["league_id"], df["p_model"]):
            decisions.append(decide_total_bet(edge, odds, lid, p_model))
        df["bet_decision"] = decisions
        if "best_bet_type" not in df.columns:
            df["best_bet_type"] = None
        df.loc[df["bet_decision"] == "NO BET", "best_bet_type"] = "NONE"
        df["stake"] = np.where(
            df["bet_decision"] == "A",
            1.0,
            np.where(df["bet_decision"] == "B", 0.4, 0.0),
        )
        df["edge_bin"] = pd.cut(
            df["edge"],
            bins=[0, 0.08, 0.10, 0.15, 1],
            labels=["0-8%", "8-10%", "10-15%", "15%+"]
        )

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
