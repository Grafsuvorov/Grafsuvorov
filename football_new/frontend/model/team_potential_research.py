import json
from typing import Dict, List

import numpy as np
import pandas as pd

from config import UNDERSTAT_MIN_SEASON
from data.build_dataset import build_dataset
from data.loader import load_stats
from decision.outcomes_decision import decide_outcome_bet
from decision.totals_decision import decide_total_bet
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.team_potential import build_team_potential_features
from features.team_stats_form import build_team_stats_form
from models.inference import predict_outcomes, predict_totals
from train_outcomes import _train_outcomes_single
from train_totals import _train_totals_single


TP_PREFIX = "tp_"


def _weighted_metric(metrics_by_league: Dict[int, Dict[str, float]], metric_name: str):
    num = 0.0
    den = 0
    for metrics in metrics_by_league.values():
        n = int(metrics.get("val_n", 0))
        val = metrics.get(metric_name)
        if n <= 0 or val is None:
            continue
        num += float(val) * n
        den += n
    return (num / den) if den else None


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


def _by_league_summary(df: pd.DataFrame) -> Dict[str, Dict[str, float]]:
    out = {}
    for lid in sorted({int(x) for x in df["league_id"].dropna().unique()}):
        out[str(lid)] = _roi_summary(df[df["league_id"] == lid].copy())
    return out


def _serialize_examples(df: pd.DataFrame, cols: List[str], n: int = 5) -> List[Dict[str, object]]:
    rows = []
    for rec in df.head(n)[cols].to_dict(orient="records"):
        row = dict(rec)
        if row.get("date_utc") is not None and hasattr(row["date_utc"], "isoformat"):
            row["date_utc"] = row["date_utc"].isoformat()
        for key, val in list(row.items()):
            if isinstance(val, (np.floating, float)):
                row[key] = float(val)
            elif isinstance(val, (np.integer, int)):
                row[key] = int(val)
        rows.append(row)
    return rows


def _compute_p_market(df: pd.DataFrame) -> pd.Series:
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")
    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    return imp_over / overround


def _bet_profit_total(row: pd.Series) -> float:
    goals = float(row["home_goals"]) + float(row["away_goals"])
    if row["bet_side"] == "OVER":
        return float(row["avg_odds_over25"]) - 1.0 if goals > 2.5 else -1.0
    return float(row["avg_odds_under25"]) - 1.0 if goals <= 2.5 else -1.0


def _bet_profit_outcome(row: pd.Series) -> float:
    if row["bet_side"] == "Home":
        won = row["home_goals"] > row["away_goals"]
    elif row["bet_side"] == "Draw":
        won = row["home_goals"] == row["away_goals"]
    else:
        won = row["home_goals"] < row["away_goals"]
    return float(row["odds_side"]) - 1.0 if won else -1.0


def _build_feature_frame() -> pd.DataFrame:
    df_all = build_dataset(return_all=True)
    df_all = df_all[df_all["season"].astype(int) >= int(UNDERSTAT_MIN_SEASON)].copy()

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
        build_team_potential_features(df_all),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats_list, target_df=None)
    df_all = add_draw_diff_features(df_all)
    return df_all[df_all["has_result"]].copy()


def _filter_variant(df: pd.DataFrame, keep_cols: List[str]) -> pd.DataFrame:
    tp_cols = [c for c in df.columns if c.startswith(TP_PREFIX)]
    drop_cols = [c for c in tp_cols if c not in set(keep_cols)]
    return df.drop(columns=drop_cols, errors="ignore").copy()


