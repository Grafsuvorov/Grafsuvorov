from __future__ import annotations

from collections import defaultdict

import numpy as np
import pandas as pd

from .settings import (
    FALLBACK_AWAY_GOALS,
    FALLBACK_HOME_GOALS,
    MIN_MATCHES_FOR_TEAM_STATE,
)


def poisson_triplet_and_over(lh: float, la: float, K: int = 10) -> tuple[float, float, float, float]:
    lh = float(max(1e-8, lh))
    la = float(max(1e-8, la))
    pmf_h = np.zeros(K + 1, dtype="float64")
    pmf_a = np.zeros(K + 1, dtype="float64")
    pmf_h[0] = np.exp(-lh)
    pmf_a[0] = np.exp(-la)
    for k in range(1, K):
        pmf_h[k] = pmf_h[k - 1] * lh / k
        pmf_a[k] = pmf_a[k - 1] * la / k
    pmf_h[K] = max(0.0, 1.0 - pmf_h[:K].sum())
    pmf_a[K] = max(0.0, 1.0 - pmf_a[:K].sum())
    pmf_h /= pmf_h.sum()
    pmf_a /= pmf_a.sum()
    joint = np.outer(pmf_h, pmf_a)
    idx = np.arange(K + 1)
    total_goals = np.add.outer(idx, idx)
    p_home = joint[idx[:, None] > idx[None, :]].sum()
    p_draw = joint[idx[:, None] == idx[None, :]].sum()
    p_away = joint[idx[:, None] < idx[None, :]].sum()
    p_over = joint[total_goals >= 3].sum()
    s = p_home + p_draw + p_away
    return float(p_away / s), float(p_draw / s), float(p_home / s), float(p_over)



def _market_probs(home_odds: float, draw_odds: float, away_odds: float) -> tuple[float, float, float]:
    imp_h = 1.0 / float(home_odds)
    imp_d = 1.0 / float(draw_odds)
    imp_a = 1.0 / float(away_odds)
    overround = imp_h + imp_d + imp_a
    return imp_a / overround, imp_d / overround, imp_h / overround


def add_market_baseline(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    probs = out.apply(
        lambda r: _market_probs(r["avg_odds_home"], r["avg_odds_draw"], r["avg_odds_away"]),
        axis=1,
        result_type="expand",
    )
    probs.columns = ["p_away_mkt", "p_draw_mkt", "p_home_mkt"]
    return pd.concat([out, probs], axis=1)


def build_simple_poisson_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()

    league_state = defaultdict(
        lambda: {
            "matches": 0,
            "home_goals_sum": 0.0,
            "away_goals_sum": 0.0,
        }
    )
    team_state = defaultdict(
        lambda: {
            "overall_gf": [],
            "overall_ga": [],
            "home_gf": [],
            "home_ga": [],
            "away_gf": [],
            "away_ga": [],
        }
    )

    rows = []
    for _, r in out.iterrows():
        lid = int(r["league_id"])
        home_id = int(r["home_team_id"])
        away_id = int(r["away_team_id"])

        ls = league_state[lid]
        home_avg = (
            ls["home_goals_sum"] / ls["matches"]
            if ls["matches"] >= MIN_MATCHES_FOR_TEAM_STATE
            else FALLBACK_HOME_GOALS
        )
        away_avg = (
            ls["away_goals_sum"] / ls["matches"]
            if ls["matches"] >= MIN_MATCHES_FOR_TEAM_STATE
            else FALLBACK_AWAY_GOALS
        )

        hs = team_state[home_id]
        aw = team_state[away_id]

        def avg_or(xs: list[float], fallback: float) -> float:
            return float(np.mean(xs)) if xs else fallback

        h_att = 0.6 * avg_or(hs["home_gf"][-5:], home_avg) + 0.4 * avg_or(hs["overall_gf"][-10:], home_avg)
        h_def = 0.6 * avg_or(hs["home_ga"][-5:], away_avg) + 0.4 * avg_or(hs["overall_ga"][-10:], away_avg)
        a_att = 0.6 * avg_or(aw["away_gf"][-5:], away_avg) + 0.4 * avg_or(aw["overall_gf"][-10:], away_avg)
        a_def = 0.6 * avg_or(aw["away_ga"][-5:], home_avg) + 0.4 * avg_or(aw["overall_ga"][-10:], home_avg)

        lambda_home = float(np.clip(0.55 * h_att + 0.45 * a_def, 0.2, 3.6))
        lambda_away = float(np.clip(0.55 * a_att + 0.45 * h_def, 0.15, 3.2))

        p_away, p_draw, p_home, p_over25 = poisson_triplet_and_over(lambda_home, lambda_away)
        rows.append(
            {
                "league_home_avg": home_avg,
                "league_away_avg": away_avg,
                "lambda_home_v4": lambda_home,
                "lambda_away_v4": lambda_away,
                "p_away_pois": p_away,
                "p_draw_pois": p_draw,
                "p_home_pois": p_home,
                "p_over25_pois": p_over25,
            }
        )

        hg = float(r["home_goals"])
        ag = float(r["away_goals"])
        ls["matches"] += 1
        ls["home_goals_sum"] += hg
        ls["away_goals_sum"] += ag

        hs["overall_gf"].append(hg)
        hs["overall_ga"].append(ag)
        hs["home_gf"].append(hg)
        hs["home_ga"].append(ag)

        aw["overall_gf"].append(ag)
        aw["overall_ga"].append(hg)
        aw["away_gf"].append(ag)
        aw["away_ga"].append(hg)

    return pd.concat([out.reset_index(drop=True), pd.DataFrame(rows)], axis=1)


def blend_probs(market_probs: np.ndarray, poisson_probs: np.ndarray, weight_poisson: float) -> np.ndarray:
    w = float(weight_poisson)
    probs = (1.0 - w) * market_probs + w * poisson_probs
    probs = np.clip(probs, 1e-6, 1 - 1e-6)
    probs /= probs.sum(axis=1, keepdims=True)
    return probs
