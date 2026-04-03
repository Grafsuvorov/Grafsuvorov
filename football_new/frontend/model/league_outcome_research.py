import json

import pandas as pd

from outcome_scenario_research import _build_base_frame, _variant_map, _run_variant


LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}


def _league_roi(eval_df: pd.DataFrame, league_id: int):
    part = eval_df[eval_df["league_id"] == league_id].copy()
    bets = part[part["bet_decision"].isin(["A", "B"])].copy()
    stake = float(bets["stake"].sum())
    profit = float(bets["profit"].sum())
    return {
        "matches": int(len(part)),
        "bets": int(len(bets)),
        "coverage": float(len(bets) / len(part)) if len(part) else 0.0,
        "stake": stake,
        "profit": profit,
        "roi": (profit / stake) if stake > 0 else None,
    }


def main():
    df = _build_base_frame()
    current_season = int(df["season"].astype(int).max())
    train_df = df[df["season"].astype(int) < current_season].copy()
    test_df = df[df["season"].astype(int) == current_season].copy()
    variants = _variant_map(df)

    variant_results = {}
    for name, keep_cols in variants.items():
        variant_results[name] = _run_variant(train_df, test_df, keep_cols)

    by_league = {}
    for lid in sorted({int(x) for x in test_df["league_id"].dropna().unique()}):
        league_variants = []
        for name, payload in variant_results.items():
            roi = _league_roi(payload["eval_df"], lid)
            metrics = payload["metrics"]["by_league"].get(lid, {})
            league_variants.append(
                {
                    "variant": name,
                    "roi": roi["roi"],
                    "profit": roi["profit"],
                    "bets": roi["bets"],
                    "coverage": roi["coverage"],
                    "val_ll": metrics.get("val_ll"),
                    "val_acc": metrics.get("val_acc"),
                }
            )
        league_variants = sorted(
            league_variants,
            key=lambda x: (
                -999.0 if x["roi"] is None else float(x["roi"]),
                -999.0 if x["profit"] is None else float(x["profit"]),
                0 if x["bets"] is None else int(x["bets"]),
            ),
            reverse=True,
        )
        by_league[str(lid)] = {
            "league_name": LEAGUE_NAMES.get(lid, str(lid)),
            "best_variant": league_variants[0] if league_variants else None,
            "top_variants": league_variants[:4],
        }

    report = {
        "window": {
            "train_season": sorted({int(x) for x in train_df["season"].dropna().astype(int).unique()}),
            "eval_season": current_season,
            "train_rows": int(len(train_df)),
            "eval_rows": int(len(test_df)),
        },
        "by_league": by_league,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
