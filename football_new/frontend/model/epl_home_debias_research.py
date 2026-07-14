import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import log_loss


CANDIDATE_PATH = Path("tmp/outcome_v3_candidate_dataset.csv")
OUT_PATH = Path("tmp/epl_home_debias_research.json")


def _load_fixture_probs() -> pd.DataFrame:
    cand = pd.read_csv(CANDIDATE_PATH)
    cand["league"] = cand["league"].astype(str)
    df = cand[cand["league"] == "39"].copy()
    piv = df.pivot_table(index="fixture_id", columns="outcome", values=["p_model", "p_market", "p_catboost", "p_poisson", "p_draw_side"], aggfunc="first")
    piv.columns = [f"{a}_{b}" for a, b in piv.columns]
    piv = piv.reset_index()

    home = df[df["outcome"] == "Home"][["fixture_id", "actual_win", "odds"]].rename(columns={"actual_win": "home_win", "odds": "odds_home"})
    draw = df[df["outcome"] == "Draw"][["fixture_id", "actual_win", "odds"]].rename(columns={"actual_win": "draw_win", "odds": "odds_draw"})
    away = df[df["outcome"] == "Away"][["fixture_id", "actual_win", "odds"]].rename(columns={"actual_win": "away_win", "odds": "odds_away"})
    out = piv.merge(home, on="fixture_id").merge(draw, on="fixture_id").merge(away, on="fixture_id")
    out["target"] = np.where(out["home_win"] == 1, 2, np.where(out["away_win"] == 1, 0, 1))
    return out


def _shrink_home_bias(df: pd.DataFrame, alpha: float, threshold: float, away_share: float) -> np.ndarray:
    P = df[["p_model_Away", "p_model_Draw", "p_model_Home"]].to_numpy(float).copy()
    M = df[["p_market_Away", "p_market_Draw", "p_market_Home"]].to_numpy(float)
    excess = np.maximum(0.0, P[:, 2] - M[:, 2] - threshold)
    shift = alpha * excess
    P[:, 2] -= shift
    rem = shift
    P[:, 0] += rem * away_share
    P[:, 1] += rem * (1.0 - away_share)
    P = np.clip(P, 1e-6, 1 - 1e-6)
    P = P / P.sum(axis=1, keepdims=True)
    return P


def _blend_market_home(df: pd.DataFrame, beta: float) -> np.ndarray:
    P = df[["p_model_Away", "p_model_Draw", "p_model_Home"]].to_numpy(float).copy()
    M = df[["p_market_Away", "p_market_Draw", "p_market_Home"]].to_numpy(float)
    P[:, 2] = (1.0 - beta) * P[:, 2] + beta * M[:, 2]
    delta = 1.0 - P[:, 2] - (P[:, 0] + P[:, 1])
    denom = np.clip(M[:, 0] + M[:, 1], 1e-9, None)
    P[:, 0] += delta * (M[:, 0] / denom)
    P[:, 1] += delta * (M[:, 1] / denom)
    P = np.clip(P, 1e-6, 1 - 1e-6)
    P = P / P.sum(axis=1, keepdims=True)
    return P


def _summarize_home_bets(df: pd.DataFrame, P: np.ndarray, min_edge: float = 0.05) -> dict:
    M = df[["p_market_Away", "p_market_Draw", "p_market_Home"]].to_numpy(float)
    odds = df["odds_home"].astype(float).values
    edge = P[:, 2] - M[:, 2]
    mask = (odds >= 1.55) & (odds <= 4.0) & np.isfinite(odds) & (edge >= min_edge)
    if not mask.any():
        return {"bets": 0, "roi": None, "hit_rate": None}
    won = df.loc[mask, "home_win"].astype(int).values
    profit = np.where(won == 1, odds[mask] - 1.0, -1.0)
    return {
        "bets": int(mask.sum()),
        "roi": float(profit.mean()),
        "hit_rate": float(won.mean()),
        "avg_p_home": float(P[mask, 2].mean()),
        "avg_p_home_market": float(M[mask, 2].mean()),
        "avg_edge": float(edge[mask].mean()),
    }


def main():
    df = _load_fixture_probs()
    y = df["target"].astype(int).values
    P_base = df[["p_model_Away", "p_model_Draw", "p_model_Home"]].to_numpy(float)
    base_ll = float(log_loss(y, P_base, labels=[0, 1, 2]))
    base_home = _summarize_home_bets(df, P_base)

    best = None
    results = []

    for method in ["shrink", "market_home_blend"]:
        if method == "shrink":
            for alpha in [0.25, 0.4, 0.5, 0.6, 0.75]:
                for threshold in [0.0, 0.02, 0.05, 0.08]:
                    for away_share in [0.55, 0.60, 0.65, 0.70]:
                        P = _shrink_home_bias(df, alpha=alpha, threshold=threshold, away_share=away_share)
                        ll = float(log_loss(y, P, labels=[0, 1, 2]))
                        home = _summarize_home_bets(df, P)
                        rec = {
                            "method": method,
                            "alpha": alpha,
                            "threshold": threshold,
                            "away_share": away_share,
                            "val_logloss": ll,
                            "home_bets": home["bets"],
                            "home_roi": home["roi"],
                            "home_hit_rate": home["hit_rate"],
                            "home_avg_p": home.get("avg_p_home"),
                            "home_avg_market_p": home.get("avg_p_home_market"),
                            "home_avg_edge": home.get("avg_edge"),
                        }
                        results.append(rec)
                        key = (ll, -(home["roi"] or -999), home["bets"])
                        if best is None or key < best[0]:
                            best = (key, rec)
        else:
            for beta in [0.1, 0.2, 0.3, 0.4, 0.5]:
                P = _blend_market_home(df, beta=beta)
                ll = float(log_loss(y, P, labels=[0, 1, 2]))
                home = _summarize_home_bets(df, P)
                rec = {
                    "method": method,
                    "beta": beta,
                    "val_logloss": ll,
                    "home_bets": home["bets"],
                    "home_roi": home["roi"],
                    "home_hit_rate": home["hit_rate"],
                    "home_avg_p": home.get("avg_p_home"),
                    "home_avg_market_p": home.get("avg_p_home_market"),
                    "home_avg_edge": home.get("avg_edge"),
                }
                results.append(rec)
                key = (ll, -(home["roi"] or -999), home["bets"])
                if best is None or key < best[0]:
                    best = (key, rec)

    results_df = pd.DataFrame(results).sort_values(["val_logloss", "home_roi"], ascending=[True, False])
    payload = {
        "base": {
            "val_logloss": base_ll,
            "home_summary": base_home,
        },
        "best": best[1] if best else None,
        "top10": results_df.head(10).replace({np.nan: None}).to_dict(orient="records"),
    }
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
