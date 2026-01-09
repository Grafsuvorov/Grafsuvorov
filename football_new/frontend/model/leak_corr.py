# leak_corr.py
import numpy as np
import pandas as pd
from data.build_dataset import build_dataset
from data.splits import build_feature_cols

def main():
    df = build_dataset()
    feats = build_feature_cols(df)

    # y для корреляции (упростим: home win =1, else =0)
    y_hw = (df["target_result"] == 1).astype(int)

    rows = []
    for f in feats:
        x = pd.to_numeric(df[f], errors="coerce")
        if x.notna().sum() < 50:
            continue
        corr = x.corr(y_hw)
        if np.isfinite(corr):
            rows.append((f, float(abs(corr)), float(corr)))
    out = pd.DataFrame(rows, columns=["feature","abs_corr","corr"]).sort_values("abs_corr", ascending=False)
    print(out.head(30).to_string(index=False))

    # отдельный чек: фичи, которые идеально совпадают со значениями таргета (редко, но бывает)
    suspicious = []
    y3 = df["target_result"].map({-1:0,0:1,1:2}).astype(int)
    for f in feats:
        x = pd.to_numeric(df[f], errors="coerce")
        if x.notna().mean() < 0.9:
            continue
        # грубо: если x принимает 3 значения и они совпадают с y3
        uniq = sorted(pd.Series(x.dropna().unique()).head(10).tolist())
        if len(uniq) <= 6:
            # попробуем нормализовать/округлить и сравнить
            xr = np.round(x.fillna(-999).values, 3)
            if (xr == y3.values).mean() > 0.95:
                suspicious.append(f)
    print("suspicious equality feats:", suspicious)

if __name__ == "__main__":
    main()
