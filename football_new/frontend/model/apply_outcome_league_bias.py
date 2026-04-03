import argparse
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text
import joblib

from config import DB_URL, OUTCOME_MODEL_PATH


def _parse_args():
    p = argparse.ArgumentParser(description="Apply league outcome bias to model bundle")
    p.add_argument("--from", dest="date_from", required=True)
    p.add_argument("--to", dest="date_to", required=True)
    p.add_argument("--k39", type=float, default=0.5)
    p.add_argument("--k61", type=float, default=0.3)
    p.add_argument("--k78", type=float, default=0.5)
    p.add_argument("--k135", type=float, default=0.3)
    p.add_argument("--k140", type=float, default=0.0)
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args()


def _sanitize_prob(P: np.ndarray) -> np.ndarray:
    P = np.clip(P, 1e-6, 1 - 1e-6)
    s = P.sum(axis=1, keepdims=True)
    return P / s


def _outcome_from_score(hg: int, ag: int) -> int:
    if hg > ag:
        return 2  # Home
    if hg == ag:
        return 1  # Draw
    return 0  # Away


def main():
    args = _parse_args()
    engine = create_engine(DB_URL)
    q = text(
        """
        SELECT
            s.league_id,
            s.home_goals,
            s.away_goals,
            p.p_home,
            p.p_draw,
            p.p_away
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s
          ON s.fixture_id = p.fixture_id
        WHERE s.date BETWEEN :dfrom AND :dto
          AND s.home_goals IS NOT NULL
          AND s.away_goals IS NOT NULL
          AND s.league_id IN (39, 61, 78, 135, 140)
        ORDER BY s.date ASC;
        """
    )
    df = pd.read_sql(q, engine, params={"dfrom": args.date_from, "dto": args.date_to})
    if df.empty:
        print("No data in selected period")
        return

    P = df[["p_away", "p_draw", "p_home"]].astype(float).to_numpy()
    P = _sanitize_prob(P)
    y = np.array([_outcome_from_score(h, a) for h, a in zip(df.home_goals, df.away_goals)])
    Y = np.eye(3)[y]

    bias = {}
    for lid in (39, 61, 78, 135, 140):
        mask = df.league_id == lid
        if mask.sum() < 30:
            print(f"League {lid}: insufficient sample ({mask.sum()})")
            continue
        mean_pred = P[mask.values].mean(axis=0)
        mean_actual = Y[mask.values].mean(axis=0)
        delta = mean_actual - mean_pred
        bias[lid] = delta

    if not bias:
        print("No bias computed")
        return

    k = {
        39: args.k39,
        61: args.k61,
        78: args.k78,
        135: args.k135,
        140: args.k140,
    }
    for lid, delta in bias.items():
        print(f"L{lid} raw delta: {delta}, k={k[lid]} -> applied {delta * k[lid]}")

    bundle = joblib.load(OUTCOME_MODEL_PATH)
    if not isinstance(bundle, dict):
        raise RuntimeError("Outcome model bundle must be a dict of league models")

    # store bias at top-level (used by models/inference.py)
    top_bias = bundle.get("league_prob_bias") or {}
    for lid in (39, 61, 78, 135, 140):
        if lid not in bias:
            continue
        if k[lid] == 0:
            if int(lid) in top_bias:
                top_bias.pop(int(lid), None)
                print(f"Removed league_prob_bias for L{lid}")
        else:
            top_bias[int(lid)] = (bias[lid] * k[lid]).tolist()
            print(f"Updated league_prob_bias for L{lid}")
    bundle["league_prob_bias"] = top_bias

    if args.dry_run:
        print("Dry run: not saving")
        return

    joblib.dump(bundle, OUTCOME_MODEL_PATH)
    print(f"Saved: {Path(OUTCOME_MODEL_PATH)}")


if __name__ == "__main__":
    main()
