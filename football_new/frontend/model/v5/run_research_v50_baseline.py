from __future__ import annotations

import json

from pathlib import Path

from frontend.model.v4.baselines import build_simple_poisson_features
from frontend.model.v4.evaluate import evaluate_by_league, evaluate_probs
from frontend.model.v4.features import build_result_form_features
from frontend.model.v4.splits import temporal_split_by_league

from .baselines import add_timed_market_features
from .data_snapshot import load_v5_snapshot
from .ml import fit_catboost_v5, predict_catboost_v5


OUTPUT_PATH = Path("tmp/outcome_v5_0_baseline.json")


def main() -> None:
    df = load_v5_snapshot()
    df = add_timed_market_features(df)
    if "date_utc" not in df.columns:
        df["date_utc"] = df["match_start_utc"]
    df = build_simple_poisson_features(df)
    df = build_result_form_features(df)

    tr, cal, val = temporal_split_by_league(
        df,
        ts_col="date_utc",
        league_col="league_id",
    )

    model = fit_catboost_v5(tr, cal)
    val_market = val[["p_away_current", "p_draw_current", "p_home_current"]].to_numpy()
    val_probs = predict_catboost_v5(model, val)

    report = {
        "dataset": {
            "rows": int(len(df)),
            "train": int(len(tr)),
            "cal": int(len(cal)),
            "val": int(len(val)),
        },
        "overall": {
            "market": evaluate_probs(val, val_market, "market"),
            "v5_0_catboost": evaluate_probs(val, val_probs, "v5_0_catboost"),
        },
        "by_league": {
            "market": evaluate_by_league(val, val_market, "market"),
            "v5_0_catboost": evaluate_by_league(val, val_probs, "v5_0_catboost"),
        },
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
