import numpy as np
import pandas as pd
from collections import defaultdict, deque
from sqlalchemy import create_engine, text

from config import DB_URL
from decision.totals_decision import decide_total_bet
from decision.outcomes_decision import decide_outcome_bet

DATE_FROM = "2025-08-01"
DATE_TO = "2026-02-02"

START_BANKROLL = 10_000.0
# 1 unit stake = 1% of bankroll by default.
BANK_UNIT_PCT = 0.01

MIN_BETS_PER_MONTH_LEAGUE = 9
MAX_BETS_PER_MONTH_LEAGUE = 18

STAKE_BY_TIER = {"A": 1.0, "B": 0.4}
TARGET_MARKET_SHARE = {"TOTAL": 0.70, "1X2": 0.30}
MARKET_SCALE_MIN = 0.60
MARKET_SCALE_MAX = 1.40

ROLLING_WINDOW = 30
ROLLING_ROI_TRIGGER = -0.05
COOLDOWN_DAYS = 14

DRAWDOWN_THRESHOLD = 0.08
DRAWDOWN_STAKE_MULT = 0.75

LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}


def _fetch_data() -> pd.DataFrame:
    engine = create_engine(DB_URL)
    q = text(
        """
        SELECT
            p.fixture_id,
            s.league_id,
            s.date,
            s.home_team,
            s.away_team,
            s.home_goals,
            s.away_goals,
            p.p_home,
            p.p_draw,
            p.p_away,
            p.p_over25,
            m.avg_odds_home,
            m.avg_odds_draw,
            m.avg_odds_away,
            m.avg_odds_over25,
            m.avg_odds_under25
        FROM football.ml_predictions p
        JOIN football.api_football_schedule s
          ON s.fixture_id = p.fixture_id
        JOIN football.v_ml_epl_training m
          ON m.fixture_id = p.fixture_id
        WHERE s.date BETWEEN :dfrom AND :dto
          AND s.home_goals IS NOT NULL
          AND s.away_goals IS NOT NULL
          AND s.league_id IN (39, 61, 78, 135, 140)
        """
    )
    df = pd.read_sql(q, engine, params={"dfrom": DATE_FROM, "dto": DATE_TO})
    df["date"] = pd.to_datetime(df["date"], errors="coerce")
    df["month"] = df["date"].dt.to_period("M").astype(str)
    return df


def _build_totals_candidates(df: pd.DataFrame) -> pd.DataFrame:
    x = df.copy()
    x["p_over25"] = pd.to_numeric(x["p_over25"], errors="coerce")
    x["avg_odds_over25"] = pd.to_numeric(x["avg_odds_over25"], errors="coerce")
    x["avg_odds_under25"] = pd.to_numeric(x["avg_odds_under25"], errors="coerce")

    imp_over = 1.0 / x["avg_odds_over25"].replace(0, np.nan)
    imp_under = 1.0 / x["avg_odds_under25"].replace(0, np.nan)
    overround = imp_over + imp_under
    x["p_market"] = imp_over / overround

    x["p_model"] = x["p_over25"]
    x.loc[x["league_id"] == 140, "p_model"] = (
        0.9 * x.loc[x["league_id"] == 140, "p_over25"]
        + 0.1 * x.loc[x["league_id"] == 140, "p_market"]
    )
    x["edge"] = x["p_model"] - x["p_market"]
    x["side"] = np.where(x["p_model"] >= 0.5, "OVER25", "UNDER25")
    x["odds"] = np.where(x["p_model"] >= 0.5, x["avg_odds_over25"], x["avg_odds_under25"])
    x = x[x["odds"].notna()].copy()
    x["tier_base"] = [
        decide_total_bet(edge, odds, int(lid), p_model)
        for edge, odds, lid, p_model in zip(x["edge"], x["odds"], x["league_id"], x["p_model"])
    ]

    goals = x["home_goals"] + x["away_goals"]
    over_won = goals > 2.5
    x["profit_raw"] = np.where(
        x["side"] == "OVER25",
        np.where(over_won, x["avg_odds_over25"] - 1.0, -1.0),
        np.where(~over_won, x["avg_odds_under25"] - 1.0, -1.0),
    )
    x["market"] = "TOTAL"
    x["quality"] = x["edge"]
    return x[
        [
            "fixture_id",
            "league_id",
            "date",
            "month",
            "market",
            "side",
            "odds",
            "quality",
            "tier_base",
            "profit_raw",
        ]
    ].copy()


