# roi_hypotheses.py
import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

# ====== CONFIG ======
from config import DB_URL  # если нет - замени строкой подключения

DATE_FROM = "2025-09-01"
DATE_TO   = "2025-12-14"

SCHEMA = "football"
PRED_TABLE = "ml_predictions"

# откуда брать голы/лигy/дату
SCHEDULE_TABLE = "api_football_schedule"
# откуда брать коэффициенты (самое надёжное)
ODDS_VIEW = "v_ml_epl_training"   # у тебя там есть odds + over/under + overround
# если вдруг в ODDS_VIEW не все лиги, можно fallback на p.avg_odds_* из ml_predictions

MIN_BETS_FOR_RULE = 12   # порог “достаточно ставок”, чтобы не ловить шум
EV_THRESHOLDS = [0.00, 0.01, 0.02, 0.03, 0.05]

# “ровность” (для гипотезы про ничью)
GAP_BINS = [0.00, 0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 1.00]  # gap
HA_BINS  = [0.00, 0.02, 0.04, 0.06, 0.10, 0.20, 1.00]        # |pH-pA|

# ====== Helpers ======
def _safe_odds(x):
    try:
        v = float(x)
        if np.isfinite(v) and v > 1.01:
            return v
    except Exception:
        pass
    return np.nan

def profit_1unit(win: bool, odds: float) -> float:
    # ставка 1 unit: выигрыш = odds-1, проигрыш = -1
    if not np.isfinite(odds) or odds <= 1.01:
        return np.nan
    return (odds - 1.0) if win else -1.0

def compute_profit_row(row) -> float:
    """
    Считает профит по фактической рекомендации best_bet_type/best_bet_outcome
    с использованием odds из odds_view (или fallback).
    """
    bt = row["best_bet_type"]
    outc = row["best_bet_outcome"]
    hg, ag = row["home_goals"], row["away_goals"]

    if bt not in ("1X2", "OVER25", "UNDER25"):
        return np.nan

    if bt == "1X2":
        odds = {"Home": row["odds_home"], "Draw": row["odds_draw"], "Away": row["odds_away"]}.get(outc, np.nan)
        odds = _safe_odds(odds)
        if not np.isfinite(odds):
            return np.nan
        win = ((hg > ag and outc == "Home") or (hg == ag and outc == "Draw") or (hg < ag and outc == "Away"))
        return profit_1unit(win, odds)

    total_goals = hg + ag
    if bt == "OVER25":
        odds = _safe_odds(row["odds_over25"])
        if not np.isfinite(odds): return np.nan
        win = total_goals >= 3
        return profit_1unit(win, odds)

    if bt == "UNDER25":
        odds = _safe_odds(row["odds_under25"])
        if not np.isfinite(odds): return np.nan
        win = total_goals <= 2
        return profit_1unit(win, odds)

    return np.nan

def summarize_roi(df: pd.DataFrame) -> pd.DataFrame:
    # df must contain profit (float) and league_id
    g = df.groupby("league_id", dropna=False)
    out = g["profit"].agg(
        bets=lambda x: int(np.isfinite(x).sum()),
        profit=lambda x: float(np.nansum(x)),
    )
    out["roi"] = out["profit"] / out["bets"].replace(0, np.nan)
    return out.sort_values("roi", ascending=False)

