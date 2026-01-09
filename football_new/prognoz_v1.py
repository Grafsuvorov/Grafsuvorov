# -*- coding: utf-8 -*-
"""
Прогноз 1X2 и Totals БЕЗ утечек, с подробной отладкой и безопасным чтением фичей.

Ключевой фикс: prior Home/Away и Over2.5/Draw считаются по истории ТОЛЬКО ДО даты матча
(с возможным окном lookback), без использования будущих результатов.

ВАЖНО: в этом скрипте для джойнов/источника prior используется ПЕРВАЯ версия таблицы расписания:
    football.api_football_schedule
"""

import warnings

warnings.filterwarnings("ignore", category=FutureWarning, module="pandas")
warnings.filterwarnings("ignore", category=UserWarning, module="xgboost")

import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

import os
import re
import argparse
import traceback
from pathlib import Path
import importlib.util
from types import ModuleType
from typing import Optional, Callable, Dict, Any, List

try:
    from dotenv import load_dotenv  # type: ignore
except ImportError:  # optional dependency for local runs
    load_dotenv = None

import numpy as np
import pandas as pd
import joblib
import xgboost as xgb

from sqlalchemy import create_engine, MetaData, Table, text
from sqlalchemy.dialects.postgresql import insert as pg_insert

# =========================
# CONFIG
# =========================
DEFAULT_MODEL_OUTCOME_FILE = "xgb_outcome_final_safe.pkl"
DEFAULT_MODEL_TOTAL_FILE   = "xgb_over25_final_safe.pkl"


def _load_env_file(path: Path):
    """Minimal .env loader used when python-dotenv is unavailable."""
    try:
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.lower().startswith("export "):
                line = line[7:].strip()
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            if not os.environ.get(key):
                os.environ[key] = value
    except Exception:
        pass


def _bootstrap_env():
    """Load environment variables from common .env files if present."""
    here = Path(__file__).resolve().parent
    api_dir = here / "api"
    candidates = [
        here / ".env.local",
        here / ".env",
        api_dir / ".env",
        api_dir / ".env_test",
        api_dir / ".test_env",
    ]
    for path in candidates:
        if not path.exists():
            continue
        if load_dotenv is not None:
            load_dotenv(path, override=False)
        else:
            _load_env_file(path)


_bootstrap_env()

DB_SCHEMA = os.getenv("DB_SCHEMA", "football")
DB_TABLE  = os.getenv("DB_TABLE", "ml_predictions")


def _compose_db_url() -> str:
    env_url = os.getenv("DB_URL") or os.getenv("DATABASE_URL")
    if env_url:
        return env_url
    scheme = os.getenv("DB_SCHEME", "postgresql+psycopg2")
    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASSWORD")
    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    name = os.getenv("DB_NAME", "dwh")
    if not user or password is None:
        raise RuntimeError(
            "Set DB_URL/DATABASE_URL or DB_USER/DB_PASSWORD environment variables for database connection."
        )
    return f"{scheme}://{user}:{password}@{host}:{port}/{name}"


DB_URL    = _compose_db_url()

CONF_RATING = {
    "STRONG": {"ev": 0.08, "p": 0.50, "ev_alt": 0.12, "p_alt": 0.40},
    "MED":    {"ev": 0.04, "p": 0.40, "ev_alt": 0.08, "p_alt": 0.30},
    "WEAK":   {"ev": 0.01, "p": 0.35},
    "CLOSE_DIFF": 0.03,
    "MIN_BOOKS": 3
}

AWAY_GUARD = {
    "prob_floor": {"Strong": 0.48, "Medium": 0.45, "Weak": 0.40},
    "odds_cap": {"Strong": 3.2, "Medium": 2.8, "Weak": 2.6}
}

# Управление выбором ставки (где переключаемся на ничью / тотал)
BET_DECISION_CFG = {
    "close_gap": float(os.getenv("BET_CLOSE_GAP", 0.08)),
    "close_draw_prob": float(os.getenv("BET_CLOSE_DRAW_PROB", 0.30)),
    "draw_ev_margin": float(os.getenv("BET_DRAW_EV_MARGIN", 0.005)),
    "draw_min_ev": float(os.getenv("BET_DRAW_MIN_EV", 0.01)),
    "close_min_ev": float(os.getenv("BET_CLOSE_MIN_EV", 0.015)),
    "total_switch_margin": float(os.getenv("BET_TOTAL_SWITCH_MARGIN", 0.00)),
    "total_min_ev": float(os.getenv("BET_TOTAL_MIN_EV", 0.015)),
}

# Якоря к рынку (минимальная доля бленда)
ALPHA_FLOOR_1X2 = float(os.getenv("ALPHA_FLOOR_1X2", 0.15))
ALPHA_FLOOR_TOT = float(os.getenv("ALPHA_FLOOR_TOT", 0.40))  # синхронизация с тренером

# Управление ничьёй (послепродовая логика)
DRAW_PRIOR_BETA   = float(os.getenv("DRAW_PRIOR_BETA",   0.35))
DRAW_CAP_ABS      = float(os.getenv("DRAW_CAP_ABS",      0.32))
DRAW_CAP_DELTA_MK = float(os.getenv("DRAW_CAP_DELTA_MK", 0.05))

# Правило “close game ⇒ draw”
CLOSE_TAU        = float(os.getenv("CLOSE_TAU",        0.03))
CLOSE_PMIN_DRAW  = float(os.getenv("CLOSE_PMIN_DRAW",  0.32))
CLOSE_MARGIN     = float(os.getenv("CLOSE_MARGIN",     0.05))

# Анти-HOME
HA_SHRINK_BETA     = float(os.getenv("HA_SHRINK_BETA",     0.35))
HA_Q_DELTA_UP      = float(os.getenv("HA_Q_DELTA_UP",      0.05))
HA_Q_DELTA_DOWN    = float(os.getenv("HA_Q_DELTA_DOWN",    0.08))
HA_CAP_ABS         = float(os.getenv("HA_CAP_ABS",         0.70))
AWAY_CAP_ABS       = float(os.getenv("AWAY_CAP_ABS",       0.70))

# Сколько дней смотреть назад для HA/Draw/Over prior (0/None = вся история до матча)
HA_PRIOR_LOOKBACK_DAYS = int(os.getenv("HA_PRIOR_LOOKBACK_DAYS", 365))

TOP_K_DEFAULT = 14  # explain (top-k rows for feature explanations)


_MODULE_CACHE: Dict[Path, ModuleType] = {}