def _build_outcomes_candidates(df: pd.DataFrame) -> pd.DataFrame:
    y = df.copy()
    for c in ["p_home", "p_draw", "p_away", "avg_odds_home", "avg_odds_draw", "avg_odds_away"]:
        y[c] = pd.to_numeric(y[c], errors="coerce")

    opts = []
    for outcome, p_col, o_col in [
        ("Home", "p_home", "avg_odds_home"),
        ("Draw", "p_draw", "avg_odds_draw"),
        ("Away", "p_away", "avg_odds_away"),
    ]:
        t = y[["fixture_id", "league_id", "date", "month", "home_goals", "away_goals", p_col, o_col]].copy()
        t.columns = ["fixture_id", "league_id", "date", "month", "home_goals", "away_goals", "p", "odds"]
        t["outcome"] = outcome
        t["ev"] = t["p"] * t["odds"] - 1.0
        opts.append(t)
    all_opts = pd.concat(opts, ignore_index=True).dropna(subset=["p", "odds", "ev"])
    picks = all_opts.loc[all_opts.groupby("fixture_id")["ev"].idxmax()].copy()

    picks["tier_base"] = [
        decide_outcome_bet(ev, odds, int(lid), outcome)
        for ev, odds, lid, outcome in zip(picks["ev"], picks["odds"], picks["league_id"], picks["outcome"])
    ]

    home_won = picks["home_goals"] > picks["away_goals"]
    draw_won = picks["home_goals"] == picks["away_goals"]
    away_won = picks["home_goals"] < picks["away_goals"]
    picks["profit_raw"] = np.where(
        picks["outcome"] == "Home",
        np.where(home_won, picks["odds"] - 1.0, -1.0),
        np.where(
            picks["outcome"] == "Draw",
            np.where(draw_won, picks["odds"] - 1.0, -1.0),
            np.where(away_won, picks["odds"] - 1.0, -1.0),
        ),
    )
    picks["market"] = "1X2"
    picks["side"] = picks["outcome"].map({"Home": "P1", "Draw": "X", "Away": "P2"})
    picks["quality"] = picks["ev"]
    return picks[
        [
            "fixture_id",
            "league_id",
            "date",
            "month",
            "market",
            "side",
            "odds",
            "quality",
            "tier_base",
            "profit_raw",
        ]
    ].copy()


def _apply_monthly_quota(cands: pd.DataFrame, market: str) -> pd.DataFrame:
    out = cands.copy()
    out["tier"] = np.where(out["tier_base"].isin(["A", "B"]), out["tier_base"], "NO BET")
    out["source"] = np.where(out["tier"] == "NO BET", "none", "base")

    broad_min_odds = 1.55 if market == "TOTAL" else 1.50
    broad_max_odds = 2.60
    quality_floor = 0.00

    for (month, league_id), idx in out.groupby(["month", "league_id"]).groups.items():
        part = out.loc[idx]
        chosen = part[part["tier"].isin(["A", "B"])]
        count = len(chosen)

        # Trim overtrading.
        if count > MAX_BETS_PER_MONTH_LEAGUE:
            keep_idx = chosen.sort_values("quality", ascending=False).head(MAX_BETS_PER_MONTH_LEAGUE).index
            drop_idx = chosen.index.difference(keep_idx)
            out.loc[drop_idx, "tier"] = "NO BET"
            out.loc[drop_idx, "source"] = "trim"
            count = MAX_BETS_PER_MONTH_LEAGUE

        # Fill undertrading.
        if count < MIN_BETS_PER_MONTH_LEAGUE:
            need = MIN_BETS_PER_MONTH_LEAGUE - count
            pool = part[
                (part["tier"] == "NO BET")
                & (part["odds"] >= broad_min_odds)
                & (part["odds"] <= broad_max_odds)
                & (part["quality"] >= quality_floor)
            ].sort_values("quality", ascending=False)
            add_idx = pool.head(need).index
            out.loc[add_idx, "tier"] = "B"
            out.loc[add_idx, "source"] = "quota"

    out = out[out["tier"].isin(["A", "B"])].copy()
    return out


def _apply_market_allocation(bets: pd.DataFrame) -> pd.DataFrame:
    out = bets.copy()
    out["stake_base"] = out["tier"].map(STAKE_BY_TIER).astype(float)
    out["market_mult"] = 1.0

    for month, idx in out.groupby("month").groups.items():
        part = out.loc[idx]
        st_total = part.loc[part["market"] == "TOTAL", "stake_base"].sum()
        st_out = part.loc[part["market"] == "1X2", "stake_base"].sum()
        st_all = st_total + st_out
        if st_all <= 0:
            continue

        if st_total > 0 and st_out > 0:
            cur_share_total = st_total / st_all
            cur_share_out = st_out / st_all
            m_total = TARGET_MARKET_SHARE["TOTAL"] / cur_share_total
            m_out = TARGET_MARKET_SHARE["1X2"] / cur_share_out
        elif st_total > 0:
            m_total, m_out = 1.0, 1.0
        else:
            m_total, m_out = 1.0, 1.0

        m_total = min(max(m_total, MARKET_SCALE_MIN), MARKET_SCALE_MAX)
        m_out = min(max(m_out, MARKET_SCALE_MIN), MARKET_SCALE_MAX)

        out.loc[idx[out.loc[idx, "market"] == "TOTAL"], "market_mult"] = m_total
        out.loc[idx[out.loc[idx, "market"] == "1X2"], "market_mult"] = m_out

    out["stake_plan"] = out["stake_base"] * out["market_mult"]
    return out


