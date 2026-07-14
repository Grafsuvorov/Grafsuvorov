from __future__ import annotations

import json
from pathlib import Path


WALKFORWARD_PATH = Path("tmp/outcome_walkforward_stability_2025-08-01_2026-05-10.json")
OUT_PATH = Path("tmp/outcome_segment_policy_v1.json")


def is_valid_bucket(value):
    return value is not None and str(value).lower() != "nan"


def main():
    data = json.loads(WALKFORWARD_PATH.read_text())
    rows = data["top_stable_segments"] + data["worst_segments"]

    allowed = []
    blocked = []
    seen_allow = set()
    seen_block = set()

    for row in rows:
        key = (
            row["league"],
            row["outcome"],
            row["odds_bucket"],
            row["draw_risk_bin"],
        )
        if not is_valid_bucket(row["odds_bucket"]):
            continue

        if (
            row["windows"] >= 3
            and row["positive_window_share"] >= 0.75
            and row["avg_roi"] >= 0.15
            and row["total_bets"] >= 30
        ):
            if key not in seen_allow:
                allowed.append(
                    {
                        "league": row["league"],
                        "outcome": row["outcome"],
                        "odds_bucket": row["odds_bucket"],
                        "draw_risk_bin": row["draw_risk_bin"],
                        "windows": row["windows"],
                        "positive_window_share": row["positive_window_share"],
                        "avg_roi": row["avg_roi"],
                        "total_bets": row["total_bets"],
                    }
                )
                seen_allow.add(key)

        if (
            row["windows"] >= 3
            and row["positive_window_share"] <= 0.25
            and row["avg_roi"] <= -0.15
            and row["total_bets"] >= 30
        ):
            if key not in seen_block:
                blocked.append(
                    {
                        "league": row["league"],
                        "outcome": row["outcome"],
                        "odds_bucket": row["odds_bucket"],
                        "draw_risk_bin": row["draw_risk_bin"],
                        "windows": row["windows"],
                        "positive_window_share": row["positive_window_share"],
                        "avg_roi": row["avg_roi"],
                        "total_bets": row["total_bets"],
                    }
                )
                seen_block.add(key)

    report = {
        "allowed_segments_v1": allowed,
        "blocked_segments_v1": blocked,
    }
    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
