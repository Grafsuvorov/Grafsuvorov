# features/build_matrix.py
import pandas as pd


def build_feature_matrix(schedule: pd.DataFrame, feats_list, target_df=None):
    if not feats_list:
        raise RuntimeError("build_feature_matrix(): feats_list is empty")

    df = schedule.copy()

    for f in feats_list:
        df = df.merge(f, on="fixture_id", how="left")

    dups = df.columns[df.columns.duplicated()].tolist()
    if dups:
        raise RuntimeError(f"Duplicate feature columns after merge: {dups}")
    bad = [c for c in df.columns if c.endswith("_x") or c.endswith("_y")]
    if bad:
        raise RuntimeError(f"Merge suffix columns detected (_x/_y): {bad}")

    if target_df is not None:
        df = df.merge(target_df, on="fixture_id", how="left")

    return df
