
# -*- coding: utf-8 -*-
"""
Глобальный тренер 1X2 и Over 2.5 (anti-leak + рынок только для якорения, сглаженный Poisson)

КЛЮЧЕВЫЕ ИЗМЕНЕНИЯ В ЭТОЙ ВЕРСИИ:
- Anti-leak усилен: ВСЕ рыночные колонки исключены из обучающих фичей и используются
  только на этапе якорения (blending-to-market).
- Сплит: CAL=90 дн, VA=14 дн (стабильнее подбор δ/τ/параметров смесей).
- Порядок для 1X2: XGB/Poisson смесь -> якорение рынком -> draw-caps -> δ-сдвиг ничьей -> draw-bias.
- Ничья: eps=0.05, DRAW_CAP_ABS=0.55, DRAW_CAP_DELTA_MKT=0.30, что возвращает recall ничьи.
- Добавлены симметрийные признаки: abs_delta_* (по expected_goals, tempo, sot_rate) и abs_elo_diff.
- Poisson: K=10, λ ∈ [0.05; 4.5], регрессоры более «спокойные».
- Recency: полураспад 120 дней, floor 0.35 (чуть больше веса свежим играм).
"""

import warnings
warnings.filterwarnings("ignore")

import numpy as np
import pandas as pd
from pandas.api.types import is_numeric_dtype
from sqlalchemy import create_engine, text

from sklearn.metrics import log_loss, classification_report, brier_score_loss
from sklearn.linear_model import LogisticRegression
from sklearn.isotonic import IsotonicRegression

import xgboost as xgb
import joblib
import os

# =========================
# CONFIG
# =========================
DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"
# «рынок без ts считаем прематч» — включить, если вы уверены в чистоте витрины
MARKET_ASSUME_PREMATCH_WITHOUT_TS = True

# Топ-5 лиг
LEAGUE_IDS = [39, 61, 78, 135, 140]

# Источник коэффициентов
ODDS_VIEW_NAME_PRIMARY = "football.v_ml_epl_training"
ODDS_VIEW_NAME_FALLBACK = None

RANDOM_SEED = 42
np.random.seed(RANDOM_SEED)
engine = create_engine(DB_URL)

# ---------- Стабильность / Диагностика ----------
NOW_USE_SCHED_MAX = True
NOW_OVERRIDE = None
FREEZE_CALIB = False
DEBUG_EXPORT = True
DEBUG_OUT_OUTCOMES = "debug_outcomes_breakdown.csv"
DEBUG_OUT_TOTALS   = "debug_totals_breakdown.csv"

# Роллинги
ROLL_N = 5
ROLL_N_SHORT = 3
DECAY_H2H = 0.85

# Elo
ELO_INIT = 1500.0
ELO_HOME_ADV = 60.0

# Контроль ничьей
DRAW_BETA_PRIOR = 0.25
DRAW_CAP_ABS = 0.55          # ↑ было 0.50
DRAW_CAP_DELTA_MKT = 0.30    # ↑ было 0.22

# «Якорь» к рынку
ALPHA_MKT_FLOOR_TOT = 0.40
ALPHA_MKT_FLOOR_OUT = 0.05

# «Свежесть»
RECENCY_HALFLIFE_DAYS = 120  # ↓ было 180
RECENCY_FLOOR = 0.35         # ↑ было 0.30
RECENCY_CAP = 3.0

# Сплиты
CAL_DAYS = 90  # ↑ было 50
VA_DAYS = 14
LEAGUE_CAL_MIN = 12
LEAGUE_VA_MIN = 6
   # ↓ было 21
GAP_DAYS = 0

# Пороги
TEMP_MIN_N = 20
ALPHA_MIN_N = 20
TAU_MIN_N = 20

# τ бонусы по лигам
TAU_DRAW_BONUS_BY_LID = {39: 1.03, 78: 1.05}

# Файлы моделей/важностей
OUT_FILE_RES = "xgb_outcome_final_safe.pkl"
OUT_FILE_TOT = "xgb_over25_final_safe.pkl"
FI_OUT_HA = "feature_importance_outcomes_ha.csv"
FI_OUT_DR = "feature_importance_outcomes_draw.csv"
FI_TOT    = "feature_importance_totals.csv"

_GLOBAL_NOW_TS = None

# Poisson сглаживание
POISSON_K = 10                  # ↓ было 12
POISSON_LAMBDA_MIN = 0.05       # ↑ 0.02 -> 0.05
POISSON_LAMBDA_MAX = 4.5        # ↓ 6.0 -> 4.5

# =========================
# UTILS
# =========================
def league_mask_bool(df: pd.DataFrame, lid: int) -> np.ndarray:
    arr = pd.to_numeric(df["league_id"], errors="coerce")
    return (arr == int(lid)).to_numpy()

def coalesce_two(df: pd.DataFrame, base_col: str) -> pd.DataFrame:
    cx, cy = base_col + "_x", base_col + "_y"
    if cx in df.columns or cy in df.columns:
        df[base_col] = df.get(cx, df.get(base_col))
        if cy in df.columns:
            df[base_col] = df[base_col].where(df[base_col].notna(), df[cy])
        for c in (cx, cy):
            if c in df.columns: df.drop(columns=c, inplace=True)
    return df

def safe_log_loss(y_true, proba, labels=None):
    y_true = np.asarray(y_true)
    if proba.ndim == 1:
        if labels is None: labels = [0,1]
        try:
            return float(log_loss(y_true, proba, labels=labels))
        except ValueError:
            p = np.mean(y_true==1) if len(y_true)>0 else 0.5
            return float(-(p*np.log(p+1e-12)+(1-p)*np.log(1-p+1e-12)))
    else:
        if labels is None:
            k = proba.shape[1]; labels = list(range(k))
        try:
            return float(log_loss(y_true, proba, labels=labels))
        except ValueError:
            counts = np.bincount(y_true, minlength=len(labels))
            p = counts/np.sum(counts) if counts.sum()>0 else np.ones(len(labels))/len(labels)
            P = np.tile(p, (len(y_true),1))
            return float(log_loss(y_true, P, labels=labels))

def safe_acc(y_true, y_pred):
    y_true = np.asarray(y_true); y_pred = np.asarray(y_pred)
    if len(y_true)==0: return float("nan")
    return float((y_true==y_pred).mean())

def _ema(s: pd.Series, span=5):
    return s.shift(1).ewm(span=span, adjust=False, min_periods=1).mean()

def _slope_last_n(s: pd.Series, n=5):
    def fit_slope(x):
        if len(x) < 2: return np.nan
        idx = np.arange(len(x))
        try: return np.polyfit(idx, x, 1)[0]
        except Exception: return np.nan
    return s.shift(1).rolling(n, min_periods=2).apply(fit_slope, raw=False)

def best_ntree_limit(booster):
    if hasattr(booster, "best_ntree_limit") and booster.best_ntree_limit is not None:
        return int(booster.best_ntree_limit)
    if hasattr(booster, "best_iteration") and booster.best_iteration is not None:
        return int(booster.best_iteration) + 1
    try:
        attrs = booster.attributes()
        if "best_iteration" in attrs and attrs["best_iteration"] is not None:
            return int(attrs["best_iteration"]) + 1
    except Exception:
        pass
    return None

def predict_best(booster, dmatrix, n_best):
    if n_best is None:
        return booster.predict(dmatrix)
    try:
        return booster.predict(dmatrix, iteration_range=(0, int(n_best)))
    except TypeError:
        pass
    try:
        return booster.predict(dmatrix, ntree_limit=int(n_best))
    except TypeError:
        pass
    return booster.predict(dmatrix)

def safe_div(a, b):
    a = pd.to_numeric(a, errors="coerce")
    b = pd.to_numeric(b, errors="coerce")
    return np.where((b==0) | (~np.isfinite(b)), np.nan, a / b)

def _logit(p):
    p = np.clip(p,1e-6,1-1e-6); return np.log(p/(1-p))
def _sigmoid(x): return 1.0/(1.0+np.exp(-x))
def sanitize_prob(x):
    x = np.array(x, dtype="float64")
    x = np.nan_to_num(x, nan=0.5, posinf=0.999999, neginf=1e-6)
    return np.clip(x, 1e-6, 1-1e-6)

def dynamic_alpha(overround_arr, nbk_arr, sum_lambda_arr=None, floor=0.10, ceil=0.65):
    orr = pd.to_numeric(overround_arr, errors="coerce").astype("float64")
    nbk = pd.to_numeric(nbk_arr, errors="coerce").astype("float64")
    inv_orr = 1.0 / np.clip(orr, 1.01, 1.25)
    ln_nbk = np.log1p(np.clip(nbk, 0, 50))
    if sum_lambda_arr is None:
        z = -1.1 + 3.2 * inv_orr + 0.25 * ln_nbk
    else:
        sL = pd.to_numeric(sum_lambda_arr, errors="coerce").astype("float64")
        z = -1.1 + 3.2 * inv_orr + 0.25 * ln_nbk - 0.18 * np.clip(sL, 0, 5)
    a = 1.0 / (1.0 + np.exp(-z))
    return np.clip(a, floor, ceil)


# =========================
# Строгий anti-leak по колонкам
# =========================
SAFE_AGGR_SUFFIXES = ("_mean_", "_std_", "_ema_", "_slope_", "_sum_", "_avg_")
MARKET_TOKENS = ("avg_odds", "imp_", "p_home_norm", "p_draw_norm", "p_away_norm",
                 "overround_1x2", "n_bookmakers", "p_over_mkt")

def strict_drop_goalish_columns(df: pd.DataFrame, keep_basic_results=True) -> pd.DataFrame:
    df = df.copy()
    raw = [
        "home_goals_x","home_goals_y","away_goals_x","away_goals_y",
        "score","score_ft","score_ht","score_total",
        "ft_home_goals","ft_away_goals","goals_home","goals_away","goals_total"
    ]
    if not keep_basic_results:
        raw += ["home_goals","away_goals"]
    drop = [c for c in raw if c in df.columns]
    if drop:
        df.drop(columns=drop, inplace=True, errors="ignore")
        print(f"[LEAK-GUARD] Dropped raw goal columns: {drop}")

    sus = []
    for c in df.columns:
        lc = c.lower()
        if ("goal" in lc or "score" in lc):
            if c in ("target_result","target_over25","home_goals","away_goals"):
                continue
            if not any(sfx in lc for sfx in SAFE_AGGR_SUFFIXES):
                sus.append(c)
    if sus:
        df.drop(columns=list(set(sus)), inplace=True, errors="ignore")
        print(f"[LEAK-GUARD] Dropped suspicious goal/score columns: {sorted(set(sus))}")
    return df

def build_feature_cols(df_like: pd.DataFrame, extra_drops=None):
    """
    Возвращает безопасный список фич:
    - только числовые
    - без служебных и таргетов
    - без goal/score (если не агрегаты)
    - БЕЗ любых рыночных колонок (avg_odds_*, imp_*, *_norm, overround_1x2, n_bookmakers)
    """
    non_feats = {
        "fixture_id","date_utc","season","league_id","home_team_id","away_team_id",
        "home_goals","away_goals","target_result","target_over25","has_result"
    }
    if extra_drops:
        non_feats |= set(extra_drops)

    num_cols = [c for c in df_like.columns if is_numeric_dtype(df_like[c])]
    feats = []
    for c in num_cols:
        if c in non_feats:
            continue
        lc = c.lower()

        # выкидываем рынок из фичей
        if any(tok in lc for tok in MARKET_TOKENS):
            continue

        # выкидываем goal/score если не агрегаты
        if ("goal" in lc or "score" in lc):
            if not any(sfx in lc for sfx in SAFE_AGGR_SUFFIXES):
                continue
        feats.append(c)
    return sorted(feats)

# Доп. страховка от «проскочивших» утечек: выкинуть фичи с |corr| к таргету >= thr на CAL.
def _drop_suspicious_corr_features(df_like, feature_cols, target_col, thr=0.98):
    safe = []
    y = pd.to_numeric(df_like[target_col], errors="coerce")
    for c in feature_cols:
        try:
            x = pd.to_numeric(df_like[c], errors="coerce")
            corr = abs(pd.Series(x).corr(pd.Series(y)))
            if np.isnan(corr) or corr < thr:
                safe.append(c)
            else:
                print(f"[LEAK-GUARD] Drop '{c}' due to |corr|={corr:.3f} with {target_col}")
        except Exception:
            safe.append(c)
    return safe

