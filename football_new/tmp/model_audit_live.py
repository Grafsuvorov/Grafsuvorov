from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import accuracy_score, log_loss
from sqlalchemy import create_engine, text


LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}

OUTCOME_LABELS = np.array(["Away", "Draw", "Home"])


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--date-from", required=True)
    p.add_argument("--date-to", required=True)
    p.add_argument("--out", default="tmp/model_audit_live.json")
    return p.parse_args()


def _sanitize_prob(P: np.ndarray) -> np.ndarray:
    P = np.clip(P.astype(float), 1e-6, 1 - 1e-6)
    s = P.sum(axis=1, keepdims=True)
    return P / s


def _outcome_code(hg: int, ag: int) -> int:
    if hg > ag:
        return 2
    if hg == ag:
        return 1
    return 0


def _settle_profit(row: pd.Series) -> float | None:
    bet_type = row.get("best_bet_type")
    outcome = row.get("best_bet_outcome")
    odds = row.get("best_bet_odds")
    if not pd.notna(odds) or float(odds) <= 1.01:
        return None
    hg = int(row["home_goals"])
    ag = int(row["away_goals"])
    total = hg + ag

    won = False
    if bet_type == "1X2":
        won = (
            (outcome == "Home" and hg > ag)
            or (outcome == "Draw" and hg == ag)
            or (outcome == "Away" and ag > hg)
        )
    elif bet_type == "TOTAL":
        won = (
            (outcome == "Over2.5" and total > 2.5)
            or (outcome == "Under2.5" and total < 2.5)
        )
    else:
        return None
    return float(odds) - 1.0 if won else -1.0


def _to_records(df: pd.DataFrame, float_cols: list[str] | None = None) -> list[dict]:
    if float_cols:
        for col in float_cols:
            if col in df.columns:
                df[col] = df[col].astype(float).round(6)
    out: list[dict] = []
    for row in df.to_dict(orient="records"):
        clean = {}
        for k, v in row.items():
            if isinstance(v, (np.floating,)):
                clean[k] = None if np.isnan(v) else float(v)
            elif isinstance(v, (np.integer,)):
                clean[k] = int(v)
            else:
                clean[k] = v
        out.append(clean)
    return out


def _summarize_roi(df: pd.DataFrame, group_cols: list[str]) -> pd.DataFrame:
    if df.empty:
        return pd.DataFrame(columns=group_cols + ["bets", "profit", "roi", "hit_rate"])
    out = (
        df.groupby(group_cols, dropna=False)
        .agg(
            bets=("profit", "size"),
            profit=("profit", "sum"),
            wins=("won", "sum"),
        )
        .reset_index()
    )
    out["roi"] = out["profit"] / out["bets"]
    out["hit_rate"] = out["wins"] / out["bets"]
    return out.sort_values(["roi", "bets"], ascending=[True, False]).reset_index(drop=True)


def _calibration_bins(df: pd.DataFrame, prob_col: str, hit_col: str, bins: list[float], min_count: int = 8) -> pd.DataFrame:
    tmp = df[[prob_col, hit_col]].copy()
    tmp = tmp[np.isfinite(tmp[prob_col])].copy()
    if tmp.empty:
        return pd.DataFrame(columns=["bin", "n", "avg_p", "hit_rate", "bias"])
    tmp["bin"] = pd.cut(tmp[prob_col], bins=bins, include_lowest=True)
    out = (
        tmp.groupby("bin", observed=False)
        .agg(
            n=(hit_col, "size"),
            avg_p=(prob_col, "mean"),
            hit_rate=(hit_col, "mean"),
        )
        .reset_index()
    )
    out = out[out["n"] >= min_count].copy()
    out["bias"] = out["hit_rate"] - out["avg_p"]
    out["bin"] = out["bin"].astype(str)
    return out


