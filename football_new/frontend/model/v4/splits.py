from __future__ import annotations

from datetime import timedelta

import pandas as pd


def temporal_split_by_league(
    df: pd.DataFrame,
    ts_col: str = "date_utc",
    league_col: str = "league_id",
    cal_days: int = 120,
    val_days: int = 30,
    gap_days: int = 0,
):
    df = df.copy()
    df[ts_col] = pd.to_datetime(df[ts_col], utc=True, errors="coerce")
    now = pd.to_datetime(df[ts_col].max(), utc=True)

    val_end_glob = now - timedelta(days=gap_days)
    val_start_glob = val_end_glob - timedelta(days=val_days)
    cal_end_glob = val_start_glob
    cal_start_glob = cal_end_glob - timedelta(days=cal_days)

    tr_parts = []
    cal_parts = []
    val_parts = []
    used = set()

    for _, g in df.groupby(league_col):
        g = g.sort_values(ts_col).reset_index(drop=True)
        val = g[(g[ts_col] > val_start_glob) & (g[ts_col] <= val_end_glob)].copy()
        if len(val) < 10:
            val = g.tail(min(len(g), 10)).copy()
        rem = g.drop(val.index)
        cal = rem[(rem[ts_col] > cal_start_glob) & (rem[ts_col] <= cal_end_glob)].copy()
        if len(cal) < 20:
            cal = rem.tail(min(len(rem), 20)).copy()
        tr = rem.drop(cal.index)
        tr_parts.append(tr)
        cal_parts.append(cal)
        val_parts.append(val)

    def _dedup(parts):
        nonlocal used
        out = []
        for p in parts:
            mask = ~p["fixture_id"].isin(used)
            used |= set(p.loc[mask, "fixture_id"])
            out.append(p.loc[mask])
        return pd.concat(out, ignore_index=True) if out else pd.DataFrame(columns=df.columns)

    return _dedup(tr_parts), _dedup(cal_parts), _dedup(val_parts)
