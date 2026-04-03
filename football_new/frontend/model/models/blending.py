# -*- coding: utf-8 -*-
# models/blending.py
# Утилиты для смешивания вероятностей моделей и рынка
# Python 3.9 compatible

import numpy as np


# =========================
# BASIC SANITIZE
# =========================

def sanitize_prob(p):
    """
    Приводит вероятности в безопасный вид:
    - убирает nan / inf
    - клипает
    - нормализует
    """
    p = np.asarray(p, dtype="float64")

    if p.ndim == 1:
        p = np.nan_to_num(p, nan=0.5, posinf=1.0, neginf=0.0)
        p = np.clip(p, 1e-6, 1.0 - 1e-6)
        return p

    # 2D (например 1X2)
    p = np.nan_to_num(p, nan=1.0 / p.shape[1], posinf=1.0, neginf=0.0)
    p = np.clip(p, 1e-6, 1.0)
    row_sum = p.sum(axis=1, keepdims=True)
    row_sum[row_sum == 0] = 1.0
    return p / row_sum


# =========================
# SAFE BLEND (1D)
# =========================

def _safe_blend(p_model, p_market, alpha):
    """
    Безопасное смешивание бинарных вероятностей:
      p = (1 - alpha) * p_model + alpha * p_market
    """
    if alpha <= 0:
        return sanitize_prob(p_model)

    p_model = sanitize_prob(p_model)
    p_market = sanitize_prob(p_market)

    out = (1.0 - alpha) * p_model + alpha * p_market
    return sanitize_prob(out)


# =========================
# POISSON + XGB (1X2)
# =========================

def blend_poisson_and_xgb(P_poisson, P_xgb, alpha):
    """
    Смешивание вероятностей 1X2:
      P = alpha * XGB + (1 - alpha) * Poisson
    """
    P_poisson = sanitize_prob(P_poisson)
    P_xgb = sanitize_prob(P_xgb)

    if alpha <= 0:
        return P_poisson
    if alpha >= 1:
        return P_xgb

    P = alpha * P_xgb + (1.0 - alpha) * P_poisson
    return sanitize_prob(P)


# =========================
# MARKET ANCHOR (1X2)
# =========================

def apply_market_anchor(P_model, P_market, tau):
    """
    Якорение 1X2 к рынку:
      P = (1 - tau) * P_model + tau * P_market
    """
    if tau <= 0:
        return sanitize_prob(P_model)

    P_model = sanitize_prob(P_model)
    P_market = sanitize_prob(P_market)

    P = (1.0 - tau) * P_model + tau * P_market
    return sanitize_prob(P)


# =========================
# DRAW CONTROL (1X2)
# =========================

def apply_draw_cap(P, max_draw=0.55, boost_small_draw=0.10):
    """
    Контроль вероятности ничьей:
    - ограничение сверху
    - мягкий буст слишком маленьких значений
    """
    P = sanitize_prob(P)

    pA = P[:, 0]
    pD = P[:, 1]
    pH = P[:, 2]

    # cap
    over = pD > max_draw
    if over.any():
        excess = pD[over] - max_draw
        pD[over] = max_draw
        pA[over] += excess * 0.5
        pH[over] += excess * 0.5

    # boost small draw
    small = pD < boost_small_draw
    if small.any():
        delta = boost_small_draw - pD[small]
        pD[small] = boost_small_draw
        pA[small] -= delta * 0.5
        pH[small] -= delta * 0.5

    P2 = np.stack([pA, pD, pH], axis=1)
    return sanitize_prob(P2)