def _variant_map(df: pd.DataFrame) -> Dict[str, List[str]]:
    tp_cols = [c for c in df.columns if c.startswith(TP_PREFIX)]
    attack_cols = [c for c in tp_cols if "attack_" in c]
    defense_cols = [c for c in tp_cols if "defense_" in c]
    matchup_cols = [c for c in tp_cols if "matchup_" in c]
    balance_cols = [c for c in tp_cols if "balance" in c or "diff" in c or "trend" in c]
    match_state_cols = [c for c in tp_cols if "match_" in c]

    return {
        "baseline": [],
        "potential_attack_defense": sorted(set(attack_cols + defense_cols)),
        "potential_matchup": sorted(set(matchup_cols + balance_cols)),
        "potential_signal_core": sorted(
            set(attack_cols + defense_cols + [c for c in matchup_cols if "attack" in c or "quality" in c] + balance_cols)
        ),
        "potential_full": sorted(set(tp_cols + match_state_cols)),
    }


def _evaluate_totals_predictions(df: pd.DataFrame, probs: np.ndarray) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)
    out["p_over25"] = pd.to_numeric(pd.Series(probs), errors="coerce")
    if "home_team" not in out.columns:
        out["home_team"] = out["home_team_id"].astype(str)
    if "away_team" not in out.columns:
        out["away_team"] = out["away_team_id"].astype(str)
    out["p_market"] = _compute_p_market(out)
    out["edge"] = out["p_over25"] - out["p_market"]
    out["bet_side"] = np.where(out["p_over25"] >= 0.5, "OVER", "UNDER")
    out["odds_side"] = np.where(out["bet_side"] == "OVER", out["avg_odds_over25"], out["avg_odds_under25"])
    out["bet_decision"] = [
        decide_total_bet(edge, odds, int(lid), p)
        for edge, odds, lid, p in zip(out["edge"], out["odds_side"], out["league_id"], out["p_over25"])
    ]
    out["stake"] = np.where(out["bet_decision"] == "A", 1.0, np.where(out["bet_decision"] == "B", 0.4, 0.0))
    bets = out["bet_decision"].isin(["A", "B"])
    out["profit_raw"] = 0.0
    out.loc[bets, "profit_raw"] = out.loc[bets].apply(_bet_profit_total, axis=1)
    out["profit"] = out["profit_raw"] * out["stake"]
    return out


def _evaluate_outcome_predictions(df: pd.DataFrame, probs: np.ndarray) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)
    out["p_away"] = probs[:, 0]
    out["p_draw"] = probs[:, 1]
    out["p_home"] = probs[:, 2]

    options = []
    for side, p_col, odds_col in [
        ("Home", "p_home", "avg_odds_home"),
        ("Draw", "p_draw", "avg_odds_draw"),
        ("Away", "p_away", "avg_odds_away"),
    ]:
        tmp = out[
            [
                "fixture_id",
                "date_utc",
                "league_id",
                "season",
                "home_team_id",
                "away_team_id",
                "home_goals",
                "away_goals",
                p_col,
                odds_col,
            ]
        ].copy()
        tmp.columns = [
            "fixture_id",
            "date_utc",
            "league_id",
            "season",
            "home_team",
            "away_team",
            "home_goals",
            "away_goals",
            "p_side",
            "odds_side",
        ]
        tmp["bet_side"] = side
        tmp["ev"] = tmp["p_side"] * tmp["odds_side"] - 1.0
        options.append(tmp)

    opts = pd.concat(options, ignore_index=True).dropna(subset=["p_side", "odds_side", "ev"])
    best_idx = opts.groupby("fixture_id")["ev"].idxmax()
    picks = opts.loc[best_idx].copy().reset_index(drop=True)
    picks["bet_decision"] = [
        decide_outcome_bet(ev, odds, int(lid), side)
        for ev, odds, lid, side in zip(picks["ev"], picks["odds_side"], picks["league_id"], picks["bet_side"])
    ]
    picks["stake"] = np.where(picks["bet_decision"] == "A", 1.0, np.where(picks["bet_decision"] == "B", 0.4, 0.0))
    bets = picks["bet_decision"].isin(["A", "B"])
    picks["profit_raw"] = 0.0
    picks.loc[bets, "profit_raw"] = picks.loc[bets].apply(_bet_profit_outcome, axis=1)
    picks["profit"] = picks["profit_raw"] * picks["stake"]
    return picks


