import json
from pathlib import Path

import numpy as np
import pandas as pd


OUT_PATH = Path("tmp/outcome_v3_value_layer_research.json")
CANDIDATE_PATH = Path("tmp/outcome_v3_candidate_dataset.csv")
SEGMENT_PATH = Path("tmp/outcome_v3_segment_diagnostic.json")


def _load_candidates() -> pd.DataFrame:
    df = pd.read_csv(CANDIDATE_PATH)
    df["date_utc"] = pd.to_datetime(df["date_utc"], utc=True, errors="coerce")
    return df


def _load_watch_segments() -> set[tuple[str, str, str, str, str]]:
    obj = json.loads(SEGMENT_PATH.read_text())
    watch = obj.get("top_watch", [])
    return {
        (
            str(x["league"]),
            str(x["outcome"]),
            str(x["odds_bucket"]),
            str(x["edge_bucket"]),
            str(x["draw_risk_bucket"]),
        )
        for x in watch
    }


def _add_features(df: pd.DataFrame, watch_segments: set[tuple[str, str, str, str, str]]) -> pd.DataFrame:
    out = df.copy()
    out["league"] = out["league"].astype(str)
    out["outcome"] = out["outcome"].astype(str)
    out["odds_bucket"] = out["odds_bucket"].astype(str)
    out["edge_bucket"] = out["edge_bucket"].astype(str)
    out["draw_risk_bucket"] = out["draw_risk_bucket"].astype(str)

    out["abs_cb_pois"] = (out["p_catboost"] - out["p_poisson"]).abs()
    out["abs_cb_market"] = (out["p_catboost"] - out["p_market_base"]).abs()
    out["abs_pois_market"] = (out["p_poisson"] - out["p_market_base"]).abs()
    out["candidate_is_favorite"] = out["candidate_is_favorite"].astype(int)
    out["candidate_is_home"] = out["candidate_is_home"].astype(int)
    out["candidate_is_draw"] = out["candidate_is_draw"].astype(int)
    out["candidate_is_away"] = out["candidate_is_away"].astype(int)
    out["segment_watch"] = [
        int((str(l), str(o), str(ob), str(eb), str(db)) in watch_segments)
        for l, o, ob, eb, db in zip(
            out["league"],
            out["outcome"],
            out["odds_bucket"],
            out["edge_bucket"],
            out["draw_risk_bucket"],
        )
    ]
    out["won"] = out["actual_win"].astype(int)
    return out


