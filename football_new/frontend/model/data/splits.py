# data/splits.py

import numpy as np
import pandas as pd
from datetime import timedelta
from typing import Optional


def resolve_now(ts: pd.Series, override: Optional[str] = None) -> pd.Timestamp:
    """
    now: максимум по дате, либо принудительный override (строка с датой).
    """
    if override:
        return pd.to_datetime(override, utc=True)
    return pd.to_datetime(ts.max(), utc=True)


def temporal_split_by_league(
    df: pd.DataFrame,
    ts_col: str = "date_utc",
    league_col: str = "league_id",
    cal_days: int = 90,
    val_days: int = 14,
    gap_days: int = 0,
    min_cal_per_league: int = 12,
    min_val_per_league: int = 6,
    now_override: Optional[str] = None,
):
    """
    TR / CAL / VAL сплит по времени отдельно по каждой лиге,
    с гарантированным минимальным количеством матчей в окнах.
    """
    df = df.copy()
    df[ts_col] = pd.to_datetime(df[ts_col], utc=True, errors="coerce")
    df[league_col] = pd.to_numeric(df[league_col], errors="coerce")

    now = resolve_now(df[ts_col], now_override)
    td = timedelta

    val_end_glob = now - td(days=gap_days)
    val_start_glob = val_end_glob - td(days=val_days)
    cal_end_glob = val_start_glob
    cal_start_glob = cal_end_glob - td(days=cal_days)

    tr_parts, cal_parts, val_parts = [], [], []
    used_fixtures = set()

    for lid, g in df.groupby(league_col):
        if g.empty:
            continue

        g = g.sort_values(ts_col).reset_index(drop=True)
        league_max = g[ts_col].max()

        val_end = min(val_end_glob, league_max)
        val_start = val_end - td(days=val_days)
        cal_end = min(cal_end_glob, val_start)
        cal_start = cal_end - td(days=cal_days)

        val_part = g[(g[ts_col] > val_start) & (g[ts_col] <= val_end)].copy()
        needed_val = max(min_val_per_league, len(g) // 4)
        if len(val_part) < needed_val:
            val_part = g.tail(needed_val).copy()

        remaining = g.drop(val_part.index)

        cal_part = remaining[(remaining[ts_col] > cal_start) & (remaining[ts_col] <= cal_end)].copy()
        needed_cal = max(min_cal_per_league, len(g) // 3)
        if len(cal_part) < needed_cal:
            cal_part = remaining.tail(needed_cal).copy()

        remaining = remaining.drop(cal_part.index)

        tr_parts.append(remaining)
        cal_parts.append(cal_part)
        val_parts.append(val_part)

    def _dedup(part_list):
        nonlocal used_fixtures
        out_rows = []
        for p in part_list:
            if "fixture_id" not in p.columns:
                out_rows.append(p)
                continue
            mask = ~p["fixture_id"].isin(used_fixtures)
            used_fixtures |= set(p.loc[mask, "fixture_id"])
            out_rows.append(p.loc[mask])
        if not out_rows:
            return pd.DataFrame(columns=df.columns)
        return pd.concat(out_rows, ignore_index=True)

    tr = _dedup(tr_parts)
    cal = _dedup(cal_parts)
    val = _dedup(val_parts)

    print(
        f"[SPLIT] now={now} | "
        f"TR={tr[ts_col].min()}..{tr[ts_col].max()} | "
        f"CAL={cal[ts_col].min()}..{cal[ts_col].max()} | "
        f"VAL={val[ts_col].min()}..{val[ts_col].max()}"
    )

    return tr, cal, val


def recency_weights(
    df: pd.DataFrame,
    ts_col: str = "date_utc",
    half_life_days: int = 120,
    floor: float = 0.35,
    cap: float = 3.0,
    now_override: Optional[str] = None,
) -> np.ndarray:
    """
    Вес матча по экспоненциальному распаду по времени.
    """
    t = pd.to_datetime(df[ts_col], utc=True, errors="coerce")
    now = resolve_now(t, now_override)
    age_days = (now - t).dt.days.astype("float32")
    w = np.power(0.5, age_days / float(half_life_days))
    w = np.clip(w, floor, cap)
    return w.values.astype("float32")