# =========================
# PRIORS (safe)
# =========================
def compute_league_draw_prior(sched: pd.DataFrame, recent_days: int = 365) -> pd.DataFrame:
    df = sched.sort_values("date_utc").copy()
    df["date_utc"] = pd.to_datetime(df["date_utc"], utc=True)
    known = df[~df["home_goals"].isna() & ~df["away_goals"].isna()].copy()
    known["is_draw"] = (known["home_goals"] == known["away_goals"]).astype("float32")
    out_rows = []
    for lid, g in df.groupby("league_id", sort=False):
        g = g.sort_values("date_utc").reset_index(drop=True)
        k = known[known["league_id"] == lid].sort_values("date_utc")
        vals = []
        for d_i in g["date_utc"]:
            start = d_i - pd.Timedelta(days=recent_days)
            window = k[(k["date_utc"] < d_i) & (k["date_utc"] >= start)]
            vals.append(float(window["is_draw"].mean()) if not window.empty else np.nan)
        out_rows.append(pd.DataFrame({"fixture_id": g["fixture_id"].values, "league_draw_prior": vals}))
    out = pd.concat(out_rows, ignore_index=True) if out_rows else pd.DataFrame(columns=["fixture_id","league_draw_prior"])
    out["league_draw_prior"] = out["league_draw_prior"].fillna(0.26).astype("float32")
    return out

def compute_league_over25_prior(sched: pd.DataFrame) -> pd.DataFrame:
    df = sched[["fixture_id", "league_id", "date_utc", "home_goals", "away_goals"]].copy()
    df["date_utc"] = pd.to_datetime(df["date_utc"], utc=True, errors="coerce")
    df = df.sort_values(["league_id", "date_utc"]).reset_index(drop=True)
    known = (~df["home_goals"].isna()) & (~df["away_goals"].isna())
    total_goals = pd.to_numeric(df["home_goals"], errors="coerce") + pd.to_numeric(df["away_goals"], errors="coerce")
    is_over = (total_goals >= 3).astype("int64").where(known, 0)
    grp = df["league_id"]
    sum_prev = is_over.groupby(grp).cumsum().shift(1)
    cnt_prev = known.astype("int64").groupby(grp).cumsum().shift(1)
    prior = (sum_prev / cnt_prev).astype("float32").fillna(0.52)
    return pd.DataFrame({"fixture_id": df["fixture_id"].values, "league_over25_prior": prior.values})

# =========================
# LOAD (+ sanity checks)
# =========================
def _load_odds_view(conn, lids):
    def _try(name):
        if not name:
            return None
        try:
            return pd.read_sql(text(f"SELECT * FROM {name} WHERE league_id IN :lids"),
                               conn, params={"lids": tuple(lids)})
        except Exception:
            return None
    df = _try(ODDS_VIEW_NAME_PRIMARY)
    if df is None and ODDS_VIEW_NAME_FALLBACK:
        df = _try(ODDS_VIEW_NAME_FALLBACK)
    if df is None:
        cols = ["fixture_id","n_bookmakers","avg_odds_home","avg_odds_draw","avg_odds_away",
                "avg_odds_over25","avg_odds_under25","imp_home_raw","imp_draw_raw","imp_away_raw",
                "overround_1x2","p_home_norm","p_draw_norm","p_away_norm","p_over_mkt","league_id","odds_ts"]
        return pd.DataFrame(columns=cols)
    return df

def load_data():
    with engine.connect() as conn:
        sched = pd.read_sql(
            text("""
                SELECT fixture_id, date::timestamp as date_utc, season, league_id,
                       home_team_id, away_team_id, home_goals, away_goals
                FROM football.api_football_schedule
                WHERE league_id IN :lids
                ORDER BY date
            """),
            conn, params={"lids": tuple(LEAGUE_IDS)}
        )
        stats = pd.read_sql(
            text("""
                SELECT fixture_id, team_id,
                       shots_on_goal, shots_off_goal, total_shots, blocked_shots,
                       shots_insidebox, shots_outsidebox, possession, passes, passes_accurate,
                       passes_percentage, fouls, corners, offsides, yellow_cards, red_cards,
                       saves, tackles, attacks, dangerous_attacks, expected_goals, goals_prevented
                FROM football.api_football_match_stats
            """), conn
        )
        injuries = pd.read_sql(
            text("""
                SELECT injury_uid, player_id, team_id,
                       fixture_id, fixture_date,
                       injury_type, injury_reason
                FROM football.api_football_injuries
            """), conn
        )
        odds_view = _load_odds_view(conn, LEAGUE_IDS)
    return sched, stats, injuries, odds_view

def _sanity_checks(sched: pd.DataFrame, injuries: pd.DataFrame, odds_view: pd.DataFrame):
    try:
        if not injuries.empty:
            inj_m = injuries.merge(sched[["fixture_id","date_utc"]], on="fixture_id", how="inner")
            inj_m["fixture_date"] = pd.to_datetime(inj_m["fixture_date"], utc=True, errors="coerce")
            inj_m["date_utc"] = pd.to_datetime(inj_m["date_utc"], utc=True, errors="coerce")
            bad_idx = inj_m.index[inj_m["fixture_date"] > inj_m["date_utc"]]
            if len(bad_idx) > 0:
                sample = inj_m.loc[bad_idx, ["fixture_id","fixture_date","date_utc"]].head(5)
                print(f"[SANITY] Injuries after kickoff: {len(bad_idx)} rows (showing first 5):")
                print(sample.to_string(index=False))
    except Exception as e:
        print(f"[SANITY] Injuries check error: {e}")
    try:
        if "odds_ts" in odds_view.columns and not odds_view.empty:
            ov = odds_view.merge(sched[["fixture_id","date_utc"]], on="fixture_id", how="inner")
            ov["odds_ts"] = pd.to_datetime(ov["odds_ts"], utc=True, errors="coerce")
            ov["date_utc"] = pd.to_datetime(ov["date_utc"], utc=True, errors="coerce")
            bad = ov["odds_ts"] > ov["date_utc"]
            if bad.any():
                n_bad = int(bad.sum())
                sample = ov.loc[bad, ["fixture_id","odds_ts","date_utc"]].head(5)
                print(f"[SANITY] Odds timestamps after kickoff: {n_bad} rows (showing first 5):")
                print(sample.to_string(index=False))
    except Exception as e:
        print(f"[SANITY] Odds check error: {e}")

# =========================
# ELO / FORM / INJURIES / H2H
# =========================
def elo_expected(r_a, r_b, home_adv=0.0):
    ea = 1.0 / (1.0 + 10 ** ((r_b - (r_a + home_adv)) / 400.0))
    eb = 1.0 - ea
    return ea, eb

def dyn_k(games_played):
    if games_played < 10: return 28.0
    if games_played < 20: return 22.0
    return 18.0

def compute_elo(sched: pd.DataFrame) -> pd.DataFrame:
    df = sched.sort_values("date_utc").copy()
    ratings, games_cnt = {}, {}
    pre_h, pre_a = [], []
    for _, r in df.iterrows():
        h, a = int(r.home_team_id), int(r.away_team_id)
        rh, ra = ratings.get(h, ELO_INIT), ratings.get(a, ELO_INIT)
        pre_h.append(rh); pre_a.append(ra)
        hg, ag = r.home_goals, r.away_goals
        if pd.isna(hg) or pd.isna(ag): continue
        sh, sa = (1.0, 0.0) if hg > ag else (0.5, 0.5) if hg == ag else (0.0, 1.0)
        eh, ea = elo_expected(rh, ra, home_adv=ELO_HOME_ADV)
        kh, ka = dyn_k(games_cnt.get(h, 0)), dyn_k(games_cnt.get(a, 0))
        ratings[h] = rh + kh * (sh - eh); games_cnt[h] = games_cnt.get(h, 0) + 1
        ratings[a] = ra + ka * (sa - ea); games_cnt[a] = games_cnt.get(a, 0) + 1
    df["elo_home_pre"], df["elo_away_pre"] = pre_h, pre_a
    df["elo_diff"] = df["elo_home_pre"] - df["elo_away_pre"]
    ph, pa = [], []
    for _, r in df.iterrows():
        eh, ea = elo_expected(r.elo_home_pre, r.elo_away_pre, home_adv=ELO_HOME_ADV)
        ph.append(eh); pa.append(ea)
    df["p_home_elo"] = np.array(ph, dtype="float32")
    df["p_away_elo"] = np.array(pa, dtype="float32")
    return df[["fixture_id","elo_home_pre","elo_away_pre","elo_diff","p_home_elo","p_away_elo"]]

FORM_NUM_COLS = [
    "possession","shots_on_goal","shots_off_goal","total_shots","blocked_shots",
    "shots_insidebox","shots_outsidebox","fouls","corners","offsides","yellow_cards",
    "red_cards","saves","tackles","attacks","dangerous_attacks","expected_goals","goals_prevented",
]

def compute_points_table(sched: pd.DataFrame) -> pd.DataFrame:
    rows=[]
    for _, r in sched.iterrows():
        fid=r.fixture_id
        if pd.isna(r.home_goals) or pd.isna(r.away_goals):
            pts_h=gf_h=ga_h=np.nan; pts_a=gf_a=ga_a=np.nan
        else:
            pts_h = 3 if r.home_goals>r.away_goals else 1 if r.home_goals==r.away_goals else 0
            gf_h, ga_h = r.home_goals, r.away_goals
            pts_a = 3 if r.away_goals>r.home_goals else 1 if r.away_goals==r.home_goals else 0
            gf_a, ga_a = r.away_goals, r.home_goals
        rows.append([fid,r.home_team_id,r.date_utc,pts_h,gf_h,ga_h,1])
        rows.append([fid,r.away_team_id,r.date_utc,pts_a,gf_a,ga_a,0])
    return pd.DataFrame(rows, columns=["fixture_id","team_id","match_date","points","goals_for","goals_against","is_home"])

def compute_form_enhanced(stats: pd.DataFrame, sched: pd.DataFrame, n=ROLL_N, n_short=ROLL_N_SHORT) -> pd.DataFrame:
    agg = stats.groupby(["fixture_id","team_id"], as_index=False)[FORM_NUM_COLS].mean()
    agg["sot_rate"]    = safe_div(agg["shots_on_goal"], agg["total_shots"]).astype("float32")
    agg["xg_per_shot"] = safe_div(agg["expected_goals"], agg["total_shots"]).astype("float32")
    agg["tempo"] = agg["total_shots"].fillna(0) + 0.5*agg["dangerous_attacks"].fillna(0)
    pts = compute_points_table(sched)
    base = pts.merge(agg, on=["fixture_id","team_id"], how="left")
    if "match_date" not in base.columns:
        if "match_date_x" in base.columns or "match_date_y" in base.columns:
            base = coalesce_two(base, "match_date")
        elif "date_utc" in base.columns:
            base = base.rename(columns={"date_utc":"match_date"})
        else:
            raise RuntimeError("compute_form_enhanced(): нет match_date")
    base["match_date"] = pd.to_datetime(base["match_date"])
    frames=[]
    for tid, g in base.sort_values("match_date").groupby("team_id", sort=False):
        g=g.reset_index(drop=True)
        out=g[["fixture_id","team_id","match_date","is_home"]].copy()
        metrics = ["goals_for", "goals_against", "expected_goals", "tempo", "sot_rate", "xg_per_shot", "points"]
        for c in metrics:
            g[f"{c}_mean_{n}"] = g[c].shift(1).rolling(n, min_periods=1).mean()
            g[f"{c}_std_{n}"] = g[c].shift(1).rolling(n, min_periods=2).std()
            g[f"{c}_ema_{n}"] = _ema(g[c], span=n)
            g[f"{c}_slope_{n}"] = _slope_last_n(g[c], n=n)
            g[f"{c}_sum_{n_short}"] = g[c].shift(1).rolling(n_short, min_periods=1).sum()
        mask_home = (g["is_home"] == 1); mask_away = ~mask_home
        def masked_roll(col, mask, fn="mean", w=n):
            s = g[col].where(mask).shift(1)
            if fn == "mean": return s.rolling(w, min_periods=1).mean()
            if fn == "std": return s.rolling(w, min_periods=2).std()
            if fn == "ema": return s.ewm(span=w, adjust=False, min_periods=1).mean()
            if fn == "sum3": return s.rolling(n_short, min_periods=1).sum()
            if fn == "slope":
                return s.rolling(w, min_periods=2).apply(
                    lambda x: np.polyfit(np.arange(len(x)), x, 1)[0] if len(x)>=2 else np.nan, raw=False)
            return s
        for c in metrics:
            g[f"{c}_home_mean_{n}"] = masked_roll(c, mask_home, "mean", n)
            g[f"{c}_home_std_{n}"] = masked_roll(c, mask_home, "std", n)
            g[f"{c}_home_ema_{n}"] = masked_roll(c, mask_home, "ema", n)
            g[f"{c}_home_slope_{n}"] = masked_roll(c, mask_home, "slope", n)
            g[f"{c}_home_sum_{n_short}"] = masked_roll(c, mask_home, "sum3", n)
            g[f"{c}_away_mean_{n}"] = masked_roll(c, mask_away, "mean", n)
            g[f"{c}_away_std_{n}"] = masked_roll(c, mask_away, "std", n)
            g[f"{c}_away_ema_{n}"] = masked_roll(c, mask_away, "ema", n)
            g[f"{c}_away_slope_{n}"] = masked_roll(c, mask_away, "slope", n)
            g[f"{c}_away_sum_{n_short}"] = masked_roll(c, mask_away, "sum3", n)
        carry=[c for c in g.columns if any(tag in c for tag in (f"_mean_{n}",f"_std_{n}",f"_ema_{n}",f"_slope_{n}",f"_sum_{ROLL_N_SHORT}"))]
        out = out.join(g[carry])
        frames.append(out)
    form = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()
    home = form.rename(columns={c: f"home_{c}" for c in form.columns if c not in ["fixture_id","team_id","match_date","is_home"]})
    away = form.rename(columns={c: f"away_{c}" for c in form.columns if c not in ["fixture_id","team_id","match_date","is_home"]})
    dfH = sched.merge(home, left_on=["fixture_id","home_team_id"], right_on=["fixture_id","team_id"], how="left").drop(columns=["team_id"])
    dfA = sched.merge(away, left_on=["fixture_id","away_team_id"], right_on=["fixture_id","team_id"], how="left").drop(columns=["team_id"])
    use_cols_away = ["fixture_id"] + [c for c in dfA.columns if c.startswith("away_")]
    return dfH.merge(dfA[use_cols_away], on="fixture_id", how="left")