def _load_module_from_path(path: Path, name_hint: str) -> ModuleType:
    path = Path(path).resolve()
    cached = _MODULE_CACHE.get(path)
    if cached is not None:
        return cached
    spec = importlib.util.spec_from_file_location(f"{name_hint}_{abs(hash(path))}", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load module from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[attr-defined]
    _MODULE_CACHE[path] = module
    return module

# =========================
# HELPERS
# =========================
def _best_ntree_limit(booster):
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

def _predict_with_limit(booster, dmatrix, n_best):
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


def _predict_single_row(booster, frame: pd.DataFrame, feature_names, n_best):
    if booster is None:
        return np.nan
    if hasattr(booster, "inplace_predict"):
        try:
            kwargs = {}
            if n_best is not None:
                kwargs["iteration_range"] = (0, int(n_best))
            preds = booster.inplace_predict(frame, **kwargs)
            preds = np.asarray(preds, dtype=float)
            if preds.size:
                return float(preds.flat[0])
        except Exception:
            pass
    dmatrix = xgb.DMatrix(frame.values, feature_names=feature_names)
    preds = _predict_with_limit(booster, dmatrix, n_best)
    preds = np.asarray(preds, dtype=float)
    return float(preds.flat[0])

def _find_and_load_build_dataset(search_dir: Path) -> Callable:
    """Ищем любой .py рядом, в котором есть build_dataset(); выбираем наиболее подходящий."""
    me = Path(__file__).resolve()
    candidates = []
    for p in search_dir.glob("*.py"):
        if p.resolve() == me:
            continue
        try:
            with p.open("r", encoding="utf-8", errors="ignore") as f:
                text_src = f.read(400000)
                if re.search(r"\bdef\s+build_dataset\s*\(", text_src):
                    candidates.append(p)
        except Exception:
            continue
    if not candidates:
        raise FileNotFoundError("В папке нет файла с build_dataset().")

    def score(path: Path):
        name = path.name.lower()
        s = 0
        if "model" in name: s += 3
        if "train" in name or "prognoz" in name: s += 2
        if "v" in name: s += 1
        return (-s, len(str(path)))

    candidates.sort(key=score)
    for p in candidates:
        try:
            mod = _load_module_from_path(p, "model_src")
            if hasattr(mod, "build_dataset"):
                print(f"[build_dataset] loaded from {p.name}")
                return getattr(mod, "build_dataset")
        except Exception as e:
            print(f"[build_dataset] failed to load {p.name}: {e}")
    raise RuntimeError("Нашёл кандидатов, но не смог загрузить build_dataset().")

def _resolve_build_dataset(here: Path) -> Callable:
    """
    Сначала пытаемся взять build_dataset из model_new_v3.py (жёстко),
    если нет — используем авто-поиск.
    """
    preferred = here / "model_new_v3.py"
    if preferred.exists():
        try:
            mod = _load_module_from_path(preferred, "model_src_preferred")
            if hasattr(mod, "build_dataset"):
                print("[build_dataset] using model_new_v3.py (preferred)")
                return getattr(mod, "build_dataset")
            else:
                print("[build_dataset] model_new_v3.py has no build_dataset(); trying others…")
        except Exception as e:
            print(f"⚠️ Не удалось импортировать model_new_v3.py: {e}\nПробую авто-поиск.")
    return _find_and_load_build_dataset(here)

def _safe_float(x):
    try:
        v = float(x)
        return v if np.isfinite(v) else np.nan
    except Exception:
        return np.nan

def _sigmoid(x): return 1.0 / (1.0 + np.exp(-x))
def _to_logit(p):
    p = np.clip(float(p), 1e-6, 1-1e-6)
    return np.log(p/(1-p))
def _clamp(x, lo, hi):
    return min(max(x, lo), hi)

def _impute_row(row: pd.Series, feature_list, impute_map: dict, league_id_int: Optional[int]):
    """
    Импутируем по медианам из тренера.
    impute = {"global": {...}, "by_league": {lid: {...}}}
    """
    med_global = {}
    med_by_l = {}
    if isinstance(impute_map, dict):
        if "global" in impute_map and isinstance(impute_map["global"], dict):
            med_global = impute_map["global"]
        if "by_league" in impute_map and isinstance(impute_map["by_league"], dict):
            med_by_l = impute_map["by_league"]

    med_l = med_by_l.get(int(league_id_int), {}) if league_id_int is not None else {}

    vals = {}
    for c in feature_list:
        if c == "abs_elo_diff":
            v = _safe_float(row.get("elo_diff"))
            v = abs(v) if np.isfinite(v) else np.nan
        else:
            v = _safe_float(row.get(c, np.nan))
        if not np.isfinite(v):
            if c in med_l:
                v = float(med_l.get(c))
            elif c in med_global:
                v = float(med_global.get(c))
            else:
                v = 0.0
        vals[c] = v
    return pd.DataFrame([vals], columns=feature_list)

def _market_probs_1x2_from_row(row: pd.Series):
    # нормированные вероятности, если есть
    pH = _safe_float(row.get("p_home_norm"))
    pD = _safe_float(row.get("p_draw_norm"))
    pA = _safe_float(row.get("p_away_norm"))
    if np.isfinite(pH) and np.isfinite(pD) and np.isfinite(pA):
        P = np.array([[pA, pD, pH]], dtype="float64")
        P = np.clip(P, 1e-6, 1-1e-6)
        P /= P.sum(axis=1, keepdims=True)
        return P
    # иначе из коэффициентов
    oh, od, oa = map(_safe_float, (row.get("avg_odds_home"), row.get("avg_odds_draw"), row.get("avg_odds_away")))
    inv = np.array([1/oa if (oa and oa>0) else np.nan,
                    1/od if (od and od>0) else np.nan,
                    1/oh if (oh and oh>0) else np.nan], dtype="float64")
    if np.isfinite(inv).sum() == 3:
        inv /= inv.sum()
        return inv.reshape(1,3)
    return None

def _market_prob_over_from_row(row: pd.Series):
    pm = _safe_float(row.get("p_over_mkt"))
    if np.isfinite(pm):
        return float(np.clip(pm, 1e-6, 1-1e-6))
    o_over  = _safe_float(row.get("avg_odds_over25"))
    o_under = _safe_float(row.get("avg_odds_under25"))
    if np.isfinite(o_over) and np.isfinite(o_under) and o_over>1.0 and o_under>1.0:
        inv = 1.0/o_over + 1.0/o_under
        if inv > 0:
            return float((1.0/o_over)/inv)
    return np.nan

def _ev(p, odds):
    if not np.isfinite(p) or not np.isfinite(odds) or odds <= 1.0: return np.nan
    return p * odds - 1.0

def _kelly(p, odds):
    if not np.isfinite(p) or not np.isfinite(odds) or odds <= 1.0: return np.nan
    return (odds*p - 1.0) / max(1e-9, (odds - 1.0))

def _edge(odds, p):
    if not np.isfinite(p) or p <= 0: return (np.nan, np.nan)
    fair = 1.0 / p
    return odds / fair - 1.0, fair

def _downgrade_label(label: str) -> str:
    return {"Strong": "Medium", "Medium": "Weak", "Weak": "NoBet"}.get(label, "NoBet")


def _apply_away_guard(label: str, prob: float, odds: float) -> str:
    if label == "NoBet":
        return label
    prob_floor = AWAY_GUARD.get("prob_floor", {})
    odds_cap = AWAY_GUARD.get("odds_cap", {})

    if not np.isfinite(prob) or prob <= 0:
        return "NoBet"

    odds_val = float(odds) if np.isfinite(odds) else np.nan

    while label != "NoBet":
        floor = float(prob_floor.get(label, 0.0))
        cap = float(odds_cap.get(label, np.inf))
        need_downgrade = (prob < floor) or (np.isfinite(odds_val) and odds_val > cap)
        if not need_downgrade:
            break
        label = _downgrade_label(label)
    return label


def _rate(ev, prob, p_top2_gap, n_books):
    """Классифицирует силу ставки по EV/вероятности; ослабление для close-игр и малого числа букмекеров."""
    if not np.isfinite(ev) or not np.isfinite(prob):
        return "NoBet"

    strong = ((ev >= CONF_RATING["STRONG"]["ev"] and prob >= CONF_RATING["STRONG"]["p"]) or
              (ev >= CONF_RATING["STRONG"]["ev_alt"] and prob >= CONF_RATING["STRONG"]["p_alt"]))
    med    = ((ev >= CONF_RATING["MED"]["ev"]    and prob >= CONF_RATING["MED"]["p"]) or
              (ev >= CONF_RATING["MED"]["ev_alt"] and prob >= CONF_RATING["MED"]["p_alt"]))
    weak   =  (ev >= CONF_RATING["WEAK"]["ev"]   and prob >= CONF_RATING["WEAK"]["p"])

    label = "NoBet"
    if strong:
        label = "Strong"
    elif med:
        label = "Medium"
    elif weak:
        label = "Weak"

    if (p_top2_gap is not None) and (p_top2_gap < CONF_RATING["CLOSE_DIFF"]):
        label = _downgrade_label(label)

    if (n_books is not None) and (n_books < CONF_RATING["MIN_BOOKS"]):
        label = _downgrade_label(label)

    return label

# =========================
# TRAIN-STYLE DRAW CONTROL (pre-LR)
# =========================
def _apply_draw_controls_like_train(P, row):
    pA, pD, pH = float(P[0,0]), float(P[0,1]), float(P[0,2])
    prior = _safe_float(row.get("league_draw_prior"))
    if not np.isfinite(prior): prior = 0.26
    beta = 0.15
    pD = (1.0 - beta) * pD + beta * prior
    pD_mkt = _safe_float(row.get("p_draw_norm"))
    cap_abs = 0.34
    cap_rel = (pD_mkt + 0.08) if np.isfinite(pD_mkt) else 1.0
    pD = min(pD, cap_abs, cap_rel)
    old_rem = max(1e-9, pA + pH)
    new_rem = max(1e-9, 1.0 - pD)
    scale = new_rem / old_rem
    pA, pH = pA*scale, pH*scale
    Q = np.array([[pA, pD, pH]], dtype="float64")
    Q = np.clip(Q, 1e-6, 1-1e-6); Q /= Q.sum(axis=1, keepdims=True)
    return Q

# =========================
# MODEL LOADING
# =========================
def _load_outcome_pack(path: Path):
    """
    Совместимость со СТАРЫМ форматом (booster_ha/booster_draw/...) и с НОВЫМ форматом твоего тренера
    (xgb_ha/xgb_draw, features={ha,draw}, medians, calibrators, tau).
    """
    pack = joblib.load(path)

    # Новый формат тренера
    if isinstance(pack, dict) and ("xgb_ha" in pack or "xgb_draw" in pack):
        booster_ha   = pack["xgb_ha"]
        booster_draw = pack["xgb_draw"]
        best_ha      = pack.get("n_best_ha", _best_ntree_limit(booster_ha))
        best_draw    = pack.get("n_best_draw", _best_ntree_limit(booster_draw))

        feats_blob = pack.get("features", {})
        if isinstance(feats_blob, dict):
            features   = feats_blob.get("ha", []) or []
            features_d = feats_blob.get("draw", features) or features
        else:
            features   = feats_blob or []
            features_d = pack.get("features_draw", features)

        meds = pack.get("medians", {}) or {}

        def _ensure_mapping(value):
            if value is None:
                return {}
            if isinstance(value, pd.Series):
                return value.to_dict()
            if hasattr(value, 'items'):
                return dict(value)
            try:
                return dict(value)
            except Exception:
                return {}

        med_global = {k: float(v) for k, v in _ensure_mapping(meds.get("global")).items()}

        med_by_l = {}
        for lid, ser in _ensure_mapping(meds.get("by_league")).items():
            ser_map = _ensure_mapping(ser)
            med_by_l[int(lid)] = {k: float(v) for k, v in ser_map.items()}
        impute_map = {"global": med_global, "by_league": med_by_l}

        calibrators = pack.get("calibrators", {})
        tau         = pack.get("tau", {})
        calib = {
            "lr_global": calibrators.get("global", None),
            "lr_by_league": calibrators.get("by_league", {}) or {},
            "tau_global": float(tau.get("global", 1.0)),
            "tau_by_league": tau.get("by_league", {}) or {},
            "T_HA": 1.0,
            "T_Draw": 1.0,
            "alpha_market_global": 0.0,
            "alpha_market_by_league": {}
        }
        return booster_ha, best_ha, booster_draw, best_draw, features, features_d, impute_map, calib

    # Старый ожидаемый формат (если вдруг)
    if isinstance(pack, dict) and ("booster_ha" in pack and "booster_draw" in pack):
        booster_ha   = pack["booster_ha"]
        best_ha      = pack.get("best_ntree_limit_ha", _best_ntree_limit(booster_ha))
        booster_draw = pack["booster_draw"]
        best_draw    = pack.get("best_ntree_limit_draw", _best_ntree_limit(booster_draw))
        features     = pack["features"]
        features_d   = pack.get("features_draw", features)
        impute_map   = pack.get("impute", {})
        calib        = pack.get("calib", {})
        return booster_ha, best_ha, booster_draw, best_draw, features, features_d, impute_map, calib

    if isinstance(pack, xgb.Booster):
        booster_ha = pack
        return booster_ha, _best_ntree_limit(booster_ha), None, None, [], [], {"global":{}, "by_league":{}}, {}

    raise RuntimeError(f"Неизвестный формат outcome-pack в {path}")

def _load_total_pack(path: Path):
    pack = joblib.load(path)
    booster_tot   = pack["booster"]
    best_tot      = pack.get("best_ntree_limit", _best_ntree_limit(booster_tot))
    features_tot  = pack["features"]
    impute_tot    = pack.get("impute", {})
    iso_global    = pack.get("iso_global", None)
    iso_by_league = pack.get("iso_by_league", {})
    alpha_glob    = float(pack.get("alpha_market_global", 0.0))
    alpha_by_l    = pack.get("alpha_market_by_league", {}) or {}
    alpha_floor   = float(pack.get("alpha_floor", ALPHA_FLOOR_TOT))
    min_ev_tau    = float(pack.get("min_ev_tau", 0.0))
    return (booster_tot, best_tot, features_tot, impute_tot,
            iso_global, iso_by_league, alpha_glob, alpha_by_l, alpha_floor, min_ev_tau)

# =========================
# PRIOR providers (NO LEAK)
# =========================
def make_ha_prior_provider(df_all: pd.DataFrame, lookback_days: Optional[int] = HA_PRIOR_LOOKBACK_DAYS):
    """
    (league_id, when) -> prior(Home share among HA) по лиге на 'when' только из истории ДО 'when'.
    """
    base = df_all.dropna(subset=["home_goals", "away_goals"]).copy()
    if base.empty:
        def _prov(_lid: Optional[int], _when: pd.Timestamp) -> float:
            return 0.5
        return _prov

    base["date_utc"] = pd.to_datetime(base["date_utc"], utc=True, errors="coerce")
    out: Dict[int, Dict[str, Any]] = {}
    for lid, g in base.groupby("league_id", dropna=True):
        g = g.sort_values("date_utc")
        hw = (g["home_goals"] > g["away_goals"]).astype("int32").cumsum().to_numpy()
        aw = (g["home_goals"] < g["away_goals"]).astype("int32").cumsum().to_numpy()
        t  = g["date_utc"].astype("int64").to_numpy()  # ns
        out[int(lid)] = {"t": t, "hw": hw, "aw": aw}

    def provider(lid: Optional[int], when_ts: pd.Timestamp) -> float:
        if lid is None or int(lid) not in out or pd.isna(when_ts):
            return 0.5
        bucket = out[int(lid)]
        t_arr: np.ndarray = bucket["t"]
        hw: np.ndarray = bucket["hw"]
        aw: np.ndarray = bucket["aw"]

        t_when = pd.to_datetime(when_ts, utc=True, errors="coerce").value  # ns int
        if not np.isfinite(t_when):
            return 0.5

        idx_hi = np.searchsorted(t_arr, t_when, side="left") - 1
        if idx_hi < 0:
            return 0.5

        if lookback_days is None or int(lookback_days) <= 0:
            h = int(hw[idx_hi]); a = int(aw[idx_hi])
        else:
            delta_ns = int(lookback_days) * 24 * 3600 * (10**9)
            t_lo = t_when - delta_ns
            idx_lo = np.searchsorted(t_arr, t_lo, side="left") - 1
            if idx_lo < 0:
                h = int(hw[idx_hi]); a = int(aw[idx_hi])
            else:
                h = int(hw[idx_hi] - hw[idx_lo])
                a = int(aw[idx_hi] - aw[idx_lo])

        denom = h + a
        return (h/denom) if denom > 0 else 0.5

    return provider

def make_over25_prior_provider(prior_base: pd.DataFrame, recent_days: int = 365):
    """
    (league_id, when) -> p(Over2.5) по лиге на 'when' из окна recent_days ДО 'when'.
    """
    base = prior_base.dropna(subset=["date_utc","league_id","home_goals","away_goals"]).copy()
    if base.empty:
        def _prov(_lid: Optional[int], _when: pd.Timestamp) -> float:
            return 0.52
        return _prov

    base["date_utc"] = pd.to_datetime(base["date_utc"], utc=True, errors="coerce")
    base["is_over"]  = ((pd.to_numeric(base["home_goals"], errors="coerce") +
                         pd.to_numeric(base["away_goals"], errors="coerce")) >= 3).astype("int32")

    buckets: Dict[int, Dict[str, Any]] = {}
    for lid, g in base.groupby("league_id", dropna=True):
        g = g.sort_values("date_utc")
        t = g["date_utc"].astype("int64").to_numpy()
        c = g["is_over"].cumsum().to_numpy()
        buckets[int(lid)] = {"t": t, "c": c}

    def prov(lid: Optional[int], when_ts: pd.Timestamp) -> float:
        if lid is None or int(lid) not in buckets or pd.isna(when_ts):
            return 0.52
        b = buckets[int(lid)]
        t_arr, c_arr = b["t"], b["c"]
        t_when = pd.to_datetime(when_ts, utc=True, errors="coerce").value
        if not np.isfinite(t_when): return 0.52
        hi = np.searchsorted(t_arr, t_when, side="left") - 1
        if hi < 0: return 0.52
        if recent_days and int(recent_days) > 0:
            delta_ns = int(recent_days)*24*3600*(10**9)
            lo = np.searchsorted(t_arr, t_when - delta_ns, side="left") - 1
            cnt = int(c_arr[hi] - (c_arr[lo] if lo >= 0 else 0))
            tot = int((hi - lo) if lo >= 0 else (hi + 1))
        else:
            cnt = int(c_arr[hi]); tot = int(hi + 1)
        return (cnt / tot) if tot > 0 else 0.52

    return prov

def make_draw_prior_provider(prior_base: pd.DataFrame, recent_days: int = 365):
    """
    (league_id, when) -> p(Draw) по лиге на 'when' из окна recent_days ДО 'when'.
    """
    base = prior_base.dropna(subset=["date_utc","league_id","home_goals","away_goals"]).copy()
    if base.empty:
        def _prov(_lid: Optional[int], _when: pd.Timestamp) -> float:
            return 0.26
        return _prov

    base["date_utc"] = pd.to_datetime(base["date_utc"], utc=True, errors="coerce")
    base["is_draw"]  = (pd.to_numeric(base["home_goals"], errors="coerce") ==
                        pd.to_numeric(base["away_goals"], errors="coerce")).astype("int32")

    buckets: Dict[int, Dict[str, Any]] = {}
    for lid, g in base.groupby("league_id", dropna=True):
        g = g.sort_values("date_utc")
        t = g["date_utc"].astype("int64").to_numpy()
        c = g["is_draw"].cumsum().to_numpy()
        buckets[int(lid)] = {"t": t, "c": c}

    def prov(lid: Optional[int], when_ts: pd.Timestamp) -> float:
        if lid is None or int(lid) not in buckets or pd.isna(when_ts):
            return 0.26
        b = buckets[int(lid)]
        t_arr, c_arr = b["t"], b["c"]
        t_when = pd.to_datetime(when_ts, utc=True, errors="coerce").value
        if not np.isfinite(t_when): return 0.26
        hi = np.searchsorted(t_arr, t_when, side="left") - 1
        if hi < 0: return 0.26
        if recent_days and int(recent_days) > 0:
            delta_ns = int(recent_days)*24*3600*(10**9)
            lo = np.searchsorted(t_arr, t_when - delta_ns, side="left") - 1
            cnt = int(c_arr[hi] - (c_arr[lo] if lo >= 0 else 0))
            tot = int((hi - lo) if lo >= 0 else (hi + 1))
        else:
            cnt = int(c_arr[hi]); tot = int(hi + 1)
        return (cnt / tot) if tot > 0 else 0.26

    return prov

# =========================
# FILL LEAGUE_ID if missing (schedule v1)
# =========================
def _ensure_league_id(df: pd.DataFrame, engine):
    if "league_id" in df.columns:
        missing = df["league_id"].isna().sum()
        if missing <= 0:
            return df
        print(f"⚠️ league_id есть, но {missing} значений NaN — попробую заполнить из schedule…")
    else:
        print("⚠️ league_id отсутствует в датасете — попробую присоединить из schedule…")

    with engine.connect() as conn:
        keys = pd.read_sql(
            text("""
                SELECT DISTINCT fixture_id, league_id
                FROM football.api_football_schedule
            """), conn
        )
    out = df.merge(keys, on="fixture_id", how="left", suffixes=("", "_sched"))
    if "league_id" in out.columns and "league_id_sched" in out.columns:
        out["league_id"] = out["league_id"].fillna(out["league_id_sched"])
        out.drop(columns=["league_id_sched"], inplace=True, errors="ignore")
    print("✅ После join: has league_id =", "league_id" in out.columns,
          "; NaN count =", int(out["league_id"].isna().sum()) if "league_id" in out.columns else "n/a")
    return out

# =========================
# PRIOR base builder (schedule v1)
# =========================
def _build_prior_source(df_all: pd.DataFrame, engine) -> pd.DataFrame:
    cols = ["date_utc","league_id","home_goals","away_goals"]
    base = pd.DataFrame(columns=cols)
    have = all(c in df_all.columns for c in cols)
    if have:
        base = df_all.loc[~df_all["home_goals"].isna() & ~df_all["away_goals"].isna(), cols].copy()
    if base.empty:
        with engine.connect() as conn:
            base = pd.read_sql(
                text("""
                  SELECT date::timestamp as date_utc, league_id, home_goals, away_goals
                  FROM football.api_football_schedule
                  WHERE home_goals IS NOT NULL AND away_goals IS NOT NULL
                """), conn
            )
    base["date_utc"] = pd.to_datetime(base["date_utc"], utc=True, errors="coerce")
    return base

# =========================
# CORE PER-MATCH
# =========================
def score_one_match(row, packs, table, conn,
                    ha_provider: Callable[[Optional[int], pd.Timestamp], float],
                    over25_prior: Callable[[Optional[int], pd.Timestamp], float],
                    draw_prior: Callable[[Optional[int], pd.Timestamp], float],
                    explain_topk=0, dry_run=False):

    # ===== Outcome pack
    (bo_ha, nbest_ha, bo_dr, nbest_dr,
     feat_ha, feat_dr, impute_out, calib_out) = packs["outcome"]

    # температуры (глобальные/лиг) из тренера
    T_HA          = float(calib_out.get("T_HA", 1.0))
    T_Draw        = float(calib_out.get("T_Draw", 1.0))
    T_HA_by       = calib_out.get("T_HA_by_league", {}) or {}
    T_Draw_by     = calib_out.get("T_Draw_by_league", {}) or {}

    # LR-калибровка (multinomial)
    lr_glob       = calib_out.get("lr_global", None)
    lr_by_l       = calib_out.get("lr_by_league", {}) or {}

    # τ на ничью
    tau_global    = float(calib_out.get("tau_global", 1.0))
    tau_by_league = calib_out.get("tau_by_league", {}) or {}

    # alpha к рынку (глобально/лиг)
    alpha_out_glob = float(calib_out.get("alpha_market_global", 0.0))
    alpha_out_by   = calib_out.get("alpha_market_by_league", {}) or {}

    # ===== Totals pack (optional)
    has_total = ("total" in packs)
    if has_total:
        (bo_tot, nbest_tot, feat_tot, impute_tot,
         iso_global, iso_by_l, alpha_glob_tot, alpha_by_l_tot, alpha_floor_tot, tau_min_ev) = packs["total"]

    # inputs
    league_id_num = pd.to_numeric(row.get("league_id"), errors="coerce")
    league_id_int = int(league_id_num) if pd.notna(league_id_num) else None
    when_ts = row.get("date_utc")

    # безопасные priors ДО любых преобразований
    safe_draw_prior = draw_prior(league_id_int, when_ts)
    safe_ha_prior   = ha_provider(league_id_int, when_ts)  # используется в анти-HOME

    # температуры per-league
    T_HA_use   = float(T_HA_by.get(league_id_int, T_HA)) if league_id_int is not None else T_HA
    T_Draw_use = float(T_Draw_by.get(league_id_int, T_Draw)) if league_id_int is not None else T_Draw

    # ===== Binary predictions
    # важно: фичи берём как есть, но если среди них есть 'league_draw_prior' — переписываем её безопасной
    row_safe = row.copy()
    if "league_draw_prior" in feat_dr or "league_draw_prior" in feat_ha:
        row_safe["league_draw_prior"] = safe_draw_prior

    X_ha = _impute_row(row_safe, feat_ha, impute_out, league_id_int)
    X_dr = _impute_row(row_safe, feat_dr, impute_out, league_id_int)

    p_home_bin = float(_predict_single_row(bo_ha, X_ha, feat_ha, nbest_ha))
    p_draw_raw = float(_predict_single_row(bo_dr, X_dr, feat_dr, nbest_dr))
    p_home_bin = float(np.clip(p_home_bin, 1e-6, 1-1e-6))
    p_draw_raw = float(np.clip(p_draw_raw, 1e-6, 1-1e-6))

    # ===== Temperature assembly to 3-way
    logit_home = _to_logit(p_home_bin)
    logit_draw = _to_logit(p_draw_raw)
    pD = _sigmoid(logit_draw / T_Draw_use)
    remain = 1.0 - pD
    pH_ = _sigmoid(logit_home / T_HA_use)
    pH = remain * pH_
    pA = remain * (1.0 - pH_)
    P_raw = np.array([[pA, pD, pH]], dtype="float64")
    P_raw = np.clip(P_raw, 1e-6, 1-1e-6)
    P_raw = P_raw / P_raw.sum(axis=1, keepdims=True)

    # ===== Trainer-like draw control (pre-LR) — ИСПОЛЬЗУЕМ БЕЗОПАСНЫЙ prior
    row_for_draw = row_safe.copy()
    row_for_draw["league_draw_prior"] = safe_draw_prior
    P_raw = _apply_draw_controls_like_train(P_raw, row_for_draw)

    # ===== Multinomial LR calibration (per-league)
    X_cal = np.log(P_raw / (1 - P_raw))
    lr_use = lr_by_l.get(league_id_int) if (league_id_int is not None) else None
    if lr_use is None:
        lr_use = lr_glob
    if lr_use is not None:
        P_cal = lr_use.predict_proba(X_cal)
        P_cal = np.clip(P_cal, 1e-6, 1-1e-6)
        P_cal = P_cal / P_cal.sum(axis=1, keepdims=True)
    else:
        P_cal = P_raw.copy()

    # ===== τ tilt на ничью
    tau_use = float(tau_by_league.get(league_id_int, tau_global)) if league_id_int is not None else tau_global
    P_cal_t = P_cal.copy()
    P_cal_t[0, 1] = float(np.clip(P_cal_t[0, 1] * tau_use, 1e-6, 1.0 - 1e-6))
    P_cal_t /= P_cal_t.sum(axis=1, keepdims=True)

    # ===== Market blend (per-league alpha with floor)
    alpha_out_base = max(alpha_out_glob, ALPHA_FLOOR_1X2)
    alpha_out_use  = (alpha_out_by.get(int(league_id_int), alpha_out_base)
                      if league_id_int is not None else alpha_out_base)

    P_mkt = _market_probs_1x2_from_row(row_safe)
    if (P_mkt is not None) and (alpha_out_use > 0):
        P = (1 - alpha_out_use) * P_cal_t + alpha_out_use * P_mkt
        P = np.clip(P, 1e-6, 1-1e-6)
        P = P / P.sum(axis=1, keepdims=True)
    else:
        P = P_cal_t

    # ===== Anti-HOME + strict draw bounds post-cal — prior без утечки
    pA, pD, pH = float(P[0,0]), float(P[0,1]), float(P[0,2])

    pD = (1.0 - DRAW_PRIOR_BETA) * pD + DRAW_PRIOR_BETA * safe_draw_prior
    pD_mkt = _safe_float(row_safe.get("p_draw_norm"))
    cap_rel_d = (pD_mkt + DRAW_CAP_DELTA_MK) if np.isfinite(pD_mkt) else DRAW_CAP_ABS
    pD = min(pD, DRAW_CAP_ABS, cap_rel_d)

    remain = max(1e-9, 1.0 - pD)
    den_HA = max(1e-9, pH + pA)
    qH = pH / den_HA

    qH = (1.0 - HA_SHRINK_BETA) * qH + HA_SHRINK_BETA * safe_ha_prior

    if P_mkt is not None:
        pA_m, pD_m, pH_m = float(P_mkt[0,0]), float(P_mkt[0,1]), float(P_mkt[0,2])
        den_m = max(1e-9, pH_m + pA_m)
        qH_m = pH_m / den_m
        qH_hi = qH_m + HA_Q_DELTA_UP
        qH_lo = qH_m - HA_Q_DELTA_DOWN
        qH = _clamp(qH, qH_lo, qH_hi)

    if remain > 0:
        qH_max_abs = min(1.0 - 1e-6, HA_CAP_ABS / remain)
        qH_min_abs = max(1e-6, 1.0 - (AWAY_CAP_ABS / remain))
        if np.isfinite(qH_max_abs): qH = min(qH, qH_max_abs)
        if np.isfinite(qH_min_abs): qH = max(qH, qH_min_abs)

    pH = remain * qH
    pA = remain * (1.0 - qH)

    P[0,0], P[0,1], P[0,2] = pA, pD, pH
    P = np.clip(P, 1e-6, 1-1e-6); P = P / P.sum(axis=1, keepdims=True)

    # ===== close ⇒ draw (soft)
    top2 = np.sort(P, axis=1)[:, -2:]
    pred_idx = P.argmax(axis=1)
    close_mask = (top2[:,1] - top2[:,0]) < CLOSE_TAU
    best_HA = max(P[0,0], P[0,2])
    if close_mask[0] and (P[0,1] >= CLOSE_PMIN_DRAW) and (P[0,1] >= best_HA + CLOSE_MARGIN):
        pred_idx[0] = 1

    pA_f, pD_f, pH_f = float(P[0,0]), float(P[0,1]), float(P[0,2])

    # ===== Totals
    p_over_final = np.nan
    p_under_final = np.nan
    alpha_tot_use = None
    if has_total:
        # league_over25_prior — если модель его ждёт, всегда перезаписываем безопасным prior
        if "league_over25_prior" in feat_tot:
            row_safe = row_safe.copy()
            row_safe["league_over25_prior"] = over25_prior(league_id_int, when_ts)

        # per-league alpha с флоором
        alpha_tot_base = max(alpha_glob_tot, alpha_floor_tot, ALPHA_FLOOR_TOT)
        alpha_tot_use  = (alpha_by_l_tot.get(int(league_id_int), alpha_tot_base)
                          if league_id_int is not None else alpha_tot_base)

        X_tot = _impute_row(row_safe, feat_tot, impute_tot, league_id_int)
        p_over_raw = float(_predict_single_row(bo_tot, X_tot, feat_tot, nbest_tot))
        p_over_raw = float(np.clip(p_over_raw, 1e-6, 1-1e-6))

        # isotonic per-league -> global -> fallback none
        if league_id_int is not None and isinstance(iso_by_l, dict) and (league_id_int in iso_by_l):
            try:
                p_over_iso = float(np.clip(iso_by_l[league_id_int].predict([p_over_raw])[0], 1e-6, 1-1e-6))
            except Exception:
                p_over_iso = p_over_raw
        elif iso_global is not None:
            try:
                p_over_iso = float(np.clip(iso_global.predict([p_over_raw])[0], 1e-6, 1-1e-6))
            except Exception:
                p_over_iso = p_over_raw
        else:
            p_over_iso = p_over_raw

        p_mkt_over = _market_prob_over_from_row(row_safe)
        if np.isfinite(p_mkt_over):
            p_over_final = float((1 - alpha_tot_use) * p_over_iso + alpha_tot_use * p_mkt_over)
        else:
            p_over_final = float(p_over_iso)
        p_over_final = float(np.clip(p_over_final, 1e-6, 1-1e-6))
        p_under_final = float(1.0 - p_over_final)

    # ===== market / EV / best
    def _val(col):
        return _safe_float(row_safe[col]) if col in row_safe.index else np.nan

    od_home   = _val("avg_odds_home")
    od_draw   = _val("avg_odds_draw")
    od_away   = _val("avg_odds_away")
    od_over25 = _val("avg_odds_over25")
    od_under25= _val("avg_odds_under25")
    n_books   = int(_val("n_bookmakers")) if np.isfinite(_val("n_bookmakers")) else None

    evH = _ev(pH_f, od_home);   edgeH, fairH = _edge(od_home, pH_f)
    evD = _ev(pD_f, od_draw);   edgeD, fairD = _edge(od_draw, pD_f)
    evA = _ev(pA_f, od_away);   edgeA, fairA = _edge(od_away, pA_f)

    evOver = _ev(p_over_final, od_over25) if np.isfinite(p_over_final) else np.nan
    evUnder= _ev(1.0 - p_over_final, od_under25) if np.isfinite(p_over_final) else np.nan
    edgeOver, fairOver = _edge(od_over25, p_over_final) if np.isfinite(p_over_final) else (np.nan, np.nan)
    edgeUnder, fairUnder = _edge(od_under25, 1.0 - p_over_final) if np.isfinite(p_over_final) else (np.nan, np.nan)

    cands = []
    def _push(t, outcome, odds, ev, edge):
        if np.isfinite(ev):
            cands.append((t, outcome, odds, ev, edge))
    _push("1X2",  "Home", od_home, evH, edgeH)
    _push("1X2",  "Draw", od_draw, evD, edgeD)
    _push("1X2",  "Away", od_away, evA, edgeA)
    if np.isfinite(p_over_final):
        _push("OVER25","Over2.5",  od_over25,  evOver,  edgeOver)
        _push("UNDER25","Under2.5",od_under25, evUnder, edgeUnder)

    best_candidate = ("NONE", None, np.nan, -1e-9, np.nan)
    decision_notes: List[str] = []

    totals_cands = [cand for cand in cands if cand[0] in ("OVER25", "UNDER25")]
    draw_cand = next((cand for cand in cands if cand[0] == "1X2" and cand[1] == "Draw"), None)

    if cands:
        cands.sort(key=lambda x: x[3], reverse=True)
        best_candidate = cands[0]
        decision_notes.append(f"baseline={best_candidate[0]}:{best_candidate[1]}")

        cfg_close_gap = BET_DECISION_CFG.get("close_gap", 0.0)
        cfg_draw_prob = BET_DECISION_CFG.get("close_draw_prob", 0.0)
        cfg_draw_ev_margin = BET_DECISION_CFG.get("draw_ev_margin", 0.0)
        cfg_draw_min_ev = BET_DECISION_CFG.get("draw_min_ev", 0.0)
        cfg_close_min_ev = BET_DECISION_CFG.get("close_min_ev", 0.0)

        ha_gap = abs(pH_f - pA_f)
        draw_prob = pD_f

        if best_candidate[0] == "1X2" and best_candidate[1] in ("Home", "Away"):
            if ha_gap <= cfg_close_gap:
                decision_notes.append(f"close_gap={ha_gap:.3f}")
                if draw_prob >= cfg_draw_prob and draw_cand is not None:
                    draw_ev_ok = draw_cand[3] >= cfg_draw_min_ev
                    draw_margin_ok = (draw_cand[3] + cfg_draw_ev_margin) >= best_candidate[3]
                    if draw_ev_ok and draw_margin_ok:
                        best_candidate = draw_cand
                        decision_notes.append("switch=draw_close")

                if best_candidate[0] == "1X2" and best_candidate[1] in ("Home", "Away"):
                    if best_candidate[3] < cfg_close_min_ev:
                        decision_notes.append("suppress_close_low_ev")
                        best_candidate = ("NONE", None, np.nan, np.nan, np.nan)

        if totals_cands:
            totals_cands.sort(key=lambda x: x[3], reverse=True)
            best_total = totals_cands[0]
            cfg_total_margin = BET_DECISION_CFG.get("total_switch_margin", 0.0)
            cfg_total_min_ev = BET_DECISION_CFG.get("total_min_ev", 0.0)

            need_total_switch = False
            if not np.isfinite(best_candidate[3]):
                need_total_switch = best_total[3] >= cfg_total_min_ev
            elif best_candidate[0] == "NONE":
                need_total_switch = best_total[3] >= cfg_total_min_ev
            else:
                need_total_switch = (
                    best_total[3] >= cfg_total_min_ev and
                    (best_total[3] - best_candidate[3]) >= cfg_total_margin
                )

            if need_total_switch:
                best_candidate = best_total
                decision_notes.append(f"switch=total({best_total[0]})")

    best_type, best_outc, best_odds, best_ev, best_edge = best_candidate

    if has_total and best_type in ("OVER25", "UNDER25") and ("tau_min_ev" in locals()) and (best_ev < tau_min_ev):
        decision_notes.append("filtered_by_tau")
        best_type, best_outc, best_odds, best_ev, best_edge = ("NONE", None, np.nan, np.nan, np.nan)

    P_vec = np.array([pA_f, pD_f, pH_f], dtype=float)
    top2_now = np.sort(P_vec)[-2:]
    p_gap = float(top2_now[1] - top2_now[0]) if np.all(np.isfinite(top2_now)) else None
    bet_prob = {"Home":pH_f, "Draw":pD_f, "Away":pA_f, "Over2.5":p_over_final, "Under2.5":1.0 - p_over_final}.get(best_outc, np.nan)
    bet_rating = _rate(best_ev, bet_prob, p_gap, n_books)
    if best_type == "1X2" and best_outc == "Away":
        bet_rating = _apply_away_guard(bet_rating, bet_prob, best_odds)
        if bet_rating == "Weak":
            bet_rating = "NoBet"
    if bet_rating == "NoBet":
        best_type, best_outc, best_odds, best_ev, best_edge = ("NONE", None, np.nan, np.nan, np.nan)
        bet_prob = np.nan

    bet_reason_parts = []
    note_str = ", ".join(decision_notes) if decision_notes else ""
    if best_type != "NONE":
        if np.isfinite(bet_prob):  bet_reason_parts.append(f"p={bet_prob:.2f}")
        if np.isfinite(best_odds): bet_reason_parts.append(f"odds={best_odds:.2f}")
        if np.isfinite(best_ev):   bet_reason_parts.append(f"EV={best_ev:.3f}")
        if np.isfinite(best_edge): bet_reason_parts.append(f"edge={best_edge:.2%}")
        if p_gap is not None:      bet_reason_parts.append(f"gapTop2={p_gap:.3f}")
        if n_books is not None:    bet_reason_parts.append(f"books={n_books}")
        if note_str:
            bet_reason_parts.append(f"notes={note_str}")
        bet_reason = " | ".join(bet_reason_parts)
    else:
        bet_reason = "No positive EV"
        if note_str:
            bet_reason = f"No bet: {note_str}"

    # decision index для печати
    decision_idx = int(np.array([pA_f, pD_f, pH_f]).argmax())
    payload = {
        "fixture_id": int(row_safe["fixture_id"]),
        "model_version": "xgb_outcome_total_safe_v6_noleak",
        "features_n": len(feat_ha),
        "p_home": pH_f, "p_draw": pD_f, "p_away": pA_f,
        "p_over25": float(p_over_final) if np.isfinite(p_over_final) else None,
        "p_under25": float(1.0 - p_over_final) if np.isfinite(p_over_final) else None,
        "n_bookmakers": int(row_safe["n_bookmakers"]) if pd.notna(row_safe.get("n_bookmakers")) else None,
        "avg_odds_home": _safe_float(row_safe.get("avg_odds_home")),
        "avg_odds_draw": _safe_float(row_safe.get("avg_odds_draw")),
        "avg_odds_away": _safe_float(row_safe.get("avg_odds_away")),
        "avg_odds_over25": _safe_float(row_safe.get("avg_odds_over25")),
        "avg_odds_under25": _safe_float(row_safe.get("avg_odds_under25")),
        "p_home_norm": _safe_float(row_safe.get("p_home_norm")),
        "p_draw_norm": _safe_float(row_safe.get("p_draw_norm")),
        "p_away_norm": _safe_float(row_safe.get("p_away_norm")),
        "p_over_mkt": _market_prob_over_from_row(row_safe),
        "league_draw_prior": safe_draw_prior,
        "overround_1x2": _safe_float(row_safe.get("overround_1x2")),
        "ev_home": _ev(pH_f, _safe_float(row_safe.get("avg_odds_home"))),
        "ev_draw": _ev(pD_f, _safe_float(row_safe.get("avg_odds_draw"))),
        "ev_away": _ev(pA_f, _safe_float(row_safe.get("avg_odds_away"))),
        "fair_home": _edge(_safe_float(row_safe.get("avg_odds_home")), pH_f)[1],
        "fair_draw": _edge(_safe_float(row_safe.get("avg_odds_draw")), pD_f)[1],
        "fair_away": _edge(_edge(_safe_float(row_safe.get("avg_odds_away")), pA_f)[1], 1.0)[0] if False else _edge(_safe_float(row_safe.get("avg_odds_away")), pA_f)[1],
        "edge_home": _edge(_safe_float(row_safe.get("avg_odds_home")), pH_f)[0],
        "edge_draw": _edge(_safe_float(row_safe.get("avg_odds_draw")), pD_f)[0],
        "edge_away": _edge(_safe_float(row_safe.get("avg_odds_away")), pA_f)[0],
        "kelly_home": _kelly(pH_f, _safe_float(row_safe.get("avg_odds_home")))/2.0 if np.isfinite(_safe_float(row_safe.get("avg_odds_home"))) else None,
        "kelly_draw": _kelly(pD_f, _safe_float(row_safe.get("avg_odds_draw")))/2.0 if np.isfinite(_safe_float(row_safe.get("avg_odds_draw"))) else None,
        "kelly_away": _kelly(pA_f, _safe_float(row_safe.get("avg_odds_away")))/2.0 if np.isfinite(_safe_float(row_safe.get("avg_odds_away"))) else None,
        "ev_over": _ev(p_over_final, _safe_float(row_safe.get("avg_odds_over25"))) if np.isfinite(p_over_final) else None,
        "ev_under": _ev(1.0 - p_over_final, _safe_float(row_safe.get("avg_odds_under25"))) if np.isfinite(p_over_final) else None,
        "fair_over": _edge(_safe_float(row_safe.get("avg_odds_over25")), p_over_final)[1] if np.isfinite(p_over_final) else None,
        "fair_under": _edge(_safe_float(row_safe.get("avg_odds_under25")), 1.0 - p_over_final)[1] if np.isfinite(p_over_final) else None,
        "edge_over": _edge(_safe_float(row_safe.get("avg_odds_over25")), p_over_final)[0] if np.isfinite(p_over_final) else None,
        "edge_under": _edge(_safe_float(row_safe.get("avg_odds_under25")), 1.0 - p_over_final)[0] if np.isfinite(p_over_final) else None,
        "decision_1x2": ["Away","Draw","Home"][decision_idx],
        "decision_total": ("Over" if (np.isfinite(p_over_final) and p_over_final>=0.5)
                           else "Under" if (np.isfinite(p_over_final) and (1.0 - p_over_final)>=0.5)
                           else "None"),
        "best_bet_type": best_type,
        "best_bet_outcome": best_outc,
        "best_bet_odds": best_odds if np.isfinite(best_odds) else None,
        "best_bet_ev": best_ev if np.isfinite(best_ev) else None,
        "best_bet_edge": best_edge if np.isfinite(best_edge) else None,
        "bet_rating": bet_rating,
        "bet_reason": bet_reason,
        "bet_decision_notes": note_str if note_str else None,
        "alpha_blend_outcome": alpha_out_use,
        "alpha_blend_total": alpha_tot_use if has_total else None,
    }

    # UPSERT в БД
    if not dry_run:
        tbl_cols = set(table.c.keys())
        data = {k: v for k, v in payload.items() if k in tbl_cols}
        stmt = pg_insert(table).values(**data)
        updt = stmt.on_conflict_do_update(
            index_elements=[table.c.fixture_id],
            set_={k: stmt.excluded[k] for k in data.keys() if k != "fixture_id"}
        )
        conn.execute(updt)

    return {
        "fixture_id": int(row_safe["fixture_id"]),
        "date_utc": str(row_safe["date_utc"]),
        "league_id": int(row_safe["league_id"]) if pd.notna(row_safe.get("league_id", np.nan)) else None,
        "p": (pH_f, pD_f, pA_f),
        "p_over": p_over_final if np.isfinite(p_over_final) else None,
        "bet": (best_type, best_outc, bet_rating, best_ev)
    }

# =========================
# MAIN
# =========================
def main():
    parser = argparse.ArgumentParser(description="Predict 1X2 & totals for fixtures; writes to DB (UPSERT).")
    parser.add_argument("--fixture-id", type=int, default=None, help="Конкретный fixture_id (необязательно).")
    parser.add_argument("--date-from", type=str, default=None, help="Начало диапазона дат (например 2024-12-25).")
    parser.add_argument("--date-to", type=str, default=None, help="Конец диапазона дат (например 2025-09-05).")
    parser.add_argument("--outcome-model", type=str, default=DEFAULT_MODEL_OUTCOME_FILE)
    parser.add_argument("--total-model", type=str, default=DEFAULT_MODEL_TOTAL_FILE)
    parser.add_argument("--explain-topk", type=int, default=0, help="Сохранить топ-k вкладов фич (0 — не считать).")
    parser.add_argument("--dry-run", action="store_true", help="Не писать в БД, только печать превью.")
    args = parser.parse_args()

    here = Path(__file__).resolve().parent
    if str(here) not in sys.path:
        sys.path.insert(0, str(here))

    # load models
    print(f"[OUTCOME] Loading pack: {args.outcome_model}")
    out_pack = _load_outcome_pack(here / args.outcome_model)
    packs = {"outcome": out_pack}

    has_total = (here / args.total_model).exists()
    if has_total:
        print(f"[TOTAL] Loading pack: {args.total_model}")
        tot_pack = _load_total_pack(here / args.total_model)
        packs["total"] = tot_pack
    else:
        print("ℹ️ Файл тоталов не найден — посчитаю только 1X2.")

    # dataset (отладка: откуда build_dataset)
    build_dataset = _resolve_build_dataset(here)

    df_all = build_dataset(return_all=True) if "return_all" in build_dataset.__code__.co_varnames else build_dataset()
    if "fixture_id" not in df_all.columns or "date_utc" not in df_all.columns:
        raise RuntimeError("build_dataset() должен вернуть fixture_id и date_utc")
    df_all["date_utc"] = pd.to_datetime(df_all["date_utc"], errors="coerce", utc=True)

    # debug: league_id наличие и при необходимости join из schedule (v1)
    engine_ro = create_engine(DB_URL)
    df_all = _ensure_league_id(df_all, engine_ro)

    # ===== DEBUG: состав df_all
    if "league_id" in df_all.columns:
        leagues_all = df_all["league_id"].dropna().astype(int).unique()
        print("Leagues in df_all (first 20):", leagues_all[:20])
        print("Counts by league in df_all (top 15):")
        try:
            print(df_all.groupby("league_id").size().sort_values(ascending=False).head(15))
        except Exception as e:
            print("groupby error:", e)
        mask_l1 = (df_all["league_id"].astype("Int64") == 61)
        if mask_l1.any():
            print("Ligue 1 date_utc range in df_all:",
                  df_all.loc[mask_l1, "date_utc"].min(), "->",
                  df_all.loc[mask_l1, "date_utc"].max())
        else:
            print("⚠️ Ligue 1 (61) отсутствует в df_all — build_dataset её не вернул.")
    else:
        print("⚠️ В df_all всё ещё нет league_id (не критично для прогноза, но отладка ограничена).")

    # prior-провайдеры (БЕЗ утечек)
    ha_provider    = make_ha_prior_provider(df_all, lookback_days=HA_PRIOR_LOOKBACK_DAYS)
    prior_base     = _build_prior_source(df_all, engine_ro)  # schedule v1
    over25_prior   = make_over25_prior_provider(prior_base, recent_days=365)
    draw_prior     = make_draw_prior_provider(prior_base, recent_days=365)

    # выбор матчей
    if args.fixture_id is not None:
        targets = df_all[df_all["fixture_id"] == args.fixture_id].copy()
        if targets.empty:
            raise RuntimeError(f"Матч fixture_id={args.fixture_id} не найден в df_all.")
    else:
        if args.date_from is None or args.date_to is None:
            raise RuntimeError("Нужно указать --date-from и --date-to, либо --fixture-id.")
        date_from = pd.to_datetime(args.date_from, utc=True, errors="coerce")
        date_to   = pd.to_datetime(args.date_to,   utc=True, errors="coerce")
        if pd.isna(date_from) or pd.isna(date_to):
            raise RuntimeError("Неверный формат даты.")
        mask = (df_all["date_utc"] >= date_from) & (df_all["date_utc"] <= date_to)
        targets = df_all.loc[mask].copy()
        if targets.empty:
            print("⚠️ В диапазоне дат ничего не найдено. Выходим.")
            return

    # ===== DEBUG: состав targets
    print("Targets total:", len(targets),
          "range:", targets["date_utc"].min(), "->", targets["date_utc"].max())
    if "league_id" in targets.columns:
        try:
            print("Counts by league in targets:")
            print(targets.groupby("league_id").size().sort_values(ascending=False))
        except Exception as e:
            print("groupby error (targets):", e)
        mask_l1_t = (targets["league_id"].astype("Int64") == 61)
        print("Targets Ligue 1 rows:", int(mask_l1_t.sum()))
        if mask_l1_t.any():
            print(targets.loc[mask_l1_t, ["fixture_id", "date_utc"]].sort_values("date_utc").head(10))
    else:
        print("⚠️ В targets нет league_id — покажу только общий объём.")

    # БД-таблица
    engine = create_engine(DB_URL)
    meta_db = MetaData()
    with engine.begin() as conn:
        table = Table(DB_TABLE, meta_db, schema=DB_SCHEMA, autoload_with=conn)

    ok, fail = 0, 0
    ok_l1, fail_l1 = 0, 0
    results_preview = []

    # Рассчитываем — без пересчёта пост-фактумных фичей
    with engine.begin() as conn:
        for i, (_, row) in enumerate(targets.sort_values("date_utc").iterrows(), 1):
            fid = int(row['fixture_id']) if pd.notna(row.get('fixture_id')) else -1
            lid = int(row['league_id']) if ('league_id' in row and pd.notna(row['league_id'])) else None
            try:
                res = score_one_match(row, packs, table, conn,
                                      ha_provider=ha_provider,
                                      over25_prior=over25_prior,
                                      draw_prior=draw_prior,
                                      explain_topk=args.explain_topk,
                                      dry_run=args.dry_run)
                ok += 1
                if lid == 61: ok_l1 += 1
                if len(results_preview) < 8:
                    results_preview.append(res)
                verb = "preview" if args.dry_run else "upserted"
                print(f"[{i}/{len(targets)}] ✓ fixture {res['fixture_id']} (league={res.get('league_id')}) @ {res['date_utc']} -> {verb} (best={res['bet']})")
            except Exception as e:
                fail += 1
                if lid == 61: fail_l1 += 1
                print(f"[{i}/{len(targets)}] ✗ fixture {fid} (league={lid}) error: {e}")
                traceback.print_exc(limit=1)

    print(f"\nDone. Upserted (OK): {ok}, Errors: {fail}")
    print(f"Ligue 1 only — OK: {ok_l1}, Errors: {fail_l1}")

    if results_preview:
        print("\n— preview of first results —")
        for r in results_preview:
            pH, pD, pA = r["p"][0], r["p"][1], r["p"][2]
            pOver = f"{r['p_over']:.3f}" if (r["p_over"] is not None and np.isfinite(r["p_over"])) else "na"
            print(
                f"  #{r['fixture_id']}  L={r.get('league_id')}  {r['date_utc']}  "
                f"pH={pH:.3f} pD={pD:.3f} pA={pA:.3f}  pOver={pOver}  best={r['bet']}"
            )

if __name__ == "__main__":
    main()
