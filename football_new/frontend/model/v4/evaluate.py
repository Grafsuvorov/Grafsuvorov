from __future__ import annotations

import numpy as np
import pandas as pd


def outcome_target(df: pd.DataFrame) -> np.ndarray:
    hg = pd.to_numeric(df["home_goals"], errors="coerce").fillna(0).to_numpy()
    ag = pd.to_numeric(df["away_goals"], errors="coerce").fillna(0).to_numpy()
    y = np.zeros(len(df), dtype="int64")
    y[ag > hg] = 0
    y[ag == hg] = 1
    y[hg > ag] = 2
    return y


def multiclass_logloss(y: np.ndarray, probs: np.ndarray) -> float:
    probs = np.clip(probs, 1e-9, 1 - 1e-9)
    return float(-np.mean(np.log(probs[np.arange(len(y)), y])))


def multiclass_accuracy(y: np.ndarray, probs: np.ndarray) -> float:
    pred = np.argmax(probs, axis=1)
    return float(np.mean(pred == y))


def multiclass_brier(y: np.ndarray, probs: np.ndarray) -> float:
    probs = np.asarray(probs, dtype="float64")
    target = np.zeros_like(probs)
    target[np.arange(len(y)), y] = 1.0
    return float(np.mean(np.sum((probs - target) ** 2, axis=1)))


def topclass_calibration_gap(y: np.ndarray, probs: np.ndarray, bins: int = 10) -> float:
    probs = np.asarray(probs, dtype="float64")
    pred = np.argmax(probs, axis=1)
    conf = probs[np.arange(len(y)), pred]
    correct = (pred == y).astype("float64")

    edges = np.linspace(0.0, 1.0, bins + 1)
    weighted_gap = 0.0
    n = len(y)
    for i in range(bins):
        lo = edges[i]
        hi = edges[i + 1]
        if i == bins - 1:
            mask = (conf >= lo) & (conf <= hi)
        else:
            mask = (conf >= lo) & (conf < hi)
        if not np.any(mask):
            continue
        bin_conf = float(np.mean(conf[mask]))
        bin_acc = float(np.mean(correct[mask]))
        weighted_gap += abs(bin_conf - bin_acc) * (float(np.sum(mask)) / n)
    return float(weighted_gap)


def evaluate_probs(df: pd.DataFrame, probs: np.ndarray, label: str) -> dict:
    y = outcome_target(df)
    return {
        "label": label,
        "n": int(len(df)),
        "logloss": round(multiclass_logloss(y, probs), 6),
        "accuracy": round(multiclass_accuracy(y, probs), 6),
        "brier": round(multiclass_brier(y, probs), 6),
        "topclass_calibration_gap": round(topclass_calibration_gap(y, probs), 6),
    }


def evaluate_by_league(df: pd.DataFrame, probs: np.ndarray, label: str) -> list[dict]:
    out = []
    for league, g in df.groupby("league", sort=True):
        idx = g.index.to_numpy()
        out.append(
            {
                "league": league,
                **evaluate_probs(g, probs[idx], label),
            }
        )
    return out
