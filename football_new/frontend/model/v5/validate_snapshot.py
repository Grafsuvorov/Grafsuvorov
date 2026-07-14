from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

from .data_contract import V5_OPTIONAL_PHASE1_COLUMNS, V5_REQUIRED_COLUMNS
from .data_snapshot import load_v5_snapshot


OUTPUT_PATH = Path("tmp/v5_snapshot_validation.json")


def main() -> None:
    df = load_v5_snapshot()
    missing_required = [c for c in V5_REQUIRED_COLUMNS if c not in df.columns]

    coverage = {}
    for col in V5_REQUIRED_COLUMNS + V5_OPTIONAL_PHASE1_COLUMNS:
        if col not in df.columns:
            continue
        coverage[col] = round(float(df[col].notna().mean()), 6)

    time_violations = {}
    if {"odds_snapshot_time_utc", "prediction_time_utc"}.issubset(df.columns):
        viol = (
            pd.to_datetime(df["odds_snapshot_time_utc"], utc=True, errors="coerce")
            > pd.to_datetime(df["prediction_time_utc"], utc=True, errors="coerce")
        )
        time_violations["odds_after_prediction"] = int(viol.fillna(False).sum())

    market_timing = {}
    if "market_timing_source" in df.columns:
        counts = df["market_timing_source"].fillna("unknown").value_counts(dropna=False).to_dict()
        market_timing = {str(k): int(v) for k, v in counts.items()}
    if {
        "avg_odds_home_open",
        "avg_odds_draw_open",
        "avg_odds_away_open",
        "avg_odds_home_current",
        "avg_odds_draw_current",
        "avg_odds_away_current",
    }.issubset(df.columns):
        distinct_move = (
            (df["avg_odds_home_open"] != df["avg_odds_home_current"])
            | (df["avg_odds_draw_open"] != df["avg_odds_draw_current"])
            | (df["avg_odds_away_open"] != df["avg_odds_away_current"])
        )
        market_timing["rows_with_real_open_current_difference"] = int(distinct_move.fillna(False).sum())

    report = {
        "rows": int(len(df)),
        "missing_required": missing_required,
        "coverage": coverage,
        "time_violations": time_violations,
        "market_timing": market_timing,
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
