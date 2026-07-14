import json
from pathlib import Path

import numpy as np
import pandas as pd


CANDIDATE_PATH = Path("tmp/outcome_v3_candidate_dataset.csv")
OUT_PATH = Path("tmp/outcome_v3_segment_portfolio_research.json")
SEGMENT_COLS = ["league", "outcome", "odds_bucket", "edge_bucket", "draw_risk_bucket"]


def _load_candidates() -> pd.DataFrame:
    df = pd.read_csv(CANDIDATE_PATH)
    df["date_utc"] = pd.to_datetime(df["date_utc"], utc=True, errors="coerce")
    for c in SEGMENT_COLS:
        df[c] = df[c].astype(str)
    return df


def _time_split(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    parts = []
    for lid, g in df.groupby("league_id"):
        g = g.sort_values("date_utc").reset_index(drop=True)
        if len(g) < 90:
            continue
        cut = max(int(len(g) * 0.75), len(g) - 120)
        cut = min(max(cut, 40), len(g) - 20)
        g["split"] = "train"
        g.loc[g.index >= cut, "split"] = "val"
        parts.append(g)
    merged = pd.concat(parts, ignore_index=True)
    return merged[merged["split"] == "train"].copy(), merged[merged["split"] == "val"].copy()


def _segment_windows(g: pd.DataFrame, window_days: int = 60, step_days: int = 30) -> tuple[int, int, float | None]:
    g = g.sort_values("date_utc")
    start = g["date_utc"].min()
    end = g["date_utc"].max()
    if pd.isna(start) or pd.isna(end):
        return 0, 0, None
    window = pd.Timedelta(days=window_days)
    step = pd.Timedelta(days=step_days)
    cur = start
    total = 0
    pos = 0
    rois = []
    while cur + window <= end:
        w = g[(g["date_utc"] >= cur) & (g["date_utc"] < cur + window)]
        if len(w) >= 5:
            roi = float(w["profit"].mean())
            rois.append(roi)
            pos += int(roi > 0)
            total += 1
        cur += step
    avg_roi = sum(rois) / len(rois) if rois else None
    return total, pos, avg_roi


def _clip01(x: float) -> float:
    return float(min(max(x, 0.0), 1.0))


def _build_segment_stats(train_df: pd.DataFrame) -> pd.DataFrame:
    records = []
    for keys, g in train_df.groupby(SEGMENT_COLS, dropna=False):
        windows, pos_windows, avg_window_roi = _segment_windows(g)
        roi = float(g["profit"].mean())
        n = int(len(g))
        calib_gap = float(g["p_model"].mean() - g["actual_win"].mean())
        ll_delta = None
        try:
            from sklearn.metrics import log_loss

            y = g["actual_win"].astype(int).values
            ll_model = float(log_loss(y, np.clip(g["p_model"].astype(float).values, 1e-6, 1 - 1e-6), labels=[0, 1]))
            ll_market = float(log_loss(y, np.clip(g["p_market"].astype(float).values, 1e-6, 1 - 1e-6), labels=[0, 1]))
            ll_delta = ll_model - ll_market
        except Exception:
            ll_delta = None

        roi_score = _clip01((roi + 0.05) / 0.25)
        sample_score = _clip01(np.log1p(n) / np.log(61))
        stability_score = _clip01((pos_windows / windows) if windows else 0.0)
        calib_score = _clip01(1.0 - abs(calib_gap) / 0.08)
        ll_score = 0.5 if ll_delta is None else _clip01((0.02 - ll_delta) / 0.04)
        window_roi_score = 0.5 if avg_window_roi is None else _clip01((avg_window_roi + 0.05) / 0.25)

        strength = (
            0.30 * roi_score
            + 0.20 * stability_score
            + 0.15 * sample_score
            + 0.15 * calib_score
            + 0.10 * ll_score
            + 0.10 * window_roi_score
        )
        tier = "D"
        if strength >= 0.72 and n >= 20:
            tier = "A"
        elif strength >= 0.58 and n >= 15:
            tier = "B"
        elif strength >= 0.46 and n >= 10:
            tier = "C"

        rec = dict(zip(SEGMENT_COLS, keys))
        rec.update(
            {
                "n": n,
                "roi": roi,
                "profit": float(g["profit"].sum()),
                "hit_rate": float(g["actual_win"].mean()),
                "avg_p_model": float(g["p_model"].mean()),
                "avg_p_market": float(g["p_market"].mean()),
                "avg_edge": float(g["edge"].mean()),
                "avg_ev": float(g["ev"].mean()),
                "calibration_gap": calib_gap,
                "ll_delta": ll_delta,
                "windows": windows,
                "positive_windows": pos_windows,
                "avg_window_roi": avg_window_roi,
                "strength": float(strength),
                "tier": tier,
            }
        )
        records.append(rec)
    out = pd.DataFrame(records)
    return out.sort_values(["strength", "n"], ascending=[False, False]).reset_index(drop=True)


def _attach_segment_strength(df: pd.DataFrame, seg_stats: pd.DataFrame) -> pd.DataFrame:
    cols = SEGMENT_COLS + ["strength", "tier"]
    return df.merge(seg_stats[cols], on=SEGMENT_COLS, how="left")


def _candidate_score(df: pd.DataFrame) -> pd.Series:
    ev_norm = np.clip(pd.to_numeric(df["ev"], errors="coerce").fillna(0.0), 0.0, 0.25) / 0.25
    edge_norm = np.clip(pd.to_numeric(df["edge"], errors="coerce").fillna(0.0), 0.0, 0.12) / 0.12
    score = pd.to_numeric(df["strength"], errors="coerce").fillna(0.0) * (0.65 * ev_norm + 0.35 * edge_norm)
    return score.astype(float)


def _pick_portfolio(df: pd.DataFrame, min_strength: float, min_score: float, tiers: set[str], max_odds: float = 4.0) -> pd.DataFrame:
    cand = df.copy()
    cand["portfolio_score"] = _candidate_score(cand)
    cand = cand[
        cand["tier"].isin(tiers)
        & (pd.to_numeric(cand["strength"], errors="coerce").fillna(0.0) >= min_strength)
        & (cand["portfolio_score"] >= min_score)
        & (pd.to_numeric(cand["odds"], errors="coerce").fillna(np.inf) <= max_odds)
    ].copy()
    if cand.empty:
        return cand
    cand = cand.sort_values(["fixture_id", "portfolio_score", "strength", "ev"], ascending=[True, False, False, False])
    best = cand.groupby("fixture_id", as_index=False).head(1).copy()
    return best


def _summarize(df: pd.DataFrame, label: str) -> dict:
    bets = int(len(df))
    return {
        "label": label,
        "bets": bets,
        "profit": float(df["profit"].sum()) if bets else 0.0,
        "roi": float(df["profit"].mean()) if bets else None,
        "hit_rate": float(df["actual_win"].mean()) if bets else None,
    }


def _by_league(df: pd.DataFrame) -> dict:
    out = {}
    for league, g in df.groupby("league"):
        out[str(league)] = _summarize(g, str(league))
    return out


def _best_single_segment(train_df: pd.DataFrame, seg_stats: pd.DataFrame, val_df: pd.DataFrame) -> tuple[dict, pd.DataFrame]:
    eligible = seg_stats[(seg_stats["n"] >= 20) & (seg_stats["roi"] > 0)].copy()
    if eligible.empty:
        return {}, val_df.iloc[0:0].copy()
    best = eligible.sort_values(["strength", "roi", "n"], ascending=[False, False, False]).iloc[0].to_dict()
    key = tuple(str(best[c]) for c in SEGMENT_COLS)
    mask = val_df.apply(lambda r: tuple(str(r[c]) for c in SEGMENT_COLS) == key, axis=1)
    return best, val_df[mask].copy()


def _grid_search(train_df: pd.DataFrame) -> dict:
    best = None
    for min_strength in [0.46, 0.52, 0.58, 0.64, 0.72]:
        for min_score in [0.05, 0.08, 0.10, 0.12, 0.15]:
            for tiers in [{"A"}, {"A", "B"}, {"A", "B", "C"}]:
                picked = _pick_portfolio(train_df, min_strength, min_score, tiers)
                if len(picked) < 12:
                    continue
                roi = float(picked["profit"].mean())
                if best is None or (roi > best["roi"]) or (roi == best["roi"] and len(picked) > best["bets"]):
                    best = {
                        "min_strength": min_strength,
                        "min_score": min_score,
                        "tiers": sorted(tiers),
                        "bets": int(len(picked)),
                        "roi": roi,
                        "profit": float(picked["profit"].sum()),
                    }
    return best or {"min_strength": 0.58, "min_score": 0.10, "tiers": ["A", "B"], "bets": 0, "roi": None, "profit": 0.0}


def main():
    df = _load_candidates()
    train_df, val_df = _time_split(df)

    seg_stats = _build_segment_stats(train_df)
    train_scored = _attach_segment_strength(train_df, seg_stats)
    val_scored = _attach_segment_strength(val_df, seg_stats)

    best_single_seg, best_single_val = _best_single_segment(train_scored, seg_stats, val_scored)
    best_portfolio_rule = _grid_search(train_scored)
    portfolio_val = _pick_portfolio(
        val_scored,
        min_strength=best_portfolio_rule["min_strength"],
        min_score=best_portfolio_rule["min_score"],
        tiers=set(best_portfolio_rule["tiers"]),
    )

    payload = {
        "candidate_rows": int(len(df)),
        "train_rows": int(len(train_scored)),
        "val_rows": int(len(val_scored)),
        "top_segments_train": seg_stats.head(20).to_dict(orient="records"),
        "best_single_segment": best_single_seg,
        "best_single_segment_val": _summarize(best_single_val, "best_single_segment_val"),
        "best_portfolio_rule": best_portfolio_rule,
        "portfolio_val": _summarize(portfolio_val, "portfolio_val"),
        "portfolio_by_league": _by_league(portfolio_val),
        "tiers_train": seg_stats["tier"].value_counts(dropna=False).to_dict(),
    }
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