REASONS_TOP = ["Suspended","Red Card","Yellow Cards","International duty","Personal Reasons","Illness",
               "Hamstring Injury","Knee Injury","Ankle Injury","Muscle Injury"]

def compute_injury_features_pre(inj: pd.DataFrame, sched: pd.DataFrame, window_days: int = 21) -> pd.DataFrame:
    df = inj.copy()
    df["fixture_date"] = pd.to_datetime(df["fixture_date"], errors="coerce", utc=True)
    df = df.dropna(subset=["fixture_date", "team_id"]).copy()
    df["injury_reason"] = df["injury_reason"].fillna("Other")
    df = df[df["injury_reason"].isin(REASONS_TOP)].copy()

    pairs = pd.concat([
        sched[["fixture_id", "date_utc", "home_team_id"]].rename(columns={"home_team_id": "team_id"}),
        sched[["fixture_id", "date_utc", "away_team_id"]].rename(columns={"away_team_id": "team_id"}),
    ], ignore_index=True)
    pairs["date_utc"] = pd.to_datetime(pairs["date_utc"], errors="coerce", utc=True)

    rows = []
    window = pd.Timedelta(days=window_days)
    for _, r in pairs.iterrows():
        if pd.isna(r.team_id) or pd.isna(r.fixture_id) or pd.isna(r.date_utc):
            continue
        fid = int(r.fixture_id)
        tid = int(r.team_id)
        match_datetime = (pd.Timestamp(r.date_utc)
                          if isinstance(r.date_utc, pd.Timestamp)
                          else pd.to_datetime(r.date_utc, utc=True))
        start = match_datetime - window
        sub = df[(df["team_id"] == tid) &
                 (df["fixture_date"] >= start) &
                 (df["fixture_date"] < match_datetime)]
        total = float(len(sub))
        if not sub.empty:
            type_cnt = sub.groupby("injury_type")["injury_uid"].count().rename(
                lambda c: f"inj_{str(c).lower().replace(' ', '_')}_cnt")
        else:
            type_cnt = pd.Series(dtype=float)
        rec = {"fixture_id": fid, "team_id": tid, "inj_total_cnt": total}
        rec.update(type_cnt.to_dict())
        rows.append(rec)

    out = pd.DataFrame(rows)
    for c in out.columns:
        if c not in ("fixture_id", "team_id"):
            out[c] = pd.to_numeric(out[c], errors="coerce").fillna(0).astype("float32")
    return out

def compute_h2h(sched: pd.DataFrame, n=ROLL_N, decay=DECAY_H2H) -> pd.DataFrame:
    df=sched.sort_values("date_utc").copy()
    df["pair_key"]=list(zip(np.minimum(df.home_team_id, df.away_team_id), np.maximum(df.home_team_id, df.away_team_id)))
    rows=[]
    for _, g in df.groupby("pair_key"):
        g=g.sort_values("date_utc").reset_index(drop=True)
        for i, r in g.iterrows():
            prev=g.loc[:i-1].tail(n)
            if prev.empty:
                rows.append([r.fixture_id, np.nan, np.nan, np.nan, 0, np.nan]); continue
            home_id, away_id = r.home_team_id, r.away_team_id
            w=d=gf=ga=0.0; m=len(prev)
            for idx, pr in enumerate(prev.itertuples(index=False)):
                if pd.isna(pr.home_goals) or pd.isna(pr.away_goals): continue
                factor = decay ** (m-1-idx)
                if pr.home_team_id==home_id and pr.away_team_id==away_id:
                    hg, ag = pr.home_goals, pr.away_goals
                elif pr.home_team_id==away_id and pr.away_team_id==home_id:
                    hg, ag = pr.away_goals, pr.home_goals
                else:
                    if pr.home_team_id==home_id:
                        hg, ag = pr.home_goals, pr.away_goals
                    else:
                        hg, ag = pr.away_goals, pr.home_goals
                gf += factor*hg; ga += factor*ag
                if hg>ag: w+=factor
                elif hg==ag: d+=factor
            norm=max(1e-6, w+d+ (m - (w+d)))
            rows.append([r.fixture_id, w/norm, (gf-ga)/norm, (gf+ga)/norm, len(prev), d/norm])
    return pd.DataFrame(rows, columns=[
        "fixture_id","h2h_winrate_home_lastN","h2h_gdiff_avg_lastN","h2h_goals_avg_lastN","h2h_games_cnt","h2h_drawrate_lastN"
    ])

# =========================
# BUILD DATASET
# =========================
def ensure_match_keys(base: pd.DataFrame, sched: pd.DataFrame) -> pd.DataFrame:
    keys = sched[["fixture_id","home_team_id","away_team_id","league_id","season"]].drop_duplicates("fixture_id")
    for c in ["home_team_id","away_team_id","league_id","season"]:
        base = coalesce_two(base, c)
    need = [c for c in ["home_team_id","away_team_id","league_id","season"] if c not in base.columns]
    if need:
        base = base.merge(keys, on="fixture_id", how="left", suffixes=("", "_sched"))
        for c in ["home_team_id","away_team_id","league_id","season"]:
            cs=f"{c}_sched"
            if cs in base.columns:
                if c not in base.columns: base[c]=base[cs]
                else: base[c]=base[c].where(base[c].notna(), base[cs])
                base.drop(columns=[cs], inplace=True, errors="ignore")
    for c in ["home_team_id","away_team_id","league_id","season"]:
        if c in base.columns:
            base[c]=pd.to_numeric(base[c], errors="coerce")
    return base

def _prematch_odds_one_per_fixture(odds: pd.DataFrame, sched: pd.DataFrame) -> pd.DataFrame:
    if odds.empty:
        return odds
    df = odds.copy()

    if "odds_ts" in df.columns:
        df["odds_ts"] = pd.to_datetime(df["odds_ts"], utc=True, errors="coerce")
        if df["odds_ts"].isna().all():
            print("[MARKET] odds_ts пуст/NaT -> перейду к режиму без ts (см. флаг MARKET_ASSUME_PREMATCH_WITHOUT_TS).")
        else:
            key = sched[["fixture_id","date_utc"]].copy()
            key["date_utc"] = pd.to_datetime(key["date_utc"], utc=True, errors="coerce")
            df = df.merge(key, on="fixture_id", how="left")
            df = df[df["odds_ts"].notna() & df["date_utc"].notna()]
            df = df[df["odds_ts"] <= df["date_utc"]]
            if df.empty:
                return pd.DataFrame(columns=[c for c in odds.columns if c != "date_utc"])
            idx = df.sort_values(["fixture_id","odds_ts"]).groupby("fixture_id").tail(1).index
            return df.loc[idx].drop(columns=["date_utc"])

    cols = [c for c in odds.columns if c != "date_utc"]
    unique_fixture_ids = pd.Series(df["fixture_id"].unique(), name="fixture_id")

    if not MARKET_ASSUME_PREMATCH_WITHOUT_TS:
        print("[MARKET] odds_ts missing (MARKET_ASSUME_PREMATCH_WITHOUT_TS=False) -> odds features set to NaN.")
        base = unique_fixture_ids.to_frame()
        for c in cols:
            if c != "fixture_id":
                base[c] = np.nan
        return base

    print("[MARKET] odds_ts not available; aggregating pre-match odds per fixture.")
    agg_spec = {}
    for c in df.columns:
        if c == "fixture_id":
            continue
        lc = c.lower()
        if c == "league_id":
            agg_spec[c] = "first"
        elif c == "n_bookmakers":
            agg_spec[c] = "max"
        elif any(tok in lc for tok in ["odds","imp_","p_home_norm","p_draw_norm","p_away_norm","p_over_mkt","overround_1x2"]):
            agg_spec[c] = "mean"
        else:
            agg_spec[c] = "first"
    prematch = df.groupby("fixture_id", as_index=False).agg(agg_spec)
    if "date_utc" in prematch.columns:
        prematch = prematch.drop(columns=["date_utc"], errors="ignore")
    prematch = prematch.merge(unique_fixture_ids.to_frame(), on="fixture_id", how="right")
    cols_no_fixture = [c for c in cols if c != "fixture_id"]
    for c in cols_no_fixture:
        if c not in prematch.columns:
            prematch[c] = np.nan
    ordered_cols = ["fixture_id"] + cols_no_fixture
    prematch = prematch[[c for c in ordered_cols if c in prematch.columns]]
    return prematch



def apply_draw_logit_shift(P: np.ndarray, delta: float = 0.0) -> np.ndarray:
    P = np.asarray(P, dtype="float64")
    if P.ndim != 2 or P.shape[1] != 3 or delta == 0.0:
        P = np.clip(P, 1e-6, 1-1e-6)
        P /= P.sum(axis=1, keepdims=True)
        return P
    out = P.copy()
    out[:, 1] = out[:, 1] * np.exp(float(delta))
    out = np.clip(out, 1e-6, 1-1e-6)
    out /= out.sum(axis=1, keepdims=True)
    return out

def _f1_for_draw(y_true_3: np.ndarray, pred_3: np.ndarray) -> float:
    y = np.asarray(y_true_3, dtype=int)
    p = np.asarray(pred_3, dtype=int)
    tp = int(np.sum((y == 1) & (p == 1)))
    fp = int(np.sum((y != 1) & (p == 1)))
    fn = int(np.sum((y == 1) & (p != 1)))
    prec = tp / max(1, (tp + fp))
    rec  = tp / max(1, (tp + fn))
    return (2 * prec * rec / max(1e-12, (prec + rec))) if (prec + rec) > 0 else 0.0

def tune_draw_shift_on_cal(y_cal_3: np.ndarray, P_cal_after_caps_anchor: np.ndarray,
                           grid: np.ndarray = None) -> float:
    """
    Подбор delta на CAL ПОСЛЕ якорения и капов (смещаем ничью уже на «реальных» вероятностях).
    """
    if grid is None:
        grid = np.linspace(0.00, 0.50, 11)  # 0..0.5 шаг 0.05
    best_delta, best_f1, best_ll = 0.0, -1.0, 1e9
    for d in grid:
        Pc = apply_draw_logit_shift(P_cal_after_caps_anchor, d)
        pred = Pc.argmax(axis=1)
        f1d = _f1_for_draw(y_cal_3, pred)
        lld = safe_log_loss(y_cal_3, Pc, labels=[0,1,2])
        if (f1d > best_f1) or (np.isclose(f1d, best_f1) and lld < best_ll):
            best_delta, best_f1, best_ll = float(d), float(f1d), float(lld)
    print(f"[OUT] Tuned draw-delta (POST-anchor/caps) on CAL: delta={best_delta:.2f}  F1_draw={best_f1:.3f}  LL={best_ll:.4f}")
    return best_delta

def argmax_with_draw_bias(P: np.ndarray, eps: float = 0.05) -> np.ndarray:
    """
    Если ничья почти равна максимуму — выбрать ничью (eps=0.05 слегка повышает recall ничьи).
    """
    P = np.asarray(P, dtype="float64")
    pA, pD, pH = P[:,0], P[:,1], P[:,2]
    best_nonD = np.maximum(pA, pH)
    choose_draw = pD >= (best_nonD - float(eps))
    pred = P.argmax(axis=1)
    pred[choose_draw] = 1
    return pred