def _split_candidates(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    parts = []
    for lid, g in df.groupby("league_id"):
        g = g.sort_values("date_utc").reset_index(drop=True)
        if len(g) < 60:
            continue
        cut = max(int(len(g) * 0.75), len(g) - 120)
        cut = min(max(cut, 30), len(g) - 15)
        g["split"] = "train"
        g.loc[g.index >= cut, "split"] = "val"
        parts.append(g)
    merged = pd.concat(parts, ignore_index=True)
    return merged[merged["split"] == "train"].copy(), merged[merged["split"] == "val"].copy()


def _fit_value_model(train_df: pd.DataFrame, val_df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    from catboost import CatBoostClassifier

    num_cols = [
        "odds",
        "p_model",
        "p_market",
        "edge",
        "ev",
        "draw_risk_score",
        "p_catboost",
        "p_poisson",
        "p_market_base",
        "p_draw_side",
        "abs_cb_pois",
        "abs_cb_market",
        "abs_pois_market",
        "candidate_is_favorite",
        "candidate_is_home",
        "candidate_is_draw",
        "candidate_is_away",
        "segment_watch",
    ]
    cat_cols = ["league", "outcome", "odds_bucket", "edge_bucket", "draw_risk_bucket"]
    use_cols = num_cols + cat_cols

    X_train = train_df[use_cols].copy()
    X_val = val_df[use_cols].copy()
    for c in num_cols:
        X_train[c] = pd.to_numeric(X_train[c], errors="coerce").replace([np.inf, -np.inf], np.nan).fillna(0.0)
        X_val[c] = pd.to_numeric(X_val[c], errors="coerce").replace([np.inf, -np.inf], np.nan).fillna(0.0)
    for c in cat_cols:
        X_train[c] = X_train[c].astype(str).fillna("NA")
        X_val[c] = X_val[c].astype(str).fillna("NA")

    cat_idx = [X_train.columns.get_loc(c) for c in cat_cols]
    model = CatBoostClassifier(
        loss_function="Logloss",
        eval_metric="Logloss",
        iterations=600,
        learning_rate=0.03,
        depth=5,
        l2_leaf_reg=8.0,
        random_strength=1.5,
        bagging_temperature=0.5,
        min_data_in_leaf=20,
        random_seed=123,
        verbose=False,
        allow_writing_files=False,
        auto_class_weights="Balanced",
    )
    model.fit(
        X_train,
        train_df["won"].astype(int).values,
        cat_features=cat_idx,
        eval_set=(X_val, val_df["won"].astype(int).values),
        use_best_model=True,
    )
    train_df = train_df.copy()
    val_df = val_df.copy()
    train_df["value_score"] = model.predict_proba(X_train)[:, 1]
    val_df["value_score"] = model.predict_proba(X_val)[:, 1]
    train_df["ev_value"] = train_df["value_score"] * train_df["odds"] - 1.0
    val_df["ev_value"] = val_df["value_score"] * val_df["odds"] - 1.0
    return train_df, val_df


def _summarize(df: pd.DataFrame, label: str) -> dict:
    bets = int(len(df))
    profit = float(df["profit"].sum()) if bets else 0.0
    roi = float(df["profit"].mean()) if bets else None
    hit_rate = float(df["won"].mean()) if bets else None
    return {
        "label": label,
        "bets": bets,
        "profit": profit,
        "roi": roi,
        "hit_rate": hit_rate,
    }


def _grid_search(train_df: pd.DataFrame) -> dict:
    best = None
    for min_ev in [0.02, 0.04, 0.06, 0.08, 0.10]:
        for min_edge in [0.00, 0.02, 0.05, 0.08]:
            for min_score in [0.20, 0.24, 0.28, 0.32, 0.36]:
                for max_draw in [0.26, 0.30, 0.34]:
                    for watch_only in [0, 1]:
                        picked = train_df[
                            (train_df["ev"] >= min_ev)
                            & (train_df["edge"] >= min_edge)
                            & (train_df["value_score"] >= min_score)
                            & (train_df["draw_risk_score"] <= max_draw)
                        ].copy()
                        if watch_only:
                            picked = picked[picked["segment_watch"] == 1].copy()
                        if len(picked) < 20:
                            continue
                        roi = float(picked["profit"].mean())
                        if best is None or (roi > best["roi"]) or (roi == best["roi"] and len(picked) > best["bets"]):
                            best = {
                                "min_ev": min_ev,
                                "min_edge": min_edge,
                                "min_score": min_score,
                                "max_draw": max_draw,
                                "watch_only": bool(watch_only),
                                "bets": int(len(picked)),
                                "roi": roi,
                                "profit": float(picked["profit"].sum()),
                            }
    return best or {
        "min_ev": 0.10,
        "min_edge": 0.06,
        "min_score": 0.30,
        "max_draw": 0.30,
        "watch_only": False,
        "bets": 0,
        "roi": None,
        "profit": 0.0,
    }


def _apply_rule(df: pd.DataFrame, rule: dict) -> pd.DataFrame:
    picked = df[
        (df["ev"] >= rule["min_ev"])
        & (df["edge"] >= rule["min_edge"])
        & (df["value_score"] >= rule["min_score"])
        & (df["draw_risk_score"] <= rule["max_draw"])
    ].copy()
    if rule["watch_only"]:
        picked = picked[picked["segment_watch"] == 1].copy()
    return picked


def _by_league(df: pd.DataFrame) -> dict:
    out = {}
    for league, g in df.groupby("league"):
        out[str(league)] = _summarize(g, str(league))
    return out


def main():
    base = _load_candidates()
    watch_segments = _load_watch_segments()
    df = _add_features(base, watch_segments)
    train_df, val_df = _split_candidates(df)
    train_scored, val_scored = _fit_value_model(train_df, val_df)

    baseline = val_scored[
        (val_scored["odds"] >= 1.70)
        & (val_scored["odds"] <= 3.20)
        & (val_scored["edge"] >= 0.06)
        & (val_scored["ev"] >= 0.10)
        & (val_scored["draw_risk_score"] <= 0.30)
    ].copy()
    best_rule = _grid_search(train_scored)
    val_picks = _apply_rule(val_scored, best_rule)

    payload = {
        "candidate_rows": int(len(df)),
        "train_rows": int(len(train_scored)),
        "val_rows": int(len(val_scored)),
        "best_rule": best_rule,
        "baseline_rule": _summarize(baseline, "baseline_rule"),
        "value_layer_rule": _summarize(val_picks, "value_layer_rule"),
        "baseline_by_league": _by_league(baseline),
        "value_by_league": _by_league(val_picks),
        "value_score_summary": {
            "train_mean": float(train_scored["value_score"].mean()),
            "val_mean": float(val_scored["value_score"].mean()),
        },
    }
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
