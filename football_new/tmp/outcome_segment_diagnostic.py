from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text


LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}

ODDS_BINS = [0.0, 1.55, 1.70, 2.00, 2.40, 3.20, 4.00, 10.0]
ODDS_LABELS = ["<1.55", "1.55-1.70", "1.70-2.00", "2.00-2.40", "2.40-3.20", "3.20-4.00", "4.00+"]
DRAW_RISK_BINS = [0.0, 0.22, 0.26, 0.30, 0.34, 1.0]
DRAW_RISK_LABELS = ["<=0.22", "0.22-0.26", "0.26-0.30", "0.30-0.34", "0.34+"]


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--date-from", required=True)
    p.add_argument("--date-to", required=True)
    p.add_argument("--out", default="tmp/outcome_segment_diagnostic.json")
    return p.parse_args()


def _implied_probs(df: pd.DataFrame) -> pd.DataFrame:
    home = pd.to_numeric(df["avg_odds_home"], errors="coerce")
    draw = pd.to_numeric(df["avg_odds_draw"], errors="coerce")
    away = pd.to_numeric(df["avg_odds_away"], errors="coerce")
    imp_home = 1.0 / home.replace(0, np.nan)
    imp_draw = 1.0 / draw.replace(0, np.nan)
    imp_away = 1.0 / away.replace(0, np.nan)
    overround = imp_home + imp_draw + imp_away
    df["p_home_mkt"] = imp_home / overround
    df["p_draw_mkt"] = imp_draw / overround
    df["p_away_mkt"] = imp_away / overround
    df["overround_1x2_calc"] = overround
    return df


def _row_side_metrics(row: pd.Series, side: str) -> dict | None:
    side_map = {
        "Home": ("p_home", "p_home_mkt", "avg_odds_home"),
        "Draw": ("p_draw", "p_draw_mkt", "avg_odds_draw"),
        "Away": ("p_away", "p_away_mkt", "avg_odds_away"),
    }
    p_col, pm_col, o_col = side_map[side]
    p_model = pd.to_numeric(pd.Series([row.get(p_col)]), errors="coerce").iloc[0]
    p_market = pd.to_numeric(pd.Series([row.get(pm_col)]), errors="coerce").iloc[0]
    odds = pd.to_numeric(pd.Series([row.get(o_col)]), errors="coerce").iloc[0]
    if not np.isfinite(p_model) or not np.isfinite(p_market) or not np.isfinite(odds) or odds <= 1.01:
        return None

    if side == "Home":
        won = int(row["home_goals"] > row["away_goals"])
    elif side == "Draw":
        won = int(row["home_goals"] == row["away_goals"])
    else:
        won = int(row["away_goals"] > row["home_goals"])

    market_entropy = 0.0
    for col in ["p_home_mkt", "p_draw_mkt", "p_away_mkt"]:
        p = row.get(col)
        if p is not None and np.isfinite(p) and p > 0:
            market_entropy -= float(p) * np.log(float(p))

    model_entropy = 0.0
    for col in ["p_home", "p_draw", "p_away"]:
        p = row.get(col)
        if p is not None and np.isfinite(p) and p > 0:
            model_entropy -= float(p) * np.log(float(p))

    ev = float(p_model * odds - 1.0)
    return {
        "fixture_id": int(row["fixture_id"]),
        "league_id": int(row["league_id"]),
        "league": LEAGUE_NAMES.get(int(row["league_id"]), str(int(row["league_id"]))),
        "outcome": side,
        "odds": float(odds),
        "avg_model_p": float(p_model),
        "avg_market_p": float(p_market),
        "draw_risk": float(row["p_draw"]),
        "edge": float(p_model - p_market),
        "ev": ev,
        "won": won,
        "profit": float(odds - 1.0) if won else -1.0,
        "market_entropy": float(market_entropy),
        "model_entropy": float(model_entropy),
        "same_favorite_flag": int(
            np.nanargmax([row["p_home"], row["p_draw"], row["p_away"]])
            == np.nanargmax([row["p_home_mkt"], row["p_draw_mkt"], row["p_away_mkt"]])
        ),
    }


def _summarize(df: pd.DataFrame, group_cols: list[str]) -> pd.DataFrame:
    out = (
        df.groupby(group_cols, dropna=False)
        .agg(
            bets=("fixture_id", "size"),
            wins=("won", "sum"),
            profit=("profit", "sum"),
            avg_odds=("odds", "mean"),
            avg_model_p=("avg_model_p", "mean"),
            actual_win_rate=("won", "mean"),
            avg_market_p=("avg_market_p", "mean"),
            avg_edge=("edge", "mean"),
            avg_ev=("ev", "mean"),
            avg_draw_risk=("draw_risk", "mean"),
        )
        .reset_index()
    )
    out["hit_rate"] = out["wins"] / out["bets"]
    out["roi"] = out["profit"] / out["bets"]
    return out.sort_values(["roi", "bets"], ascending=[True, False]).reset_index(drop=True)


def _records(df: pd.DataFrame) -> list[dict]:
    recs = []
    for row in df.to_dict(orient="records"):
        clean = {}
        for k, v in row.items():
            if isinstance(v, (np.floating,)):
                clean[k] = None if np.isnan(v) else float(v)
            elif isinstance(v, (np.integer,)):
                clean[k] = int(v)
            else:
                clean[k] = v
        recs.append(clean)
    return recs


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
          s.league_id,
          s.home_goals,
          s.away_goals,
          p.p_home,
          p.p_draw,
          p.p_away,
          v.avg_odds_home,
          v.avg_odds_draw,
          v.avg_odds_away
        from football.ml_predictions p
        join football.api_football_schedule s on s.fixture_id = p.fixture_id
        join football.v_ml_epl_training v on v.fixture_id = p.fixture_id
        where s.date::date between :date_from and :date_to
          and s.home_goals is not null
          and s.away_goals is not null
        order by s.date::date, p.fixture_id
        """
    )
    with engine.connect() as conn:
        base = pd.read_sql(q, conn, params={"date_from": args.date_from, "date_to": args.date_to})

    if base.empty:
        raise SystemExit("No settled matches in selected window")

    for col in ["p_home", "p_draw", "p_away", "avg_odds_home", "avg_odds_draw", "avg_odds_away"]:
        base[col] = pd.to_numeric(base[col], errors="coerce")
    base = _implied_probs(base)

    rows = []
    for _, row in base.iterrows():
        for side in ("Home", "Draw", "Away"):
            rec = _row_side_metrics(row, side)
            if rec is not None:
                rows.append(rec)
    df = pd.DataFrame(rows)
    df["odds_bucket"] = pd.cut(df["odds"], bins=ODDS_BINS, labels=ODDS_LABELS, include_lowest=True)
    df["draw_risk_bin"] = pd.cut(df["draw_risk"], bins=DRAW_RISK_BINS, labels=DRAW_RISK_LABELS, include_lowest=True)

    report = {
        "window": {"date_from": args.date_from, "date_to": args.date_to, "rows": int(len(df))},
        "overall_by_side": _records(_summarize(df, ["outcome"])),
        "league_outcome": _records(_summarize(df, ["league", "outcome"])),
        "league_outcome_odds": _records(_summarize(df, ["league", "outcome", "odds_bucket"])),
        "league_outcome_draw_risk": _records(_summarize(df, ["league", "outcome", "draw_risk_bin"])),
    }

    out_path = Path(args.out)
    out_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