def build_dataset(return_all: bool = False) -> pd.DataFrame:
    global _GLOBAL_NOW_TS
    sched, stats, injuries, odds_view = load_data()
    _sanity_checks(sched, injuries, odds_view)

    base = sched.copy()
    base = ensure_match_keys(base, sched)

    # ---- ФИКС "now": только по РЕЗУЛЬТАТАМ
    known_mask = sched["home_goals"].notna() & sched["away_goals"].notna()
    _GLOBAL_NOW_TS = pd.to_datetime(sched.loc[known_mask, "date_utc"], utc=True, errors="coerce").max()

    # Elo
    elo = compute_elo(sched)
    base = base.merge(elo, on="fixture_id", how="left")

    # Form
    sched_form = compute_form_enhanced(stats, sched, n=ROLL_N, n_short=ROLL_N_SHORT)
    sched_form = sched_form.drop(columns=["home_team_id","away_team_id","league_id","season","date_utc","home_goals","away_goals"], errors="ignore")
    base = base.merge(sched_form, on="fixture_id", how="left")
    base = ensure_match_keys(base, sched)

    # H2H
    h2h = compute_h2h(sched, n=ROLL_N, decay=DECAY_H2H)
    base = base.merge(h2h, on="fixture_id", how="left")

    # Priors
    lprior_d = compute_league_draw_prior(sched, recent_days=365)
    lprior_o = compute_league_over25_prior(sched)
    base = base.merge(lprior_d, on="fixture_id", how="left")
    base = base.merge(lprior_o, on="fixture_id", how="left")

    # Injuries pre
    inj_feats = compute_injury_features_pre(injuries, sched)
    injH = inj_feats.rename(columns={c:f"home_{c}" for c in inj_feats.columns if c not in ("fixture_id","team_id")})
    injA = inj_feats.rename(columns={c:f"away_{c}" for c in inj_feats.columns if c not in ("fixture_id","team_id")})
    base = (
        base.merge(injH, left_on=["fixture_id","home_team_id"], right_on=["fixture_id","team_id"], how="left")
            .drop(columns=["team_id"], errors="ignore")
            .merge(injA, left_on=["fixture_id","away_team_id"], right_on=["fixture_id","team_id"], how="left")
            .drop(columns=["team_id"], errors="ignore")
    )

    # date_utc
    if "date_utc" not in base.columns:
        base = base.merge(sched[['fixture_id','date_utc']], on="fixture_id", how="left")
    base["date_utc"] = pd.to_datetime(base["date_utc"], errors="coerce", utc=True)

    # calendar density
    def side_features(side):
        tid=f"{side}_team_id"; prefix=side
        g = base[["fixture_id","date_utc",tid]].rename(columns={tid:"team_id"}).sort_values(["team_id","date_utc"]).reset_index(drop=True)
        g["prev_date"] = g.groupby("team_id")["date_utc"].shift(1)
        g[f"{prefix}_days_since"]=(g["date_utc"]-g["prev_date"]).dt.days.astype("float32")
        def rolling_count(s, window_days):
            s=s.copy(); s.index=pd.to_datetime(s)
            return pd.Series(1.0, index=s.index).shift(1).rolling(f"{window_days}D").sum().values
        g[f"{prefix}_matches_7d"] = g.groupby("team_id")["date_utc"].transform(lambda s: rolling_count(s,7))
        g[f"{prefix}_matches_14d"]= g.groupby("team_id")["date_utc"].transform(lambda s: rolling_count(s,14))
        return g.drop(columns=["prev_date","team_id"])
    H=side_features("home"); A=side_features("away")
    base = base.merge(H, on=["fixture_id","date_utc"], how="left").merge(A, on=["fixture_id","date_utc"], how="left")
    base["delta_days_since"]  = base["home_days_since"].fillna(0)   - base["away_days_since"].fillna(0)
    base["delta_matches_7d"]  = base["home_matches_7d"].fillna(0)  - base["away_matches_7d"].fillna(0)
    base["delta_matches_14d"] = base["home_matches_14d"].fillna(0) - base["away_matches_14d"].fillna(0)

    # ----- РЫНОК: только прематч, одна строка на матч -----
    odds_cols = [
        "fixture_id","n_bookmakers","avg_odds_home","avg_odds_draw","avg_odds_away",
        "avg_odds_over25","avg_odds_under25","imp_home_raw","imp_draw_raw","imp_away_raw",
        "overround_1x2","p_home_norm","p_draw_norm","p_away_norm","p_over_mkt","league_id","odds_ts"
    ]
    have=[c for c in odds_cols if c in odds_view.columns]
    odds_raw = odds_view[have].copy() if have else pd.DataFrame(columns=odds_cols)
    odds_pm = _prematch_odds_one_per_fixture(odds_raw, sched)
    overlap=(set(odds_pm.columns)&set(base.columns))-{"fixture_id"}
    if not odds_pm.empty and overlap:
        odds_pm=odds_pm.drop(columns=list(overlap))
    base = base.merge(odds_pm, on="fixture_id", how="left")

    # p_over_mkt если нет
    if "p_over_mkt" not in base.columns and {"avg_odds_over25","avg_odds_under25"}<=set(base.columns):
        p_over_raw  = 1.0/pd.to_numeric(base["avg_odds_over25"], errors="coerce")
        p_under_raw = 1.0/pd.to_numeric(base["avg_odds_under25"], errors="coerce")
        s = p_over_raw.fillna(0)+p_under_raw.fillna(0)
        base["p_over_mkt"] = np.where(s>0, p_over_raw/s, np.nan).astype("float32")

    # Sum & Delta helpers
    def add_sum(df,name):
        h,f = f"home_{name}", f"away_{name}"
        if h in df.columns and f in df.columns: df[f"sum_{name}"]=df[h]+df[f]
    def add_delta(df,name):
        h,f = f"home_{name}", f"away_{name}"
        if h in df.columns and f in df.columns: df[f"delta_{name}"]=df[h]-df[f]

    for nm in [f"expected_goals_mean_{ROLL_N}", f"expected_goals_ema_{ROLL_N}",
               f"goals_for_mean_{ROLL_N}", f"goals_for_std_{ROLL_N}",
               f"goals_for_sum_{ROLL_N_SHORT}", f"tempo_mean_{ROLL_N}",
               f"tempo_ema_{ROLL_N}", f"tempo_slope_{ROLL_N}",
               f"sot_rate_mean_{ROLL_N}", f"xg_per_shot_mean_{ROLL_N}",
               f"points_mean_{ROLL_N}", f"points_ema_{ROLL_N}", f"points_sum_{ROLL_N_SHORT}"]:
        add_sum(base, nm)

    for nm in [f"expected_goals_mean_{ROLL_N}", f"expected_goals_std_{ROLL_N}",
               f"expected_goals_ema_{ROLL_N}", f"expected_goals_slope_{ROLL_N}",
               f"goals_for_mean_{ROLL_N}", f"goals_against_mean_{ROLL_N}",
               f"goals_for_std_{ROLL_N}", f"goals_against_std_{ROLL_N}",
               f"tempo_mean_{ROLL_N}", f"tempo_slope_{ROLL_N}",
               f"sot_rate_mean_{ROLL_N}", f"xg_per_shot_mean_{ROLL_N}",
               f"points_mean_{ROLL_N}", f"points_ema_{ROLL_N}"]:
        add_delta(base, nm)

    def add_relative_features(df, names):
        for name in names:
            h = f"home_{name}"
            a = f"away_{name}"
            if h in df.columns and a in df.columns:
                df[f"rel_{name}_diff"] = df[h] - df[a]
                denom = df[a].replace(0, np.nan)
                df[f"rel_{name}_ratio"] = df[h] / denom

    relative_metrics = [
        f"expected_goals_mean_{ROLL_N}",
        f"expected_goals_ema_{ROLL_N}",
        f"goals_for_mean_{ROLL_N}",
        f"goals_for_sum_{ROLL_N_SHORT}",
        f"tempo_mean_{ROLL_N}",
        f"sot_rate_mean_{ROLL_N}",
        f"xg_per_shot_mean_{ROLL_N}",
        f"points_mean_{ROLL_N}"
    ]
    add_relative_features(base, relative_metrics)

    base['home_is_home'] = 1.0
    base['away_is_home'] = 0.0
    if 'h2h_winrate_home_lastN' in base.columns:
        base['h2h_winrate_centered'] = base['h2h_winrate_home_lastN'] - 0.5
    if 'h2h_drawrate_lastN' in base.columns:
        base['h2h_drawrate_centered'] = base['h2h_drawrate_lastN'] - 0.3333
    if 'h2h_gdiff_avg_lastN' in base.columns:
        base['h2h_gdiff_centered'] = base['h2h_gdiff_avg_lastN']
    if 'h2h_goals_avg_lastN' in base.columns:
        base['h2h_goals_centered'] = base['h2h_goals_avg_lastN'] - 2.5

    # injury deltas
    inj_cols_all = [c for c in base.columns if c.startswith("home_inj") and c.endswith("_cnt")] + ["home_inj_total_cnt"]
    inj_cols_all = [c for c in inj_cols_all if c in base.columns]
    for hc in inj_cols_all:
        ac = hc.replace("home_","away_"); nm = hc.replace("home_","")
        if ac in base.columns: add_delta(base, nm)

    # ---------- TARGETS ----------
    known = base["home_goals"].notna() & base["away_goals"].notna()
    base["has_result"] = known.astype(bool)

    res = np.where(base["home_goals"] > base["away_goals"], 1,
          np.where(base["home_goals"] < base["away_goals"], -1, 0))
    base["target_result"] = np.where(known, res, np.nan).astype("float32")

    tot = pd.to_numeric(base["home_goals"], errors="coerce") + pd.to_numeric(base["away_goals"], errors="coerce")
    base["target_over25"] = np.where(known, (tot >= 3).astype("int32"), np.nan).astype("float32")

    base = ensure_match_keys(base, sched)
    for c in ["league_id","home_team_id","away_team_id","season"]:
        if c in base.columns:
            base[c] = pd.to_numeric(base[c], errors="coerce")

    # ---- симметрийные признаки для ничьей
    base["abs_elo_diff"] = np.abs(pd.to_numeric(base.get("elo_diff"), errors="coerce"))
    for nm in [f"expected_goals_mean_{ROLL_N}", f"tempo_mean_{ROLL_N}", f"sot_rate_mean_{ROLL_N}"]:
        dc = f"delta_{nm}"
        if dc in base.columns:
            base[f"abs_{dc}"] = np.abs(pd.to_numeric(base[dc], errors="coerce"))

    # ---- СТРОГИЙ АНТИ-ЛИК по колонкам (оставляем базовые home_goals/away_goals для целей/Poisson)
    base = strict_drop_goalish_columns(base, keep_basic_results=True)

    if return_all:
        return base.sort_values("date_utc").reset_index(drop=True)
    else:
        train = base[base["has_result"]].copy().reset_index(drop=True)
        if "league_id" not in train.columns:
            keys = sched[["fixture_id","league_id"]].drop_duplicates("fixture_id")
            train = train.merge(keys, on="fixture_id", how="left")
        train["league_id"] = pd.to_numeric(train["league_id"], errors="coerce")
        return train

# =========================
# SPLIT & FRESHNESS
# =========================
def _resolve_now(ts_series: pd.Series) -> pd.Timestamp:
    if NOW_OVERRIDE:
        return pd.to_datetime(NOW_OVERRIDE, utc=True)
    return pd.to_datetime(ts_series.max(), utc=True)