# ====== Main ======
def main():
    engine = create_engine(DB_URL, pool_pre_ping=True)

    print("Loading data...")

    # ВАЖНО: :dfrom и :dto без ::date рядом, кастуем через CAST()
    q = text(f"""
        WITH base AS (
            SELECT
                p.fixture_id,
                p.model_version,
                p.p_home, p.p_draw, p.p_away,
                p.best_bet_type, p.best_bet_outcome,
                p.bet_rating,
                p.best_bet_ev,
                s.league_id,
                s.date::date AS match_date,
                s.home_goals,
                s.away_goals
            FROM {SCHEMA}.{PRED_TABLE} p
            JOIN {SCHEMA}.{SCHEDULE_TABLE} s
              ON s.fixture_id = p.fixture_id
            WHERE s.date::date BETWEEN CAST(:dfrom AS date) AND CAST(:dto AS date)
              AND s.home_goals IS NOT NULL
              AND s.away_goals IS NOT NULL
              AND p.best_bet_type IS NOT NULL
        ),
        odds AS (
            SELECT
                fixture_id,
                avg_odds_home  AS odds_home,
                avg_odds_draw  AS odds_draw,
                avg_odds_away  AS odds_away,
                avg_odds_over25 AS odds_over25,
                avg_odds_under25 AS odds_under25
            FROM {SCHEMA}.{ODDS_VIEW}
        )
        SELECT
            b.*,
            o.odds_home, o.odds_draw, o.odds_away, o.odds_over25, o.odds_under25
        FROM base b
        LEFT JOIN odds o USING (fixture_id)
    """)

    df = pd.read_sql(q, engine, params={"dfrom": DATE_FROM, "dto": DATE_TO})
    print(f"Loaded rows (played in range): {len(df)}")

    # fallback odds from ml_predictions если odds_view не дал
    # (если ты их туда писал; иначе просто останутся NaN и выпадут из ROI)
    # Тут намеренно НЕ делаю, чтобы ты видел реальную полноту odds_view.

    # Расчёты для гипотезы “ровность”
    probs = df[["p_home", "p_draw", "p_away"]].astype(float).to_numpy()
    top2 = np.sort(probs, axis=1)[:, -2:]
    df["gap_top2"] = top2[:, 1] - top2[:, 0]
    df["ha_gap"] = (df["p_home"] - df["p_away"]).abs()
    df["is_draw"] = (df["home_goals"] == df["away_goals"]).astype(int)

    # Профит по реальным рекомендациям
    df["profit"] = df.apply(compute_profit_row, axis=1)

    # Сколько ставок вообще с валидными odds
    valid_bets = df[np.isfinite(df["profit"])].copy()
    print(f"Valid bets with odds: {len(valid_bets)}")

    # ===== A) Проверка гипотезы: “ровные => ничья” =====
    print("\n=== Hypothesis A: draw rate by model uncertainty (gap_top2 bins) ===")
    tmp = df.copy()
    tmp["gap_bin"] = pd.cut(tmp["gap_top2"], bins=GAP_BINS, include_lowest=True)
    draw_stats = tmp.groupby("gap_bin").agg(
        matches=("fixture_id", "count"),
        draw_rate=("is_draw", "mean"),
        avg_pdraw=("p_draw", "mean"),
        avg_gap=("gap_top2", "mean"),
    ).reset_index()
    print(draw_stats.to_string(index=False))

    print("\n=== Hypothesis A2: draw rate by |p_home-p_away| bins (ha_gap) ===")
    tmp["ha_bin"] = pd.cut(tmp["ha_gap"], bins=HA_BINS, include_lowest=True)
    draw_stats2 = tmp.groupby("ha_bin").agg(
        matches=("fixture_id", "count"),
        draw_rate=("is_draw", "mean"),
        avg_pdraw=("p_draw", "mean"),
        avg_ha_gap=("ha_gap", "mean"),
    ).reset_index()
    print(draw_stats2.to_string(index=False))

    # Доп: “если бы мы ставили Draw” по EV фильтру (это уже ближе к реальной стратегии)
    print("\n=== If-bet Draw ROI by bins (EV filter) ===")
    df["odds_draw"] = df["odds_draw"].map(_safe_odds)
    df["ev_draw"] = df["p_draw"] * df["odds_draw"] - 1.0
    draw_cand = df[np.isfinite(df["odds_draw"])].copy()

    def draw_profit(r):
        return profit_1unit(r["is_draw"] == 1, r["odds_draw"])

    draw_cand["draw_profit"] = draw_cand.apply(draw_profit, axis=1)

    draw_cand["gap_bin"] = pd.cut(draw_cand["gap_top2"], bins=GAP_BINS, include_lowest=True)
    draw_roi = draw_cand.groupby("gap_bin").agg(
        bets=("draw_profit", lambda x: int(np.isfinite(x).sum())),
        profit=("draw_profit", lambda x: float(np.nansum(x))),
        avg_ev=("ev_draw", "mean"),
        draw_rate=("is_draw", "mean")
    )
    draw_roi["roi"] = draw_roi["profit"] / draw_roi["bets"].replace(0, np.nan)
    print(draw_roi.reset_index().to_string(index=False))

    # ===== B) ROI по лигам для текущих рекомендаций =====
    print("\n=== ROI by league (ALL RECOMMENDED BETS) ===")
    roi_all = summarize_roi(valid_bets)
    print(roi_all.to_string())

    # ===== B2) Выделение “подходящих” правил =====
    print("\n=== Candidate rules: league x type x rating with min bets ===")
    v = valid_bets.copy()
    g = v.groupby(["league_id", "best_bet_type", "bet_rating"], dropna=False)["profit"].agg(
        bets=lambda x: int(np.isfinite(x).sum()),
        profit=lambda x: float(np.nansum(x)),
    )
    rules = g.reset_index()
    rules["roi"] = rules["profit"] / rules["bets"].replace(0, np.nan)
    rules = rules[rules["bets"] >= MIN_BETS_FOR_RULE].sort_values(["roi", "bets"], ascending=[False, False])
    print(rules.to_string(index=False))

    print("\n=== EV-threshold scan (overall) ===")
    for thr in EV_THRESHOLDS:
        part = v[(np.isfinite(v["best_bet_ev"])) & (v["best_bet_ev"] >= thr)].copy()
        part["profit"] = part["profit"].astype(float)
        bets = int(np.isfinite(part["profit"]).sum())
        prof = float(np.nansum(part["profit"]))
        roi = prof / bets if bets else np.nan
        print(f"EV >= {thr:0.02f}: bets={bets}, profit={prof:0.3f}, roi={roi:0.4f}")

    print("\n=== Suggested 'allowed' set (positive ROI rules) ===")
    allow = rules[(rules["roi"] > 0)].copy()
    if allow.empty:
        print("No positive-ROI rules under current MIN_BETS_FOR_RULE. Lower MIN_BETS_FOR_RULE or change filters.")
    else:
        print(allow.to_string(index=False))

if __name__ == "__main__":
    main()
