import json
from typing import Dict, List

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from config import (
    DB_URL,
    TOTALS_UNDERSTAT_MIN_SEASON,
)
from data.build_dataset import build_dataset
from data.loader import load_stats
from decision.totals_decision import decide_total_bet
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.team_stats_form import build_team_stats_form
from train_outcomes import build_safe_feature_list
from train_totals import _train_totals_single, select_totals_feature_cols


UNDERSTAT_PREFIXES = ("home_us_", "away_us_", "us_")


def _compute_p_market(df: pd.DataFrame) -> pd.Series:
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")
    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    return imp_over / overround


def _bet_profit(row: pd.Series) -> float:
    if row["bet_decision"] not in {"A", "B"}:
        return 0.0
    goals = float(row["home_goals"]) + float(row["away_goals"])
    if row["bet_side"] == "OVER":
        return float(row["avg_odds_over25"]) - 1.0 if goals > 2.5 else -1.0
    return float(row["avg_odds_under25"]) - 1.0 if goals <= 2.5 else -1.0


def _build_feature_frame() -> pd.DataFrame:
    df_all = build_dataset(return_all=True)
    df_all = df_all[df_all["season"].astype(int) >= int(TOTALS_UNDERSTAT_MIN_SEASON)].copy()

    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()

    feats_list = [
        build_elo_features(df_all, mode="train"),
        build_form_xg_features(df_all, match_stats, window=5),
        build_team_stats_form(df_all, match_stats, window=5),
        build_h2h_features(df_all, mode="train"),
        build_h2h_recent_features(df_all, window=5),
        build_league_context_features(df_all, window=60),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats_list, target_df=None)
    df_all = add_draw_diff_features(df_all)
    return df_all[df_all["has_result"]].copy()


def _baseline_feature_cols(df: pd.DataFrame) -> List[str]:
    return [c for c in build_safe_feature_list(df) if not c.startswith(UNDERSTAT_PREFIXES)]


def _evaluate_predictions(df: pd.DataFrame, probs: np.ndarray) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)
    out["p_over25"] = pd.to_numeric(pd.Series(probs), errors="coerce")
    out["p_market"] = _compute_p_market(out)
    out["edge"] = out["p_over25"] - out["p_market"]
    out["bet_side"] = np.where(out["p_over25"] >= 0.5, "OVER", "UNDER")
    out["odds_side"] = np.where(out["bet_side"] == "OVER", out["avg_odds_over25"], out["avg_odds_under25"])
    out["bet_decision"] = [
        decide_total_bet(edge, odds, int(lid), p)
        for edge, odds, lid, p in zip(out["edge"], out["odds_side"], out["league_id"], out["p_over25"])
    ]
    out["stake"] = np.where(out["bet_decision"] == "A", 1.0, np.where(out["bet_decision"] == "B", 0.4, 0.0))
    out["profit_raw"] = out.apply(_bet_profit, axis=1)
    out["profit"] = out["profit_raw"] * out["stake"]
    return out


def _roi_summary(df: pd.DataFrame) -> Dict[str, float]:
    bets = df[df["bet_decision"].isin(["A", "B"])].copy()
    stake = float(bets["stake"].sum())
    profit = float(bets["profit"].sum())
    return {
        "matches": int(len(df)),
        "bets": int(len(bets)),
        "coverage": float(len(bets) / len(df)) if len(df) else 0.0,
        "stake": stake,
        "profit": profit,
        "roi": (profit / stake) if stake > 0 else None,
    }


def _load_fixture_names(engine, fixture_ids: List[int]) -> pd.DataFrame:
    if not fixture_ids:
        return pd.DataFrame(columns=["fixture_id", "match_date", "home_team", "away_team", "league_name"])
    return pd.read_sql(
        text(
            """
            SELECT fixture_id, date::timestamp AS match_date, home_team, away_team, league_name
            FROM football.api_football_schedule
            WHERE fixture_id = ANY(:ids)
            """
        ),
        engine,
        params={"ids": fixture_ids},
    )