def split_tr_cal_va(df_train: pd.DataFrame,
                    va_days: int = VA_DAYS,
                    cal_days: int = CAL_DAYS,
                    gap_days: int = GAP_DAYS):
    df = df_train.sort_values("date_utc").copy()
    df["date_utc"] = pd.to_datetime(df["date_utc"], errors="coerce", utc=True)
    df["league_id"] = pd.to_numeric(df.get("league_id"), errors="coerce")

    now = _resolve_now(df["date_utc"])
    td = pd.Timedelta

    va_end_global = now - td(days=gap_days)
    va_start_global = va_end_global - td(days=va_days)
    cal_end_global = va_start_global
    cal_start_global = cal_end_global - td(days=cal_days)

    tr_parts, cal_parts, va_parts = [], [], []

    grouped = df.groupby(df["league_id"].fillna(-9999), sort=False)

    for lid, g in grouped:
        g = g.sort_values("date_utc").reset_index(drop=True)
        if g.empty:
            continue
        league_max = g["date_utc"].max()
        va_end = min(va_end_global, league_max)
        va_start = va_end - td(days=va_days)
        cal_end = min(cal_end_global, va_start)
        cal_start = cal_end - td(days=cal_days)

        va_part = g[(g["date_utc"] > va_start) & (g["date_utc"] <= va_end)].copy()
        min_va = min(LEAGUE_VA_MIN, max(len(g) // 4, 1))
        if len(va_part) < min_va:
            take = min(len(g), max(min_va, len(va_part)))
            va_part = g.tail(take).copy()

        remaining = g.drop(va_part.index)

        cal_part = remaining[(remaining["date_utc"] > cal_start) & (remaining["date_utc"] <= cal_end)].copy()
        min_cal = min(LEAGUE_CAL_MIN, max(len(g) // 3, 1))
        if len(cal_part) < min_cal:
            take = min(len(remaining), max(min_cal, len(cal_part)))
            cal_part = remaining.tail(take).copy()

        remaining = remaining.drop(cal_part.index)

        tr_parts.append(remaining)
        cal_parts.append(cal_part)
        va_parts.append(va_part)

    tr = pd.concat(tr_parts, ignore_index=True) if tr_parts else pd.DataFrame(columns=df.columns)
    cal = pd.concat(cal_parts, ignore_index=True) if cal_parts else pd.DataFrame(columns=df.columns)
    va = pd.concat(va_parts, ignore_index=True) if va_parts else pd.DataFrame(columns=df.columns)

    used = set()
    def _dedupe(df_part: pd.DataFrame) -> pd.DataFrame:
        if df_part.empty or "fixture_id" not in df_part.columns:
            return df_part.reset_index(drop=True)
        mask = ~df_part["fixture_id"].isin(used)
        used.update(df_part.loc[mask, "fixture_id"])
        return df_part.loc[mask].reset_index(drop=True)

    tr, cal, va = _dedupe(tr), _dedupe(cal), _dedupe(va)

    print(f"[SPLIT] now={now} | TR={tr['date_utc'].min()}..{tr['date_utc'].max()} "
          f"| CAL={cal['date_utc'].min()}..{cal['date_utc'].max()} | VA={va['date_utc'].min()}..{va['date_utc'].max()}")
    return tr, cal, va

def recency_weights(df_like: pd.DataFrame,
                    half_life_days: int = RECENCY_HALFLIFE_DAYS,
                    floor: float = RECENCY_FLOOR,
                    cap: float = RECENCY_CAP) -> np.ndarray:
    t = pd.to_datetime(df_like["date_utc"], errors="coerce", utc=True)
    now = _resolve_now(t)
    age_days = (now - t).dt.days.astype("float32")
    w = np.power(0.5, age_days / float(half_life_days))
    w = np.clip(w, floor, cap)
    return w.values.astype("float32")

# =========================
# MONOTONICITIES
# =========================
def build_mono_outcome(feature_list):
    mono=[]
    for f in feature_list:
        if f in ("elo_diff","p_home_elo"):
            mono.append(1)
        elif f == "p_away_elo":
            mono.append(-1)
        elif f == "abs_elo_diff":
            mono.append(-1)
        elif f.startswith("abs_delta_"):
            mono.append(-1)
        else:
            mono.append(0)
    return mono

def build_mono_draw(feature_list):
    mono=[]
    for f in feature_list:
        if f == "abs_elo_diff": mono.append(-1)
        elif f in ("league_draw_prior","h2h_drawrate_lastN"): mono.append(1)
        elif (f.startswith("sum_expected_goals") or f.startswith("sum_tempo")): mono.append(-1)
        elif f.startswith("abs_delta_"): mono.append(-1)
        else: mono.append(0)
    return mono

def build_mono_totals(feature_list):
    mono=[]
    for f in feature_list:
        if f.startswith("sum_expected_goals") or f.startswith("sum_tempo") or f in ("league_over25_prior",):
            mono.append(1)
        elif ("xg_per_shot" in f) or ("sot_rate" in f): mono.append(1)
        else:
            mono.append(0)
    return mono

# =========================
# HELPERS
# =========================
def compute_league_medians(df: pd.DataFrame, feature_cols):
    med_global = df[feature_cols].replace([np.inf, -np.inf], np.nan).median(numeric_only=True)
    med_by_league = {}
    if "league_id" in df.columns:
        for lid, g in df.groupby("league_id"):
            med_by_league[int(lid)] = g[feature_cols].replace([np.inf, -np.inf], np.nan).median(numeric_only=True)
    return med_global, med_by_league

def impute_with_league(df: pd.DataFrame, feature_cols, med_global: pd.Series, med_by_league: dict) -> pd.DataFrame:
    X = df[feature_cols].copy()
    X = X.replace([np.inf, -np.inf], np.nan)
    lids = pd.to_numeric(df.get("league_id", np.nan), errors="coerce")
    for lid, med in med_by_league.items():
        m = (lids == int(lid)).to_numpy()
        if m.any():
            X.loc[m, :] = X.loc[m, :].fillna(med)
    X = X.fillna(med_global)
    return X.astype("float64")

def apply_draw_controls(P: np.ndarray, df_like: pd.DataFrame) -> np.ndarray:
    P = np.asarray(P, dtype="float64").copy()
    if P.ndim != 2 or P.shape[1] != 3:
        return P

    if "league_draw_prior" in df_like.columns:
        pr = pd.to_numeric(df_like["league_draw_prior"], errors="coerce").values
        pr = np.where(np.isfinite(pr), pr, 0.26)
        P[:, 1] = sanitize_prob((1.0 - float(DRAW_BETA_PRIOR)) * P[:, 1] + float(DRAW_BETA_PRIOR) * pr)

    if "p_draw_norm" in df_like.columns:
        mkt = pd.to_numeric(df_like["p_draw_norm"], errors="coerce").values
        cap_rel = np.where(np.isfinite(mkt), mkt + float(DRAW_CAP_DELTA_MKT), float("inf"))
    else:
        cap_rel = np.full(len(P), float("inf"))
    cap_abs = float(DRAW_CAP_ABS)
    cap = np.minimum(cap_abs, cap_rel)
    P[:, 1] = np.minimum(P[:, 1], cap)

    P = np.clip(P, 1e-6, 1-1e-6)
    P /= P.sum(axis=1, keepdims=True)
    return P

def _diag_draw_bias(df_like: pd.DataFrame, P: np.ndarray, tag: str):
    mkt   = pd.to_numeric(df_like.get("p_draw_norm"), errors="coerce")
    prior = pd.to_numeric(df_like.get("league_draw_prior"), errors="coerce")
    print(f"[DIAG {tag}] mean p_draw: model={P[:,1].mean():.3f} | market={np.nanmean(mkt):.3f} | prior={np.nanmean(prior):.3f} | mkt_cov={mkt.notna().mean()*100:.1f}%")

def _map_by_league(lids_series: pd.Series, value_by_lid: dict, default_val: float) -> np.ndarray:
    lids = pd.to_numeric(lids_series, errors="coerce").values
    out = np.full(len(lids), float(default_val), dtype="float64")
    for i, lid in enumerate(lids):
        if np.isfinite(lid) and int(lid) in value_by_lid:
            out[i] = float(value_by_lid[int(lid)])
    return out

def _sanitize_mc(P: np.ndarray):
    P = np.asarray(P, dtype="float64")
    if P.ndim != 2:
        P = np.atleast_2d(P)
    valid = np.all(np.isfinite(P), axis=1)
    if valid.any():
        P[valid] = np.clip(P[valid], 1e-6, 1-1e-6)
        sums = P[valid].sum(axis=1, keepdims=True)
        sums = np.where(sums <= 1e-12, 1.0, sums)
        P[valid] = P[valid] / sums
    return P, valid

def export_feature_importance(booster, feature_names, path_csv):
    try:
        gain = booster.get_score(importance_type="gain")
        weight = booster.get_score(importance_type="weight")
        cover = booster.get_score(importance_type="cover")
        all_feats = set(feature_names)
        rows=[]
        for f in all_feats:
            rows.append({
                "feature": f,
                "gain": float(gain.get(f, 0.0)),
                "weight": float(weight.get(f, 0.0)),
                "cover": float(cover.get(f, 0.0))
            })
        df = pd.DataFrame(rows).sort_values("gain", ascending=False)
        df.to_csv(path_csv, index=False)
        print(f"[FI] Saved feature importance -> {path_csv} (top 10):")
        print(df.head(10).to_string(index=False))
    except Exception as e:
        print(f"[FI] Export failed for {path_csv}: {e}")

# =========================
# POISSON BRANCH
# =========================
def _poisson_pmf_vector(lmbd, K=POISSON_K):
    lmbd = float(max(1e-8, lmbd))
    pmf = np.zeros(K+1, dtype="float64")
    pmf[0] = np.exp(-lmbd)
    for k in range(1, K):
        pmf[k] = pmf[k-1] * lmbd / k
    s = pmf[:K].sum()
    pmf[K] = max(0.0, 1.0 - s)
    pmf = pmf / pmf.sum()
    return pmf

def poisson_triplet_and_over(lmbd_h, lmbd_a, K=POISSON_K):
    ph = _poisson_pmf_vector(lmbd_h, K)
    pa = _poisson_pmf_vector(lmbd_a, K)
    joint = np.outer(ph, pa)  # H x A
    idx = np.arange(K+1)
    mask_H = idx[:,None] > idx[None,:]
    mask_D = idx[:,None] == idx[None,:]
    mask_A = idx[:,None] < idx[None,:]
    pH = joint[mask_H].sum()
    pD = joint[mask_D].sum()
    pA = joint[mask_A].sum()
    total = np.add.outer(idx, idx)
    p_over25 = joint[total >= 3].sum()
    S = pA + pD + pH
    if S <= 1e-12:
        pA=pD=pH=1/3
    else:
        pA, pD, pH = pA/S, pD/S, pH/S
    return float(pA), float(pD), float(pH), float(p_over25)

def train_poisson_regressors(tr, cal, va, feature_cols, med_global, med_by_league):
    X_tr  = impute_with_league(tr,  feature_cols, med_global, med_by_league).values
    X_cal = impute_with_league(cal, feature_cols, med_global, med_by_league).values
    X_va  = impute_with_league(va,  feature_cols, med_global, med_by_league).values

    yh_tr = np.log1p(pd.to_numeric(tr["home_goals"], errors="coerce").values.astype("float64"))
    ya_tr = np.log1p(pd.to_numeric(tr["away_goals"], errors="coerce").values.astype("float64"))

    params_reg = {
        "objective": "reg:squarederror",
        "eta": 0.06, "max_depth": 3, "subsample": 0.85, "colsample_bytree": 0.85,
        "min_child_weight": 8, "lambda": 3.5, "alpha": 0.10,
        "seed": 123, "tree_method": "hist"
    }

    w_tr = recency_weights(tr, half_life_days=RECENCY_HALFLIFE_DAYS)
    dtr_h = xgb.DMatrix(X_tr, label=yh_tr, weight=w_tr, feature_names=feature_cols)
    dtr_a = xgb.DMatrix(X_tr, label=ya_tr, weight=w_tr, feature_names=feature_cols)
    dcal  = xgb.DMatrix(X_cal, feature_names=feature_cols)
    dva   = xgb.DMatrix(X_va,  feature_names=feature_cols)

    model_h = xgb.train(params=params_reg, dtrain=dtr_h, num_boost_round=600,
                        evals=[(dtr_h, "train_h")], early_stopping_rounds=60, verbose_eval=False)
    model_a = xgb.train(params=params_reg, dtrain=dtr_a, num_boost_round=600,
                        evals=[(dtr_a, "train_a")], early_stopping_rounds=60, verbose_eval=False)

    n_best_h = best_ntree_limit(model_h)
    n_best_a = best_ntree_limit(model_a)

    def _to_lambda(pred_log1p):
        lam = np.expm1(pred_log1p)
        lam = np.clip(lam, POISSON_LAMBDA_MIN, POISSON_LAMBDA_MAX)
        return lam

    lam_h_cal = _to_lambda(predict_best(model_h, dcal, n_best_h))
    lam_a_cal = _to_lambda(predict_best(model_a, dcal, n_best_a))
    lam_h_va = _to_lambda(predict_best(model_h, dva, n_best_h))
    lam_a_va = _to_lambda(predict_best(model_a, dva, n_best_a))

    return {
        "model_h": model_h, "model_a": model_a,
        "n_best_h": n_best_h, "n_best_a": n_best_a,
        "lam_h_cal": lam_h_cal, "lam_a_cal": lam_a_cal,
        "lam_h_va": lam_h_va, "lam_a_va": lam_a_va
    }

def build_poisson_probs_for_df(lam_h_arr, lam_a_arr):
    pA = np.zeros(len(lam_h_arr), dtype="float64")
    pD = np.zeros(len(lam_h_arr), dtype="float64")
    pH = np.zeros(len(lam_h_arr), dtype="float64")
    pov = np.zeros(len(lam_h_arr), dtype="float64")
    for i, (lh, la) in enumerate(zip(lam_h_arr, lam_a_arr)):
        a, d, h, o = poisson_triplet_and_over(float(lh), float(la), K=POISSON_K)
        pA[i], pD[i], pH[i], pov[i] = a, d, h, o
    P = np.stack([pA, pD, pH], axis=1)
    P = np.clip(P, 1e-6, 1 - 1e-6);
    P /= P.sum(axis=1, keepdims=True)
    return P, pov

# =========================
# TRAIN 1X2
# =========================
def train_outcomes(df_train: pd.DataFrame):
    """
    Итоговый тренер 1X2:
      - XGB: Home vs Away (p_home) и Draw (p_draw)
      - Poisson-ветка (через регрессоры лямбд)
      - Перекалибровка (LR глобально + per-league)
      - τ-коррекция ничьей per-league
      - Смешивание XGB vs Poisson (b0..b3) — сетки чуть уплотнены
      - ПОРЯДОК: смесь -> якорение рынком -> капы ничьей -> δ-сдвиг ничьей -> bias при argmax
    """

    df = df_train.copy().sort_values("date_utc")
    assert "target_result" in df.columns, "нет target_result"
    assert "target_over25" in df.columns, "нет target_over25"

    tr, cal, va = split_tr_cal_va(df)

    # список фичей (рынок уже исключён из фичей; goal/score-сырые тоже исключены)
    feat_all = build_feature_cols(df)

    # зачистка NaN/констант
    def _drop_bad_columns(d, feats):
        good = []
        for c in feats:
            x = pd.to_numeric(d[c], errors="coerce")
            if x.notna().sum() < min(30, max(10, int(0.01 * len(d)))):
                continue
            if np.nanstd(x.values) == 0.0:
                continue
            good.append(c)
        return good

    feat_all = _drop_bad_columns(df, feat_all)

    # страховка от утечки: срез по корр на CAL
    feat_ha = _drop_suspicious_corr_features(cal, feat_all, target_col="target_result", thr=0.98)
    feat_d  = _drop_suspicious_corr_features(cal, feat_all, target_col="target_over25", thr=0.98)

    # таргеты
    y_draw_tr  = (tr["target_result"] == 0).astype("int32").values
    y_draw_cal = (cal["target_result"] == 0).astype("int32").values
    y_draw_va  = (va["target_result"] == 0).astype("int32").values
    feat_draw = feat_d
    pos = int(y_draw_tr.sum())
    neg = int((1 - y_draw_tr).sum())
    spw_draw = float(neg / max(1, pos))

    # импутация
    med_global, med_by_league = compute_league_medians(tr, feat_all)

    X_tr_ha  = impute_with_league(tr,  feat_ha,  med_global, med_by_league).values
    X_cal_ha = impute_with_league(cal, feat_ha,  med_global, med_by_league).values
    X_va_ha  = impute_with_league(va,  feat_ha,  med_global, med_by_league).values

    X_tr_d   = impute_with_league(tr,  feat_draw, med_global, med_by_league).values
    X_cal_d  = impute_with_league(cal, feat_draw, med_global, med_by_league).values
    X_va_d   = impute_with_league(va,  feat_draw, med_global, med_by_league).values

    w_tr = recency_weights(tr)

    # HA: бинарка home(1) vs away(0), игнорим ничьи
    m_tr_ha  = tr["target_result"] != 0
    m_cal_ha = cal["target_result"] != 0
    m_va_ha  = va["target_result"]  != 0

    y_tr_ha  = (tr.loc[m_tr_ha,  "target_result"] == 1).astype("int32").values
    y_cal_ha = (cal.loc[m_cal_ha, "target_result"] == 1).astype("int32").values
    y_va_ha  = (va.loc[m_va_ha,  "target_result"] == 1).astype("int32").values

    dtr_ha  = xgb.DMatrix(X_tr_ha[m_tr_ha],  label=y_tr_ha,  weight=w_tr[m_tr_ha], feature_names=feat_ha)
    dcal_ha = xgb.DMatrix(X_cal_ha[m_cal_ha], label=y_cal_ha, feature_names=feat_ha)
    dva_ha  = xgb.DMatrix(X_va_ha[m_va_ha],   feature_names=feat_ha)

    dtr_d   = xgb.DMatrix(X_tr_d,  label=y_draw_tr,  weight=w_tr, feature_names=feat_draw)
    dcal_d  = xgb.DMatrix(X_cal_d, label=y_draw_cal,               feature_names=feat_draw)
    dva_d   = xgb.DMatrix(X_va_d,                                    feature_names=feat_draw)

    params_ha = {
        "objective": "binary:logistic",
        "eval_metric": "logloss",
        "eta": 0.035, "max_depth": 3, "subsample": 0.75, "colsample_bytree": 0.70,
        "min_child_weight": 12, "lambda": 6.0, "alpha": 0.05, "gamma": 0.3,
        "seed": RANDOM_SEED, "tree_method": "hist",
        "monotone_constraints": "(" + ",".join(map(str, build_mono_outcome(feat_ha))) + ")"
    }
    params_d = {
        "objective": "binary:logistic",
        "eval_metric": "logloss",
        "eta": 0.03, "max_depth": 3, "subsample": 0.75, "colsample_bytree": 0.70,
        "min_child_weight": 10, "lambda": 5.0, "alpha": 0.10, "gamma": 0.2,
        "scale_pos_weight": spw_draw,
        "seed": RANDOM_SEED + 1, "tree_method": "hist",
        "monotone_constraints": "(" + ",".join(map(str, build_mono_draw(feat_draw))) + ")"
    }

    print(f"[OUT] Features used: {len(feat_ha)} (dropped by NaN/const: {len(build_feature_cols(df)) - len(feat_ha)})")
    booster_ha = xgb.train(params_ha, dtr_ha, num_boost_round=900,
                           evals=[(dtr_ha, "train"), (dcal_ha, "cal")],
                           verbose_eval=200 if len(cal) > 0 else False,
                           early_stopping_rounds=120)
    n_best_ha = best_ntree_limit(booster_ha)

    print(f"[OUT] Features used (draw): {len(feat_draw)}")
    booster_d  = xgb.train(params_d, dtr_d, num_boost_round=900,
                           evals=[(dtr_d, "train"), (dcal_d, "cal")],
                           verbose_eval=200 if len(cal) > 0 else False,
                           early_stopping_rounds=120)
    n_best_d = best_ntree_limit(booster_d)

    export_feature_importance(booster_ha, feat_ha, FI_OUT_HA)
    export_feature_importance(booster_d,  feat_draw, FI_OUT_DR)

    # предсказания на CAL (p_home, p_draw)
    p_home_cal = np.full(len(cal), 0.5, dtype="float64")
    if m_cal_ha.any():
        p_home_cal[m_cal_ha] = predict_best(booster_ha, dcal_ha, n_best_ha).astype("float64")

    elo_fb_cal = pd.to_numeric(cal.get("p_home_elo"), errors="coerce").values
    mask_fb_cal = (~m_cal_ha) & np.isfinite(elo_fb_cal)
    if mask_fb_cal.any():
        p_home_cal[mask_fb_cal] = elo_fb_cal[mask_fb_cal]

    p_draw_cal = predict_best(booster_d, dcal_d, n_best_d).astype("float64")

    # --- сборка 3-класса из (p_home, p_draw)
    def build_triplet(pH, pD):
        pH = sanitize_prob(pH);
        pD = sanitize_prob(pD)
        remain = 1.0 - pD
        pH = np.clip(pH, 1e-6, 1 - 1e-6)
        pA = np.clip(remain - pH, 1e-6, 1 - 1e-6)
        P = np.stack([pA, pD, pH], axis=1)
        P = np.clip(P, 1e-6, 1 - 1e-6)
        P /= P.sum(axis=1, keepdims=True)
        return P

    P_cal_raw = build_triplet(pH=p_home_cal, pD=p_draw_cal)
    _diag_draw_bias(cal, P_cal_raw, "CAL raw (pre-calibration)")

    # --- калибровка (LR multinomial) глобально + per-league
    Xc = np.log(P_cal_raw / (1 - P_cal_raw))
    y_cal_3 = cal["target_result"].map({-1: 0, 0: 1, 1: 2}).astype("int32").values

    lr_global = LogisticRegression(max_iter=200, multi_class="multinomial")
    lr_global.fit(Xc, y_cal_3)

    calibrators_by_league = {}
    min_cnt_for_league_cal = max(35, int(0.3 * len(cal)))
    lids_cal = pd.to_numeric(cal["league_id"], errors="coerce").values
    for lid in pd.Series(lids_cal).dropna().unique().astype(int):
        m = (lids_cal == lid)
        if m.sum() >= min_cnt_for_league_cal:
            lr = LogisticRegression(max_iter=200, multi_class="multinomial")
            lr.fit(Xc[m], y_cal_3[m])
            calibrators_by_league[int(lid)] = lr

    # применяем калибровку на CAL
    P_cal_calibr = np.zeros_like(P_cal_raw)
    used_mask = np.zeros(len(cal), dtype=bool)
    for lid, lr_l in calibrators_by_league.items():
        m = (lids_cal == int(lid))
        if m.any():
            P_cal_calibr[m] = np.clip(lr_l.predict_proba(Xc[m]), 1e-6, 1 - 1e-6);
            used_mask[m] = True
    if (~used_mask).any():
        P_cal_calibr[~used_mask] = np.clip(lr_global.predict_proba(Xc[~used_mask]), 1e-6, 1 - 1e-6)

    # --- τ-коррекция ничьей per-league (узкая)
    tau_by_lid = {}
    for lid in pd.Series(lids_cal).dropna().unique().astype(int):
        m = (lids_cal == lid)
        if m.sum() < TAU_MIN_N:
            tau_by_lid[lid] = 1.0
            continue
        pD = P_cal_calibr[m, 1]
        yD = (cal.loc[m, "target_result"] == 0).astype(int).values
        try:
            iso = IsotonicRegression(out_of_bounds="clip")
            pDc = iso.fit_transform(pD, yD)
            adj = np.median(np.clip(pDc / np.clip(pD, 1e-6, 1 - 1e-6), 0.85, 1.15))
        except Exception:
            adj = 1.0
        tau_by_lid[lid] = float(adj)

    P_cal_t = P_cal_calibr.copy()
    tau_arr = _map_by_league(cal["league_id"], tau_by_lid, 1.0)
    bonus_arr = _map_by_league(cal["league_id"], TAU_DRAW_BONUS_BY_LID, 1.0)
    tau_arr = np.clip(tau_arr * bonus_arr, 0.85, 1.15)
    P_cal_t[:, 1] = np.clip(P_cal_t[:, 1] * tau_arr, 1e-6, 1 - 1e-6)
    P_cal_t /= P_cal_t.sum(axis=1, keepdims=True)

    # --- Poisson ветка
    pois = train_poisson_regressors(tr, cal, va, feat_all, med_global, med_by_league)
    P_dc_cal, _ = build_poisson_probs_for_df(pois["lam_h_cal"], pois["lam_a_cal"])

    # --- подбор w_out на CAL (смешивание XGB vs Poisson), чуть более плотные сетки
    orr_cal = pd.to_numeric(cal.get("overround_1x2"), errors="coerce").fillna(1.10).values
    nbk_cal = pd.to_numeric(cal.get("n_bookmakers"), errors="coerce").fillna(0).values
    sumL_cal = np.clip(pois["lam_h_cal"] + pois["lam_a_cal"], 0, 7)

    best = None
    for b0 in (0.15, 0.25, 0.35):
        for b1 in (2.0, 2.5, 3.0, 3.5):
            for b2 in (0.0, 0.2, 0.4):
                for b3 in (0.4, 0.6, 0.8):
                    inv_orr = 1.0 / np.clip(orr_cal, 1.01, 1.25)
                    ln_nbk = np.log1p(np.clip(nbk_cal, 0, 50))
                    w_out = _sigmoid(b0 + b1 * inv_orr + b2 * ln_nbk - b3 * sumL_cal)
                    mix = w_out[:, None] * P_cal_t + (1 - w_out)[:, None] * P_dc_cal
                    mix /= mix.sum(axis=1, keepdims=True)
                    ll = safe_log_loss(y_cal_3, mix, labels=[0, 1, 2])
                    if (best is None) or (ll < best[0]):
                        best = (ll, b0, b1, b2, b3)
    _, b0, b1, b2, b3 = best
    print(f"[OUT] Best w_out on CAL: b0={b0:.3f} b1={b1:.3f} b2={b2:.3f} b3={b3:.3f}")

    inv_orr_cal = 1.0 / np.clip(orr_cal, 1.01, 1.25)
    ln_nbk_cal = np.log1p(np.clip(nbk_cal, 0, 50))
    w_out_cal = _sigmoid(b0 + b1 * inv_orr_cal + b2 * ln_nbk_cal - b3 * sumL_cal)
    P_mix_cal = (w_out_cal[:, None] * P_cal_t + (1 - w_out_cal)[:, None] * P_dc_cal)
    P_mix_cal /= P_mix_cal.sum(axis=1, keepdims=True)

    # --- ЯКОРЕНИЕ К РЫНКУ (только здесь)
    have_mkt = {"p_home_norm", "p_draw_norm", "p_away_norm"} <= set(cal.columns)
    if have_mkt:
        Pm_cal = np.stack([
            cal["p_away_norm"].values,
            cal["p_draw_norm"].values,
            cal["p_home_norm"].values
        ], axis=1).astype("float64")
        Pm_cal, valid_cal = _sanitize_mc(Pm_cal)

        alpha_base = _map_by_league(cal["league_id"], {}, ALPHA_MKT_FLOOR_OUT).astype("float64")
        alpha_dyn = dynamic_alpha(orr_cal, nbk_cal, sum_lambda_arr=sumL_cal,
                                  floor=ALPHA_MKT_FLOOR_OUT, ceil=0.65)
        alpha_arr_cal = np.maximum(alpha_base, alpha_dyn)

        P_anchor_cal = P_mix_cal.copy()
        if valid_cal.any():
            P_anchor_cal[valid_cal] = (
                    (1.0 - alpha_arr_cal[valid_cal, None]) * P_mix_cal[valid_cal]
                    + alpha_arr_cal[valid_cal, None] * Pm_cal[valid_cal]
            )
            P_anchor_cal[valid_cal] /= P_anchor_cal[valid_cal].sum(axis=1, keepdims=True)
    else:
        P_anchor_cal = P_mix_cal

    # --- КАПЫ НИЧЬЕЙ + ПРИОР ЛИГИ
    P_caps_cal = apply_draw_controls(P_anchor_cal, cal)
    _diag_draw_bias(cal, P_caps_cal, "CAL after anchor+caps")

    # --- Подбор δ (ПОСЛЕ якорения и капов)
    delta_draw = tune_draw_shift_on_cal(y_cal_3, P_caps_cal)

    # ======== ВАЛИДАЦИЯ ========
    p_home_va = np.full(len(va), 0.5, dtype="float64")
    if m_va_ha.any():
        p_home_va[m_va_ha] = predict_best(booster_ha, dva_ha, n_best_ha).astype("float64")

    elo_fb_va = pd.to_numeric(va.get("p_home_elo"), errors="coerce").values
    mask_fb_va = (~m_va_ha) & np.isfinite(elo_fb_va)
    if mask_fb_va.any():
        p_home_va[mask_fb_va] = elo_fb_va[mask_fb_va]

    p_draw_va = predict_best(booster_d, dva_d, n_best_d).astype("float64")
    P_va_raw = build_triplet(pH=p_home_va, pD=p_draw_va)

    # калибровка LR на VAL (те же калибраторы)
    Xv = np.log(P_va_raw / (1 - P_va_raw))
    P_va_cal = np.zeros_like(P_va_raw)
    lids_va = pd.to_numeric(va["league_id"], errors="coerce").values
    used_mask = np.zeros(len(va), dtype=bool)
    for lid, lr_l in calibrators_by_league.items():
        m = (lids_va == int(lid))
        if m.any():
            P_va_cal[m] = np.clip(lr_l.predict_proba(Xv[m]), 1e-6, 1 - 1e-6);
            used_mask[m] = True
    if (~used_mask).any():
        P_va_cal[~used_mask] = np.clip(lr_global.predict_proba(Xv[~used_mask]), 1e-6, 1 - 1e-6)

    # τ на VAL
    tau_arr_va = _map_by_league(va["league_id"], tau_by_lid, 1.0)
    bonus_arr_va = _map_by_league(va["league_id"], TAU_DRAW_BONUS_BY_LID, 1.0)
    tau_arr_va = np.clip(tau_arr_va * bonus_arr_va, 0.85, 1.15)
    P_va_t = P_va_cal.copy()
    P_va_t[:, 1] = np.clip(P_va_t[:, 1] * tau_arr_va, 1e-6, 1 - 1e-6)
    P_va_t /= P_va_t.sum(axis=1, keepdims=True)

    # Poisson на VAL
    P_dc_va, _ = build_poisson_probs_for_df(pois["lam_h_va"], pois["lam_a_va"])

    # смесь XGB vs Poisson на VAL
    orr_va = pd.to_numeric(va.get("overround_1x2"), errors="coerce").fillna(1.10).values
    nbk_va = pd.to_numeric(va.get("n_bookmakers"), errors="coerce").fillna(0).values
    sumL_va = np.clip(pois["lam_h_va"] + pois["lam_a_va"], 0, 7)
    inv_orr_va = 1.0 / np.clip(orr_va, 1.01, 1.25)
    ln_nbk_va = np.log1p(np.clip(nbk_va, 0, 50))
    w_out_va = _sigmoid(b0 + b1 * inv_orr_va + b2 * ln_nbk_va - b3 * sumL_va)
    P_before_anchor = (w_out_va[:, None] * P_va_t + (1 - w_out_va)[:, None] * P_dc_va)
    P_before_anchor /= P_before_anchor.sum(axis=1, keepdims=True)

    # якорение рынком
    have_mkt_va = {"p_home_norm", "p_draw_norm", "p_away_norm"} <= set(va.columns)
    if have_mkt_va:
        Pm_va = np.stack([
            va["p_away_norm"].values,
            va["p_draw_norm"].values,
            va["p_home_norm"].values
        ], axis=1).astype("float64")
        Pm_va, valid_va = _sanitize_mc(Pm_va)

        alpha_base_va = _map_by_league(va["league_id"], {}, ALPHA_MKT_FLOOR_OUT).astype("float64")
        alpha_dyn_va = dynamic_alpha(orr_va, nbk_va, sum_lambda_arr=sumL_va,
                                     floor=ALPHA_MKT_FLOOR_OUT, ceil=0.65)
        alpha_arr_va = np.maximum(alpha_base_va, alpha_dyn_va)

        P_anchor_va = P_before_anchor.copy()
        if valid_va.any():
            P_anchor_va[valid_va] = (
                    (1.0 - alpha_arr_va[valid_va, None]) * P_before_anchor[valid_va]
                    + alpha_arr_va[valid_va, None] * Pm_va[valid_va]
            )
            P_anchor_va[valid_va] /= P_anchor_va[valid_va].sum(axis=1, keepdims=True)
    else:
        P_anchor_va = P_before_anchor

    # капы ничьей + приор
    P_caps_va = apply_draw_controls(P_anchor_va, va)

    # δ-сдвиг ничьей (ПОСЛЕ якорения и капов)
    P_use = apply_draw_logit_shift(P_caps_va, delta_draw)

    # финальный bias для ничьей при argmax
    pred = argmax_with_draw_bias(P_use, eps=0.05)

    y_va_3 = va["target_result"].map({-1: 0, 0: 1, 1: 2}).astype("int32").values
    acc = safe_acc(y_va_3, pred)
    ll = safe_log_loss(y_va_3, P_use, labels=[0, 1, 2])

    print(f"\n[OUT] acc={acc:.4f}  LL={ll:.4f}  alpha_mkt_global={ALPHA_MKT_FLOOR_OUT:.4f}")
    print(classification_report(y_va_3, pred, target_names=["Away(-1)", "Draw(0)", "Home(+1)"]))

    print("\n[OUT] Лиговая разбивка (валидация)")
    for lid, g in va.assign(y=y_va_3, ph=P_use[:, 2], pd_=P_use[:, 1], pa=P_use[:, 0], pred=pred).groupby("league_id"):
        m = g.index
        acc_l = safe_acc(y_va_3[np.isin(va.index, m)], pred[np.isin(va.index, m)])
        ll_l = safe_log_loss(y_va_3[np.isin(va.index, m)], P_use[np.isin(va.index, m)], labels=[0, 1, 2])
        print(f"League {int(lid)}: n={len(g)} acc={acc_l:.4f} LL={ll_l:.4f}")

    if DEBUG_EXPORT:
        dbg = va[
            ["fixture_id", "league_id", "date_utc", "home_team_id", "away_team_id", "home_goals", "away_goals"]].copy()
        dbg["pA"] = P_use[:, 0]
        dbg["pD"] = P_use[:, 1]
        dbg["pH"] = P_use[:, 2]
        dbg["pred"] = pred
        dbg.to_csv(DEBUG_OUT_OUTCOMES, index=False)
        print(f"[OUT] Debug (outcomes) saved -> {DEBUG_OUT_OUTCOMES}  rows={len(dbg)}")

    # --- сохранение
    joblib.dump({
        "xgb_ha": booster_ha,
        "xgb_draw": booster_d,
        "n_best_ha": n_best_ha,
        "n_best_draw": n_best_d,
        "features": {"ha": feat_ha, "draw": feat_draw},
        "medians": {"global": med_global, "by_league": med_by_league},
        "calibrators": {"global": lr_global, "by_league": calibrators_by_league},
        "tau": {"global": 1.0, "by_league": tau_by_lid},
        "mix_out_params": {"b0": float(b0), "b1": float(b1), "b2": float(b2), "b3": float(b3)},
        "delta_draw_logit": float(delta_draw),
    }, OUT_FILE_RES)
    print(f"[OUT] Saved: {OUT_FILE_RES}")

    return {
        "acc": acc, "ll": ll,
        "mix_out": {"b0": b0, "b1": b1, "b2": b2, "b3": b3},
        "delta_draw_logit": delta_draw,
        "y3": y_va_3,
        "P": P_use
    }


# =========================
# TOTALS (Over 2.5)  — без изменений логики якорения, но с новыми half-life и Poisson
# =========================
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


def _safe_blend(p_model: np.ndarray, p_mkt: np.ndarray, alpha) -> np.ndarray:
    p_model = np.asarray(p_model, dtype="float64")
    p_mkt = np.asarray(p_mkt, dtype="float64")
    out = p_model.copy()
    if np.isscalar(alpha):
        alpha = float(alpha)
        use_mkt = np.isfinite(p_mkt)
        if alpha > 0 and use_mkt.any():
            out[use_mkt] = (1.0 - alpha) * p_model[use_mkt] + alpha * p_mkt[use_mkt]
        return sanitize_prob(out)
    else:
        alpha = np.asarray(alpha, dtype="float64")
        use_mkt = np.isfinite(p_mkt)
        if use_mkt.any():
            out[use_mkt] = (1.0 - alpha[use_mkt]) * p_model[use_mkt] + alpha[use_mkt] * p_mkt[use_mkt]
        return sanitize_prob(out)


def train_totals(df_train: pd.DataFrame):
    if "league_id" not in df_train.columns:
        print("[WARN] league_id missing in df_train -> using global-only imputation")
        df_train = df_train.copy();
        df_train["league_id"] = np.nan

    prev = None
    try:
        prev = joblib.load(OUT_FILE_TOT)
    except Exception:
        prev = None

    tr, cal, va = split_tr_cal_va(df_train)
    if tr.empty or cal.empty or va.empty:
        raise RuntimeError("Пустые выборки для TOTALS.")

    feature_cols_all = build_feature_cols(tr)
    na_ratio = tr[feature_cols_all].isna().mean()
    nunique = tr[feature_cols_all].nunique(dropna=True)
    drop_cols = [c for c in feature_cols_all if (na_ratio[c] > 0.98) or (nunique[c] <= 1)]
    feature_cols = [c for c in feature_cols_all if c not in drop_cols]

    feature_cols = _drop_suspicious_corr_features(cal, feature_cols, target_col="target_over25", thr=0.98)

    warm_ok_tot = False
    booster_prev_tot = None
    if prev and "booster" in prev and "features" in prev and set(prev["features"]) == set(feature_cols):
        feature_cols = list(prev["features"])
        warm_ok_tot = True
        booster_prev_tot = prev["booster"]
        print("[OVR] Warm-start TOT: features match, continuing.")

    med_global, med_by_league = compute_league_medians(tr, feature_cols)
    X_tr = impute_with_league(tr, feature_cols, med_global, med_by_league)
    X_cal = impute_with_league(cal, feature_cols, med_global, med_by_league)
    X_va = impute_with_league(va, feature_cols, med_global, med_by_league)

    print(f"[OVR] Features used: {len(feature_cols)} (dropped by NaN/const: {len(drop_cols)})")

    y_tr = tr["target_over25"].astype("int32").values
    y_cal = cal["target_over25"].astype("int32").values
    y_va = va["target_over25"].astype("int32").values

    pos = (y_tr == 1).sum();
    neg = (y_tr == 0).sum()
    spw = float(neg / max(1, pos))

    params = {
        "objective": "binary:logistic", "eval_metric": "logloss",
        "eta": 0.10, "max_depth": 4, "subsample": 0.85, "colsample_bytree": 0.85,
        "min_child_weight": 8, "gamma": 0.2, "lambda": 2.2, "alpha": 0.15,
        "seed": 43, "tree_method": "hist",
        "monotone_constraints": "(" + ",".join(map(str, build_mono_totals(feature_cols))) + ")",
        "scale_pos_weight": spw
    }

    w_tr_tot = recency_weights(tr, half_life_days=RECENCY_HALFLIFE_DAYS)
    dtr = xgb.DMatrix(X_tr.values, label=y_tr, weight=w_tr_tot, feature_names=feature_cols)
    dcal = xgb.DMatrix(X_cal.values, label=y_cal, feature_names=feature_cols)
    dva = xgb.DMatrix(X_va.values, label=y_va, feature_names=feature_cols)

    rounds_tot = 600 if warm_ok_tot else 800
    model = xgb.train(params=params, dtrain=dtr, num_boost_round=rounds_tot,
                      evals=[(dtr, "train"), (dcal, "cal")],
                      early_stopping_rounds=80, verbose_eval=200,
                      xgb_model=(booster_prev_tot if warm_ok_tot else None))
    n_best = best_ntree_limit(model)
    export_feature_importance(model, feature_cols, FI_TOT)

    p_cal_raw = predict_best(model, dcal, n_best).astype("float64")
    p_va_raw = predict_best(model, dva, n_best).astype("float64")

    if FREEZE_CALIB and prev and ("iso_global" in prev):
        iso_global = prev["iso_global"]
        iso_by_league = prev.get("iso_by_league", {})
        print("[OVR] FREEZE_CALIB=True -> использую сохранённые изотоники.")
    else:
        iso_global = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
        try:
            iso_global.fit(p_cal_raw, y_cal)
        except Exception:
            pass
        iso_by_league = {}
        lids_cal_series = pd.to_numeric(cal["league_id"], errors="coerce")
        for lid in cal["league_id"].dropna().unique():
            m = (lids_cal_series == int(lid)).to_numpy()
            if m.sum() >= 120:
                iso_l = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
                try:
                    iso_l.fit(p_cal_raw[m], y_cal[m])
                    iso_by_league[int(lid)] = iso_l
                except Exception:
                    continue

    def apply_iso_per_league(p_raw, df_like):
        out = np.zeros_like(p_raw)
        lids_series = pd.to_numeric(df_like["league_id"], errors="coerce")
        used = np.zeros(len(df_like), dtype=bool)
        for lid, iso_l in iso_by_league.items():
            m = (lids_series == int(lid)).to_numpy()
            if m.any():
                out[m] = _safe_iso_predict(iso_l, p_raw[m]);
                used[m] = True
        if (~used).any():
            out[~used] = _safe_iso_predict(iso_global, p_raw[~used])
        return sanitize_prob(out)

    p_cal_iso = apply_iso_per_league(p_cal_raw, cal)
    p_va_iso = apply_iso_per_league(p_va_raw, va)

    # Poisson p_over25 на CAL/VA (через те же регрессоры)
    pois = train_poisson_regressors(tr, cal, va, feature_cols, med_global, med_by_league)
    _, p_over_cal = build_poisson_probs_for_df(pois["lam_h_cal"], pois["lam_a_cal"])
    _, p_over_va = build_poisson_probs_for_df(pois["lam_h_va"], pois["lam_a_va"])

    # Подбор w_tot на CAL
    orr_cal = pd.to_numeric(cal.get("overround_1x2"), errors="coerce").fillna(1.08).values
    nbk_cal = pd.to_numeric(cal.get("n_bookmakers"), errors="coerce").fillna(3).values
    sumL_cal = np.clip(pois["lam_h_cal"] + pois["lam_a_cal"], 0, 6)
    inv_orr_cal = 1.0 / np.clip(orr_cal, 1.01, 1.25)
    ln_nbk_cal = np.log1p(np.clip(nbk_cal, 0, 50))

    best_c = (0.0, 2.5, 0.2, 0.4, 1e9)
    for c0 in (-0.5, -0.25, 0.0, 0.25, 0.5):
        for c1 in (1.0, 2.0, 3.0, 4.0):
            for c2 in (0.0, 0.2, 0.4, 0.6):
                for c3 in (0.0, 0.2, 0.4, 0.6, 0.8):
                    w = _sigmoid(c0 + c1 * inv_orr_cal + c2 * ln_nbk_cal - c3 * sumL_cal)
                    pmix = sanitize_prob(w * p_cal_iso + (1 - w) * p_over_cal)
                    ll = safe_log_loss(y_cal, pmix, labels=[0, 1])
                    if ll < best_c[4]:
                        best_c = (float(c0), float(c1), float(c2), float(c3), float(ll))
    c0, c1, c2, c3, _ = best_c
    print(f"[OVR] Best w_tot on CAL: c0={c0:.3f} c1={c1:.3f} c2={c2:.3f} c3={c3:.3f}")

    # Применение на VAL
    orr_va = pd.to_numeric(va.get("overround_1x2"), errors="coerce").fillna(1.08).values
    nbk_va = pd.to_numeric(va.get("n_bookmakers"), errors="coerce").fillna(3).values
    sumL_va = np.clip(pois["lam_h_va"] + pois["lam_a_va"], 0, 6)
    inv_orr_va = 1.0 / np.clip(orr_va, 1.01, 1.25)
    ln_nbk_va = np.log1p(np.clip(nbk_va, 0, 50))

    w_tot = _sigmoid(c0 + c1 * inv_orr_va + c2 * ln_nbk_va - c3 * sumL_va)
    p_va_mix = sanitize_prob(w_tot * p_va_iso + (1 - w_tot) * p_over_va)

    # Alpha к рынку + динамика
    if FREEZE_CALIB and prev:
        alpha_mkt_global = prev.get("alpha_market_global", ALPHA_MKT_FLOOR_TOT)
        alpha_mkt_by_lid = prev.get("alpha_market_by_league", {})
        print(f"[OVR] FREEZE_CALIB=True -> alpha_global={alpha_mkt_global:.2f} (из pkl).")
    else:
        alpha_mkt_global = ALPHA_MKT_FLOOR_TOT
        alpha_mkt_by_lid = {}
        if "p_over_mkt" in cal.columns:
            pm_cal = sanitize_prob(cal["p_over_mkt"].astype("float64").values)
            best = (ALPHA_MKT_FLOOR_TOT, safe_log_loss(y_cal, p_cal_iso, labels=[0, 1]))
            for a in np.linspace(ALPHA_MKT_FLOOR_TOT, 0.60, 9):
                mix = _safe_blend(p_cal_iso, pm_cal, a)
                ll = safe_log_loss(y_cal, mix, labels=[0, 1])
                if ll < best[1]: best = (float(a), float(ll))
            alpha_mkt_global = best[0]

            lids_cal = pd.to_numeric(cal["league_id"], errors="coerce").values
            for lid in sorted(pd.Series(lids_cal).dropna().unique().astype(int)):
                m = (lids_cal == lid) & np.isfinite(pm_cal)
                if m.sum() < max(40, ALPHA_MIN_N): continue
                best_l = (alpha_mkt_global, safe_log_loss(y_cal[m], p_cal_iso[m], labels=[0, 1]))
                for a in np.linspace(ALPHA_MKT_FLOOR_TOT, 0.60, 7):
                    mix = _safe_blend(p_cal_iso[m], pm_cal[m], a)
                    ll = safe_log_loss(y_cal[m], mix, labels=[0, 1])
                    if ll < best_l[1]: best_l = (float(a), float(ll))
                alpha_mkt_by_lid[lid] = best_l[0]

    if "p_over_mkt" in va.columns:
        pm_va = sanitize_prob(va["p_over_mkt"].astype("float64").values)
        alpha_arr_base = _map_by_league(va["league_id"], alpha_mkt_by_lid, alpha_mkt_global)
        alpha_arr_dyn = dynamic_alpha(orr_va, nbk_va, sum_lambda_arr=sumL_va, floor=ALPHA_MKT_FLOOR_TOT, ceil=0.65)
        alpha_arr = np.maximum(alpha_arr_base, alpha_arr_dyn)
        p_va_use = _safe_blend(p_va_mix, pm_va, alpha_arr)
        alpha_used = alpha_arr
    else:
        p_va_use = sanitize_prob(p_va_mix)
        alpha_used = np.zeros(len(va), dtype="float64")

    pred_va = (p_va_use >= 0.5).astype("int32")
    print()
    print(
        f"[OVR] acc={safe_acc(y_va, pred_va):.4f}  LL={safe_log_loss(y_va, p_va_use, labels=[0, 1]):.4f}  Brier={brier_score_loss(y_va, p_va_use):.4f}  alpha_mkt_global={alpha_mkt_global:.2f}")

    print("\n[OVR] Лиговая разбивка (валидация)")
    for lid in sorted(va["league_id"].dropna().unique()):
        m = league_mask_bool(va, int(lid))
        if m.sum() < 4: continue
        y_l = y_va[m];
        p_l = p_va_use[m]
        pred_l = (p_l >= 0.5).astype("int32")
        ll = safe_log_loss(y_l, p_l, labels=[0, 1])
        br = brier_score_loss(y_l, p_l)
        print(f"League {int(lid)}: n={int(m.sum())} acc={safe_acc(y_l, pred_l):.4f} LL={ll:.4f} Brier={br:.4f}")

    if DEBUG_EXPORT:
        p_over_mkt = pd.to_numeric(va.get("p_over_mkt", np.nan), errors="coerce").values
        out_dbg = pd.DataFrame({
            "fixture_id": va["fixture_id"].values,
            "date_utc": va["date_utc"].values,
            "league_id": pd.to_numeric(va["league_id"], errors="coerce").values,
            "home_team_id": pd.to_numeric(va["home_team_id"], errors="coerce").values,
            "away_team_id": pd.to_numeric(va["away_team_id"], errors="coerce").values,
            "y_over25": y_va,
            "p_over": p_va_use,
            "p_over_mkt": p_over_mkt,
            "alpha_used": alpha_used
        })
        try:
            out_dbg.to_csv(DEBUG_OUT_TOTALS, index=False)
            print(f"[OVR] Debug (totals) saved -> {DEBUG_OUT_TOTALS}  rows={len(out_dbg)}")
        except Exception as e:
            print(f"[OVR] Debug export failed: {e}")

    joblib.dump({
        "booster": model, "best_ntree_limit": n_best,
        "features": feature_cols,
        "impute": {"global": med_global.to_dict(),
                   "by_league": {int(k): v.to_dict() for k, v in med_by_league.items()}},
        "iso_global": iso_global, "iso_by_league": iso_by_league,
        "alpha_market_global": float(alpha_mkt_global),
        "alpha_market_by_league": {int(k): float(v) for k, v in
                                   (alpha_mkt_by_lid.items() if isinstance(alpha_mkt_by_lid, dict) else {})},
        "alpha_floor": float(ALPHA_MKT_FLOOR_TOT),
        "mix_tot_params": {"c0": c0, "c1": c1, "c2": c2, "c3": c3}
    }, OUT_FILE_TOT)
    print(f"[OVR] Saved: {OUT_FILE_TOT}")

    return {"va": va, "y": y_va, "p": p_va_use, "thr": 0.5}


# =========================
# MAIN
# =========================
if __name__ == "__main__":
    # строим датасет
    df_train = build_dataset(return_all=False)
    print("has league_id:", "league_id" in df_train.columns)
    print(df_train[["fixture_id", "league_id"]].head())
    seas = sorted(df_train["season"].dropna().unique())
    print(f"Train rows: {len(df_train)}; seasons: {seas}")

    # тренируем
    out_res = train_outcomes(df_train)
    ovr_res = train_totals(df_train)

    # сводка
    print("\n=== SUMMARY (Validation, recent window) ===")
    y3 = out_res["y3"];
    P = out_res["P"];
    pred = P.argmax(axis=1)
    print(
        f"OUT: acc={safe_acc(y3, pred):.4f} LL={safe_log_loss(y3, P, labels=[0, 1, 2]):.4f} counts={np.unique(y3, return_counts=True)[1].tolist()}")

    y = ovr_res["y"];
    p = ovr_res["p"];
    thr = ovr_res["thr"]
    pred_ovr = (p >= thr).astype("int32")
    print(
        f"OVR: acc={safe_acc(y, pred_ovr):.4f} LL={safe_log_loss(y, p, labels=[0, 1]):.4f} Brier={brier_score_loss(y, p):.4f} thr={thr:.2f}")



