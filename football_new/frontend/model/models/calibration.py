# models/calibration.py

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.isotonic import IsotonicRegression


def sanitize_prob(x):
    x = np.asarray(x, dtype="float64")
    x = np.nan_to_num(x, nan=0.5, posinf=0.999999, neginf=1e-6)
    return np.clip(x, 1e-6, 1 - 1e-6)


# -------- 1X2: multinomial LR --------

def fit_multinomial_lr_calibrator(P_cal: np.ndarray, y_cal_3: np.ndarray):
    """
    P_cal: (n,3) — сырые вероятности (Away, Draw, Home)
    y_cal_3: 0/1/2
    """
    P_cal = np.asarray(P_cal, dtype="float64")
    y = np.asarray(y_cal_3, dtype=int)

    X = np.log(P_cal / (1 - P_cal))
    lr = LogisticRegression(max_iter=200, solver="lbfgs")
    lr.fit(X, y)
    return lr


def per_league_lr(
    P_cal: np.ndarray,
    y_cal_3: np.ndarray,
    leagues: pd.Series,
    min_per_league: int = 40,
):
    """
    Возвращает:
      global_lr, {league_id: lr_league}
    """
    P_cal = np.asarray(P_cal, dtype="float64")
    y = np.asarray(y_cal_3, dtype=int)
    leagues = pd.to_numeric(leagues, errors="coerce").values

    X = np.log(P_cal / (1 - P_cal))
    global_lr = LogisticRegression(max_iter=200, solver="lbfgs")
    global_lr.fit(X, y)

    per_league = {}
    for lid in pd.Series(leagues).dropna().unique().astype(int):
        mask = leagues == lid
        if mask.sum() < min_per_league:
            continue
        lr = LogisticRegression(max_iter=200, solver="lbfgs")
        lr.fit(X[mask], y[mask])
        per_league[int(lid)] = lr

    return global_lr, per_league


def apply_multinomial_lr(
    P_raw: np.ndarray,
    leagues: pd.Series,
    global_lr: LogisticRegression,
    per_league: dict[int, LogisticRegression],
):
    P_raw = np.asarray(P_raw, dtype="float64")
    leagues = pd.to_numeric(leagues, errors="coerce").values
    X = np.log(P_raw / (1 - P_raw))

    out = np.zeros_like(P_raw)
    used = np.zeros(len(P_raw), dtype=bool)

    for lid, lr in per_league.items():
        m = leagues == int(lid)
        if not m.any():
            continue
        out[m] = sanitize_prob(lr.predict_proba(X[m]))
        used[m] = True

    if (~used).any():
        out[~used] = sanitize_prob(global_lr.predict_proba(X[~used]))

    return out


# -------- Totals: isotonic --------

def _iso_is_fitted(iso: IsotonicRegression) -> bool:
    return hasattr(iso, "X_thresholds_") and hasattr(iso, "y_thresholds_")


def _safe_iso_predict(iso: IsotonicRegression, x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, dtype="float64")
    if _iso_is_fitted(iso):
        try:
            y = iso.predict(x)
            return sanitize_prob(y)
        except Exception:
            return sanitize_prob(x)
    else:
        return sanitize_prob(x)


def fit_isotonic_per_league(
    p_cal_raw: np.ndarray,
    y_cal: np.ndarray,
    leagues: pd.Series,
    min_per_league: int = 120,
):
    p_cal_raw = np.asarray(p_cal_raw, dtype="float64")
    y_cal = np.asarray(y_cal, dtype=int)
    leagues = pd.to_numeric(leagues, errors="coerce").values

    iso_global = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
    try:
        iso_global.fit(p_cal_raw, y_cal)
    except Exception:
        pass

    iso_by_league: dict[int, IsotonicRegression] = {}
    for lid in pd.Series(leagues).dropna().unique().astype(int):
        m = leagues == lid
        if m.sum() < min_per_league:
            continue
        iso = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
        try:
            iso.fit(p_cal_raw[m], y_cal[m])
            iso_by_league[int(lid)] = iso
        except Exception:
            continue

    return iso_global, iso_by_league


def apply_iso_per_league(
    p_raw: np.ndarray,
    leagues: pd.Series,
    iso_global: IsotonicRegression,
    iso_by_league: dict[int, IsotonicRegression],
):
    p_raw = np.asarray(p_raw, dtype="float64")
    leagues = pd.to_numeric(leagues, errors="coerce").values
    out = np.zeros_like(p_raw)
    used = np.zeros(len(p_raw), dtype=bool)

    for lid, iso in iso_by_league.items():
        m = leagues == int(lid)
        if not m.any():
            continue
        out[m] = _safe_iso_predict(iso, p_raw[m])
        used[m] = True

    if (~used).any():
        out[~used] = _safe_iso_predict(iso_global, p_raw[~used])

    return sanitize_prob(out)