def _run_totals_variant(train_df: pd.DataFrame, test_df: pd.DataFrame, keep_cols: List[str]) -> Dict[str, object]:
    df_variant = _filter_variant(pd.concat([train_df, test_df], ignore_index=True), keep_cols)
    train_part = df_variant[df_variant["season"].astype(int) < int(test_df["season"].max())].copy()
    test_part = df_variant[df_variant["season"].astype(int) == int(test_df["season"].max())].copy()
    bundles = {}
    metrics_by_league = {}
    for lid in sorted({int(x) for x in train_part["league_id"].dropna().unique()}):
        local_train = train_part[train_part["league_id"] == lid].copy()
        if local_train.empty:
            continue
        res = _train_totals_single(local_train, return_details=False)
        bundles[lid] = res["bundle"]
        metrics_by_league[lid] = res["metrics"]
    probs = predict_totals(test_part, bundles)
    eval_df = _evaluate_totals_predictions(test_part, probs)
    return {
        "metrics": {
            "val_ll": _weighted_metric(metrics_by_league, "val_ll"),
            "val_acc": _weighted_metric(metrics_by_league, "val_acc"),
            "val_brier": _weighted_metric(metrics_by_league, "val_brier"),
            "val_n": int(sum(int(v.get("val_n", 0)) for v in metrics_by_league.values())),
            "by_league": metrics_by_league,
        },
        "eval_df": eval_df,
        "roi": _roi_summary(eval_df),
        "by_league": _by_league_summary(eval_df),
    }


def _run_outcomes_variant(train_df: pd.DataFrame, test_df: pd.DataFrame, keep_cols: List[str]) -> Dict[str, object]:
    df_variant = _filter_variant(pd.concat([train_df, test_df], ignore_index=True), keep_cols)
    train_part = df_variant[df_variant["season"].astype(int) < int(test_df["season"].max())].copy()
    test_part = df_variant[df_variant["season"].astype(int) == int(test_df["season"].max())].copy()
    bundles = {}
    metrics_by_league = {}
    for lid in sorted({int(x) for x in train_part["league_id"].dropna().unique()}):
        local_train = train_part[train_part["league_id"] == lid].copy()
        if local_train.empty:
            continue
        res = _train_outcomes_single(local_train, league_id=lid)
        bundles[lid] = res["bundle"]
        metrics_by_league[lid] = res["metrics"]
    probs = predict_outcomes(test_part, bundles)
    eval_df = _evaluate_outcome_predictions(test_part, probs)
    return {
        "metrics": {
            "val_ll": _weighted_metric(metrics_by_league, "val_ll"),
            "val_acc": _weighted_metric(metrics_by_league, "val_acc"),
            "val_n": int(sum(int(v.get("val_n", 0)) for v in metrics_by_league.values())),
            "by_league": metrics_by_league,
        },
        "eval_df": eval_df,
        "roi": _roi_summary(eval_df),
        "by_league": _by_league_summary(eval_df),
    }


def _pick_best_variant(results: Dict[str, Dict[str, object]]) -> str:
    best_name = None
    best_score = None
    for name, payload in results.items():
        roi = payload["roi"]["roi"]
        ll = payload["metrics"]["val_ll"]
        coverage = payload["roi"]["coverage"]
        score = (
            -999.0 if roi is None else float(roi),
            -float(ll) if ll is not None else -999.0,
            float(coverage),
        )
        if best_score is None or score > best_score:
            best_name = name
            best_score = score
    return best_name


