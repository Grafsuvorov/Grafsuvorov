from __future__ import annotations

import numpy as np
from sklearn.linear_model import LogisticRegression


def probs_to_logits(probs: np.ndarray) -> np.ndarray:
    p = np.clip(np.asarray(probs, dtype="float64"), 1e-9, 1 - 1e-9)
    p = p / p.sum(axis=1, keepdims=True)
    return np.log(p)


def fit_multiclass_calibrator(probs: np.ndarray, y: np.ndarray) -> LogisticRegression:
    x = probs_to_logits(probs)
    model = LogisticRegression(
        max_iter=2000,
        C=1.0,
        random_state=42,
    )
    model.fit(x, y)
    return model


def apply_multiclass_calibrator(model: LogisticRegression, probs: np.ndarray) -> np.ndarray:
    x = probs_to_logits(probs)
    out = model.predict_proba(x)
    out = np.clip(np.asarray(out, dtype="float64"), 1e-9, 1 - 1e-9)
    out /= out.sum(axis=1, keepdims=True)
    return out
