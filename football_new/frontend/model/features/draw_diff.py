import pandas as pd


_SKIP_COLS = {
    "home_team_id",
    "away_team_id",
    "home_goals",
    "away_goals",
    "home_xg",
    "away_xg",
}


def add_draw_diff_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Add symmetric diff features for home/away pairs to help draw modeling.
    """
    out = df.copy()
    added = {}
    for col in df.columns:
        if not col.startswith("home_"):
            continue
        if col in _SKIP_COLS:
            continue
        base = col[len("home_"):]
        away_col = f"away_{base}"
        if away_col not in df.columns or away_col in _SKIP_COLS:
            continue
        if not (pd.api.types.is_numeric_dtype(df[col]) and pd.api.types.is_numeric_dtype(df[away_col])):
            continue

        diff_name = f"{base}_diff"
        abs_name = f"{base}_abs_diff"
        if diff_name in out.columns:
            continue
        diff = df[col] - df[away_col]
        added[diff_name] = diff
        added[abs_name] = diff.abs()

    if added:
        out = pd.concat([out, pd.DataFrame(added, index=df.index)], axis=1)

    return out