def main():
    args = parse_args()
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("DATABASE_URL is required")

    engine = create_engine(db_url)
    q = text(
        """
        select
          p.fixture_id,
          s.date::date as match_date,
          s.league_id,
          s.league_name,
          s.home_goals,
          s.away_goals,
          p.p_home,
          p.p_draw,
          p.p_away,
          p.p_over25,
          p.best_bet_type,
          p.best_bet_outcome,
          p.best_bet_odds,
          p.best_bet_ev,
          p.bet_rating,
          p.model_version
        from football.ml_predictions p
        join football.api_football_schedule s on s.fixture_id = p.fixture_id
        where s.date::date between :date_from and :date_to
          and s.home_goals is not null
          and s.away_goals is not null
        order by s.date::date, p.fixture_id
        """
    )
    with engine.connect() as conn:
        df = pd.read_sql(q, conn, params={"date_from": args.date_from, "date_to": args.date_to})

    if df.empty:
        raise SystemExit("No settled matches in selected window")

    for col in ["p_home", "p_draw", "p_away", "p_over25", "best_bet_odds", "best_bet_ev"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df["league"] = df["league_id"].map(LEAGUE_NAMES).fillna(df["league_name"])

    P = _sanitize_prob(df[["p_away", "p_draw", "p_home"]].fillna(1 / 3).to_numpy())
    y_outcome = np.array([_outcome_code(h, a) for h, a in zip(df["home_goals"], df["away_goals"])], dtype=int)
    pred_outcome = P.argmax(axis=1)
    df["pred_outcome"] = OUTCOME_LABELS[pred_outcome]
    df["pred_outcome_p"] = P.max(axis=1)
    df["outcome_hit"] = (pred_outcome == y_outcome).astype(int)

    y_over = ((df["home_goals"] + df["away_goals"]) >= 3).astype(int).to_numpy()
    p_over = np.clip(df["p_over25"].fillna(0.5).to_numpy(), 1e-6, 1 - 1e-6)
    p_under = 1.0 - p_over
    df["pred_total_side"] = np.where(p_over >= 0.5, "Over2.5", "Under2.5")
    df["pred_total_p"] = np.maximum(p_over, p_under)
    df["total_hit"] = np.where(
        df["pred_total_side"].eq("Over2.5"),
        (y_over == 1).astype(int),
        (y_over == 0).astype(int),
    )

    overall = {
        "matches": int(len(df)),
        "outcome_accuracy": float(accuracy_score(y_outcome, pred_outcome)),
        "outcome_log_loss": float(log_loss(y_outcome, P, labels=[0, 1, 2])),
        "totals_accuracy": float(((p_over >= 0.5).astype(int) == y_over).mean()),
        "totals_log_loss": float(log_loss(y_over, p_over, labels=[0, 1])),
        "actual_outcome_rates": {
            "away": float((y_outcome == 0).mean()),
            "draw": float((y_outcome == 1).mean()),
            "home": float((y_outcome == 2).mean()),
        },
        "mean_predicted_outcome_probs": {
            "away": float(P[:, 0].mean()),
            "draw": float(P[:, 1].mean()),
            "home": float(P[:, 2].mean()),
        },
        "actual_over25_rate": float(y_over.mean()),
        "mean_predicted_over25": float(p_over.mean()),
    }

    league_rows = []
    for lid, part in df.groupby("league_id"):
        idx = part.index.to_numpy()
        y_l = y_outcome[idx]
        P_l = P[idx]
        y_over_l = y_over[idx]
        p_over_l = p_over[idx]
        pred_l = pred_outcome[idx]
        league_rows.append(
            {
                "league_id": int(lid),
                "league": LEAGUE_NAMES.get(int(lid), str(lid)),
                "matches": int(len(part)),
                "outcome_accuracy": float(accuracy_score(y_l, pred_l)),
                "outcome_log_loss": float(log_loss(y_l, P_l, labels=[0, 1, 2])),
                "totals_accuracy": float(((p_over_l >= 0.5).astype(int) == y_over_l).mean()),
                "totals_log_loss": float(log_loss(y_over_l, p_over_l, labels=[0, 1])),
                "pred_home": float(P_l[:, 2].mean()),
                "act_home": float((y_l == 2).mean()),
                "pred_draw": float(P_l[:, 1].mean()),
                "act_draw": float((y_l == 1).mean()),
                "pred_away": float(P_l[:, 0].mean()),
                "act_away": float((y_l == 0).mean()),
                "pred_over25": float(p_over_l.mean()),
                "act_over25": float(y_over_l.mean()),
            }
        )
    league_df = pd.DataFrame(league_rows).sort_values("league_id")
    league_df["home_bias"] = league_df["act_home"] - league_df["pred_home"]
    league_df["draw_bias"] = league_df["act_draw"] - league_df["pred_draw"]
    league_df["away_bias"] = league_df["act_away"] - league_df["pred_away"]
    league_df["over25_bias"] = league_df["act_over25"] - league_df["pred_over25"]

    picks = df[df["best_bet_type"].notna() & ~df["best_bet_type"].eq("NONE")].copy()
    picks["profit"] = picks.apply(_settle_profit, axis=1)
    picks = picks[picks["profit"].notna()].copy()
    picks["won"] = (picks["profit"] > 0).astype(int)

    roi_by_segment = _summarize_roi(picks, ["league", "best_bet_type", "best_bet_outcome", "bet_rating"])
    roi_by_type = _summarize_roi(picks, ["best_bet_type", "best_bet_outcome"])

    outcome_bins = _calibration_bins(
        df,
        prob_col="pred_outcome_p",
        hit_col="outcome_hit",
        bins=[0.0, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 1.01],
        min_count=12,
    )
    totals_bins = _calibration_bins(
        df,
        prob_col="pred_total_p",
        hit_col="total_hit",
        bins=[0.0, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 1.01],
        min_count=12,
    )

    toxic_segments = roi_by_segment[(roi_by_segment["bets"] >= 5) & (roi_by_segment["roi"] < 0)].copy()
    toxic_segments = toxic_segments.sort_values(["roi", "bets"], ascending=[True, False]).head(15)

    suspicious_leagues = league_df.copy()
    suspicious_leagues["max_abs_bias"] = suspicious_leagues[
        ["home_bias", "draw_bias", "away_bias", "over25_bias"]
    ].abs().max(axis=1)
    suspicious_leagues = suspicious_leagues.sort_values(
        ["outcome_log_loss", "totals_log_loss", "max_abs_bias"], ascending=[False, False, False]
    )

    report = {
        "window": {"date_from": args.date_from, "date_to": args.date_to},
        "overall": overall,
        "league_metrics": _to_records(
            league_df[
                [
                    "league_id",
                    "league",
                    "matches",
                    "outcome_accuracy",
                    "outcome_log_loss",
                    "totals_accuracy",
                    "totals_log_loss",
                    "pred_home",
                    "act_home",
                    "home_bias",
                    "pred_draw",
                    "act_draw",
                    "draw_bias",
                    "pred_away",
                    "act_away",
                    "away_bias",
                    "pred_over25",
                    "act_over25",
                    "over25_bias",
                ]
            ].copy()
        ),
        "worst_leagues": _to_records(
            suspicious_leagues[["league", "matches", "outcome_log_loss", "totals_log_loss", "max_abs_bias"]].head(5).copy()
        ),
        "roi_by_type": _to_records(roi_by_type.copy()),
        "toxic_segments": _to_records(toxic_segments.copy()),
        "outcome_confidence_bins": _to_records(outcome_bins.copy()),
        "totals_confidence_bins": _to_records(totals_bins.copy()),
    }

    out_path = Path(args.out)
    out_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