def _compare_examples(before_df: pd.DataFrame, after_df: pd.DataFrame) -> Dict[str, List[Dict[str, object]]]:
    before_df = before_df.copy()
    after_df = after_df.copy()
    if "home_team" not in before_df.columns and "home_team_id" in before_df.columns:
        before_df["home_team"] = before_df["home_team_id"].astype(str)
    if "away_team" not in before_df.columns and "away_team_id" in before_df.columns:
        before_df["away_team"] = before_df["away_team_id"].astype(str)
    if "home_team" not in after_df.columns and "home_team_id" in after_df.columns:
        after_df["home_team"] = after_df["home_team_id"].astype(str)
    if "away_team" not in after_df.columns and "away_team_id" in after_df.columns:
        after_df["away_team"] = after_df["away_team_id"].astype(str)

    merged = before_df[
        ["fixture_id", "date_utc", "home_team", "away_team", "home_goals", "away_goals", "bet_side", "bet_decision", "profit"]
    ].rename(
        columns={"bet_side": "bet_side_before", "bet_decision": "bet_decision_before", "profit": "profit_before"}
    ).merge(
        after_df[["fixture_id", "bet_side", "bet_decision", "profit"]].rename(
            columns={"bet_side": "bet_side_after", "bet_decision": "bet_decision_after", "profit": "profit_after"}
        ),
        on="fixture_id",
        how="inner",
    )
    merged["changed"] = (
        (merged["bet_side_before"] != merged["bet_side_after"])
        | (merged["bet_decision_before"] != merged["bet_decision_after"])
    )
    merged["profit_delta"] = merged["profit_after"] - merged["profit_before"]
    changed = merged[merged["changed"]].copy()
    cols = [
        "fixture_id",
        "date_utc",
        "home_team",
        "away_team",
        "home_goals",
        "away_goals",
        "bet_side_before",
        "bet_decision_before",
        "bet_side_after",
        "bet_decision_after",
        "profit_before",
        "profit_after",
        "profit_delta",
    ]
    return {
        "improved": _serialize_examples(changed.sort_values("profit_delta", ascending=False), cols),
        "worsened": _serialize_examples(changed.sort_values("profit_delta", ascending=True), cols),
    }


def main():
    df = _build_feature_frame()
    current_season = int(df["season"].astype(int).max())
    train_df = df[df["season"].astype(int) < current_season].copy()
    test_df = df[df["season"].astype(int) == current_season].copy()
    variants = _variant_map(df)

    totals_results = {}
    outcomes_results = {}
    for name, keep_cols in variants.items():
        totals_results[name] = _run_totals_variant(train_df, test_df, keep_cols)
        outcomes_results[name] = _run_outcomes_variant(train_df, test_df, keep_cols)

    best_totals = _pick_best_variant(totals_results)
    best_outcomes = _pick_best_variant(outcomes_results)

    report = {
        "window": {
            "train_seasons": sorted({int(x) for x in train_df["season"].dropna().astype(int).unique()}),
            "eval_season": current_season,
            "train_rows": int(len(train_df)),
            "eval_rows": int(len(test_df)),
        },
        "best": {
            "totals": {
                "variant": best_totals,
                "metrics": totals_results[best_totals]["metrics"],
                "roi": totals_results[best_totals]["roi"],
                "by_league": totals_results[best_totals]["by_league"],
                "examples": _compare_examples(totals_results["baseline"]["eval_df"], totals_results[best_totals]["eval_df"]),
            },
            "outcomes": {
                "variant": best_outcomes,
                "metrics": outcomes_results[best_outcomes]["metrics"],
                "roi": outcomes_results[best_outcomes]["roi"],
                "by_league": outcomes_results[best_outcomes]["by_league"],
                "examples": _compare_examples(outcomes_results["baseline"]["eval_df"], outcomes_results[best_outcomes]["eval_df"]),
            },
        },
        "variants": {
            name: {
                "totals": {
                    "metrics": totals_results[name]["metrics"],
                    "roi": totals_results[name]["roi"],
                    "by_league": totals_results[name]["by_league"],
                },
                "outcomes": {
                    "metrics": outcomes_results[name]["metrics"],
                    "roi": outcomes_results[name]["roi"],
                    "by_league": outcomes_results[name]["by_league"],
                },
            }
            for name in variants.keys()
        },
    }

    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