def _run_execution_engine(bets: pd.DataFrame) -> pd.DataFrame:
    x = bets.sort_values(["date", "fixture_id", "market"]).copy()
    x["executed"] = False
    x["skip_reason"] = None
    x["stake_used"] = 0.0
    x["profit"] = 0.0
    x["bankroll_after"] = np.nan

    cooldown_until = defaultdict(lambda: pd.Timestamp.min)
    roi_history = defaultdict(lambda: deque(maxlen=ROLLING_WINDOW))

    bankroll = START_BANKROLL
    peak = START_BANKROLL
    unit_value = START_BANKROLL * BANK_UNIT_PCT

    for i, row in x.iterrows():
        league_id = int(row["league_id"])
        dt = row["date"]

        if dt < cooldown_until[league_id]:
            x.at[i, "skip_reason"] = "cooldown"
            x.at[i, "bankroll_after"] = bankroll
            continue

        hist = roi_history[league_id]
        if len(hist) >= ROLLING_WINDOW and (sum(hist) / len(hist)) < ROLLING_ROI_TRIGGER:
            cooldown_until[league_id] = dt + pd.Timedelta(days=COOLDOWN_DAYS)
            x.at[i, "skip_reason"] = "kill_switch"
            x.at[i, "bankroll_after"] = bankroll
            continue

        dd = (peak - bankroll) / peak if peak > 0 else 0.0
        stake_units = float(row["stake_plan"])
        if dd >= DRAWDOWN_THRESHOLD:
            stake_units *= DRAWDOWN_STAKE_MULT
        stake = stake_units * unit_value

        pnl = float(row["profit_raw"]) * stake
        bankroll += pnl
        peak = max(peak, bankroll)
        roi_history[league_id].append(float(row["profit_raw"]))

        x.at[i, "executed"] = True
        x.at[i, "stake_used"] = stake
        x.at[i, "profit"] = pnl
        x.at[i, "bankroll_after"] = bankroll

    return x


def _print_report(executed: pd.DataFrame):
    x = executed.copy()
    placed = x[x["executed"]].copy()

    by_month_league_market = (
        placed.groupby(["month", "league_id", "market"])
        .agg(bets=("fixture_id", "count"), stake=("stake_used", "sum"), profit=("profit", "sum"))
        .reset_index()
    )
    by_month_league_market["roi"] = by_month_league_market["profit"] / by_month_league_market["stake"]
    by_month_league_market["league"] = by_month_league_market["league_id"].map(LEAGUE_NAMES)
    by_month_league_market = by_month_league_market[
        ["month", "league", "market", "bets", "stake", "profit", "roi"]
    ].sort_values(["month", "league", "market"])

    by_market = (
        placed.groupby("market")
        .agg(bets=("fixture_id", "count"), stake=("stake_used", "sum"), profit=("profit", "sum"))
        .reset_index()
    )
    by_market["roi"] = by_market["profit"] / by_market["stake"]

    final_bankroll = float(placed["bankroll_after"].iloc[-1]) if not placed.empty else START_BANKROLL
    net_profit = final_bankroll - START_BANKROLL
    roi_total = net_profit / START_BANKROLL

    monthly = (
        placed.groupby("month")
        .agg(bets=("fixture_id", "count"), stake=("stake_used", "sum"), profit=("profit", "sum"))
        .reset_index()
    )
    monthly["roi"] = monthly["profit"] / monthly["stake"]

    print("\n=== PORTFOLIO POLICY V2 ===")
    print(
        {
            "bankroll_start": START_BANKROLL,
            "unit_size_usd": round(START_BANKROLL * BANK_UNIT_PCT, 2),
            "unit_pct_of_bankroll": BANK_UNIT_PCT,
            "bankroll_final": round(final_bankroll, 2),
            "net_profit": round(net_profit, 2),
            "roi_on_bankroll": round(roi_total, 4),
            "bets_executed": int(len(placed)),
            "coverage_vs_matches": round(len(placed) / 991.0, 4),
        }
    )

    print("\n=== BY MARKET ===")
    print(by_market.sort_values("roi", ascending=False).to_string(index=False))

    print("\n=== MONTHLY OVERALL ===")
    print(monthly.sort_values("month").to_string(index=False))

    print("\n=== MONTH x LEAGUE x MARKET ===")
    print(by_month_league_market.to_string(index=False))

    skipped = x[~x["executed"]]["skip_reason"].value_counts(dropna=False)
    print("\n=== SKIPPED REASONS ===")
    print(skipped.to_string())


def main():
    df = _fetch_data()
    totals = _build_totals_candidates(df)
    outcomes = _build_outcomes_candidates(df)

    totals_bets = _apply_monthly_quota(totals, market="TOTAL")
    outcomes_bets = _apply_monthly_quota(outcomes, market="1X2")

    all_bets = pd.concat([totals_bets, outcomes_bets], ignore_index=True)
    all_bets = _apply_market_allocation(all_bets)
    executed = _run_execution_engine(all_bets)
    _print_report(executed)


if __name__ == "__main__":
    main()