def main():
    engine = create_engine(DB_URL)
    df = _build_feature_frame()

    baseline_rows = []
    enhanced_rows = []
    baseline_roi_by_league = {}
    enhanced_roi_by_league = {}

    for lid in sorted({int(x) for x in df["league_id"].dropna().unique()}):
        subset = df[df["league_id"] == lid].copy()
        base_res = _train_totals_single(subset, feature_cols_override=_baseline_feature_cols(subset), return_details=True)
        enh_res = _train_totals_single(subset, feature_cols_override=select_totals_feature_cols(subset), return_details=True)

        base_eval = _evaluate_predictions(base_res["details"]["val_df"], base_res["details"]["p_val_final"])
        enh_eval = _evaluate_predictions(enh_res["details"]["val_df"], enh_res["details"]["p_val_final"])

        baseline_rows.append(base_eval)
        enhanced_rows.append(enh_eval)
        baseline_roi_by_league[str(lid)] = _roi_summary(base_eval)
        enhanced_roi_by_league[str(lid)] = _roi_summary(enh_eval)

    baseline_eval = pd.concat(baseline_rows, ignore_index=True)
    enhanced_eval = pd.concat(enhanced_rows, ignore_index=True)

    names = _load_fixture_names(engine, baseline_eval["fixture_id"].astype(int).tolist())
    baseline_eval = baseline_eval.merge(names, on="fixture_id", how="left")
    enhanced_eval = enhanced_eval.merge(names, on="fixture_id", how="left", suffixes=("", "_dup"))

    compare = baseline_eval[
        [
            "fixture_id", "league_id", "home_goals", "away_goals",
            "p_over25", "bet_side", "bet_decision", "profit",
            "avg_odds_over25", "avg_odds_under25", "match_date", "home_team", "away_team", "league_name",
        ]
    ].rename(
        columns={
            "p_over25": "p_over25_before",
            "bet_side": "bet_side_before",
            "bet_decision": "bet_decision_before",
            "profit": "profit_before",
        }
    ).merge(
        enhanced_eval[["fixture_id", "p_over25", "bet_side", "bet_decision", "profit"]],
        on="fixture_id",
        how="inner",
    ).rename(
        columns={
            "p_over25": "p_over25_after",
            "bet_side": "bet_side_after",
            "bet_decision": "bet_decision_after",
            "profit": "profit_after",
        }
    )

    compare["delta_p_over25"] = compare["p_over25_after"] - compare["p_over25_before"]
    compare["profit_delta"] = compare["profit_after"] - compare["profit_before"]
    compare["changed"] = (
        (compare["bet_side_before"] != compare["bet_side_after"])
        | (compare["bet_decision_before"] != compare["bet_decision_after"])
    )

    improved = compare[compare["changed"] & (compare["profit_delta"] > 0)].sort_values(
        ["profit_delta", "delta_p_over25"], ascending=[False, False]
    ).head(8)
    worsened = compare[compare["changed"] & (compare["profit_delta"] < 0)].sort_values(
        ["profit_delta", "delta_p_over25"], ascending=[True, True]
    ).head(8)

    def _examples(df_part: pd.DataFrame):
        cols = [
            "fixture_id", "match_date", "league_name", "home_team", "away_team", "home_goals", "away_goals",
            "p_over25_before", "p_over25_after", "bet_side_before", "bet_side_after",
            "bet_decision_before", "bet_decision_after", "profit_before", "profit_after", "profit_delta",
        ]
        out = []
        for row in df_part[cols].to_dict(orient="records"):
            rec = dict(row)
            if rec.get("match_date") is not None and hasattr(rec["match_date"], "isoformat"):
                rec["match_date"] = rec["match_date"].isoformat()
            for k in ["p_over25_before", "p_over25_after", "profit_before", "profit_after", "profit_delta"]:
                if rec.get(k) is not None:
                    rec[k] = float(rec[k])
            out.append(rec)
        return out

    report = {
        "window": {
            "season_from": int(TOTALS_UNDERSTAT_MIN_SEASON),
            "matches_eval": int(len(compare)),
        },
        "before": {
            "overall_roi": _roi_summary(baseline_eval),
            "by_league": baseline_roi_by_league,
        },
        "after": {
            "overall_roi": _roi_summary(enhanced_eval),
            "by_league": enhanced_roi_by_league,
        },
        "delta": {
            "roi": (
                _roi_summary(enhanced_eval)["roi"] - _roi_summary(baseline_eval)["roi"]
                if _roi_summary(baseline_eval)["roi"] is not None and _roi_summary(enhanced_eval)["roi"] is not None
                else None
            ),
            "profit": _roi_summary(enhanced_eval)["profit"] - _roi_summary(baseline_eval)["profit"],
            "coverage": _roi_summary(enhanced_eval)["coverage"] - _roi_summary(baseline_eval)["coverage"],
        },
        "examples_improved": _examples(improved),
        "examples_worsened": _examples(worsened),
    }

    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
