import argparse
from pathlib import Path

import pandas as pd
import numpy as np
from sqlalchemy import create_engine, text

from config import DB_URL
from decision.totals_decision import decide_total_bet
from decision.outcomes_decision import decide_outcome_bet

DATE_FROM_DEFAULT = "2026-02-06"
DATE_TO_DEFAULT = "2026-02-10"
STAKE_A = 1.0
STAKE_B = 0.5

LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}


def _implied(odds):
    if odds is None or not np.isfinite(odds) or odds <= 0:
        return None
    return 1.0 / odds


def _pick_outcome(row):
    options = [
        ("Home", row.p_home, row.avg_odds_home),
        ("Draw", row.p_draw, row.avg_odds_draw),
        ("Away", row.p_away, row.avg_odds_away),
    ]
    evs = []
    for outcome, p, odds in options:
        if p is None or odds is None or not np.isfinite(p) or not np.isfinite(odds):
            continue
        ev = p * odds - 1.0
        evs.append((outcome, p, odds, ev))
    if not evs:
        return None
    return max(evs, key=lambda x: x[3])  # by ev


def _pick_total(row):
    # model probability
    p_over = row.p_over25
    if p_over is None or not np.isfinite(p_over):
        return None
    odds_over = row.avg_odds_over25
    odds_under = row.avg_odds_under25
    # market implied (over/under)
    imp_over = _implied(odds_over)
    imp_under = _implied(odds_under)
    if imp_over is None or imp_under is None:
        return None
    p_market = imp_over / (imp_over + imp_under)
    edge = p_over - p_market
    side = "Over" if p_over >= 0.5 else "Under"
    odds_side = odds_over if side == "Over" else odds_under
    return side, p_over, odds_side, p_market, edge


def _outcome_profit(row, outcome, odds):
    hg, ag = row.home_goals, row.away_goals
    if outcome == "Home":
        won = hg > ag
    elif outcome == "Draw":
        won = hg == ag
    else:
        won = hg < ag
    return (odds - 1.0) if won else -1.0


def _total_profit(row, side, odds):
    goals = row.home_goals + row.away_goals
    if side == "Over":
        return (odds - 1.0) if goals > 2.5 else -1.0
    return (odds - 1.0) if goals <= 2.5 else -1.0


def _parse_args():
    p = argparse.ArgumentParser(description="Analyze model bets in date window")
    p.add_argument("--from", dest="date_from", default=DATE_FROM_DEFAULT)
    p.add_argument("--to", dest="date_to", default=DATE_TO_DEFAULT)
    p.add_argument(
        "--out",
        dest="out_csv",
        default=None,
        help="Output CSV path (optional)",
    )
    return p.parse_args()


def main():
    args = _parse_args()
    date_from = args.date_from
    date_to = args.date_to
    out_csv = args.out_csv
    if out_csv is None:
        out_csv = f"analysis_{date_from}_{date_to}.csv"
    engine = create_engine(DB_URL)
    q = text(
        """
        WITH base AS (
            SELECT
                fixture_id,
                league_id,
                league_name,
                date,
                home_team,
                away_team,
                home_goals,
                away_goals
            FROM football.api_football_schedule
            WHERE date BETWEEN :dfrom AND :dto
              AND home_goals IS NOT NULL
              AND away_goals IS NOT NULL
        ),
        preds_latest AS (
            SELECT *
            FROM (
                SELECT
                    p.*,
                    b.date AS kickoff_ts,
                    ROW_NUMBER() OVER (
                        PARTITION BY p.fixture_id
                        ORDER BY p.ts_generated DESC NULLS LAST
                    ) AS rn
                FROM football.ml_predictions p
                JOIN base b ON b.fixture_id = p.fixture_id
                WHERE p.ts_generated <= b.date
            ) z
            WHERE z.rn = 1
        )
        SELECT
            p.fixture_id,
            b.league_id,
            b.league_name,
            b.date::date AS date,
            b.home_team,
            b.away_team,
            b.home_goals,
            b.away_goals,
            p.p_home,
            p.p_draw,
            p.p_away,
            p.p_over25,
            m.avg_odds_home,
            m.avg_odds_draw,
            m.avg_odds_away,
            m.avg_odds_over25,
            m.avg_odds_under25
        FROM preds_latest p
        JOIN base b ON b.fixture_id = p.fixture_id
        LEFT JOIN football.v_ml_epl_training m
          ON m.fixture_id = p.fixture_id
        ORDER BY b.date ASC, b.league_id, b.home_team;
        """
    )
    df = pd.read_sql(q, engine, params={"dfrom": date_from, "dto": date_to})
    if df.empty:
        print("No data in selected period")
        return

    # normalize
    for col in [
        "p_home",
        "p_draw",
        "p_away",
        "p_over25",
        "avg_odds_home",
        "avg_odds_draw",
        "avg_odds_away",
        "avg_odds_over25",
        "avg_odds_under25",
    ]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    rows = []
    for _, row in df.iterrows():
        league_id = int(row.league_id) if pd.notna(row.league_id) else None

        # outcome pick
        pick = _pick_outcome(row)
        outcome_pick = outcome_prob = outcome_odds = outcome_ev = None
        outcome_decision = "NO BET"
        outcome_profit = None
        if pick:
            outcome_pick, outcome_prob, outcome_odds, outcome_ev = pick
            if league_id is not None:
                outcome_decision = decide_outcome_bet(
                    outcome_ev, outcome_odds, league_id, outcome_pick
                )
            if outcome_decision in ("A", "B"):
                stake = STAKE_A if outcome_decision == "A" else STAKE_B
                outcome_profit = _outcome_profit(row, outcome_pick, outcome_odds) * stake

        # total pick
        tpick = _pick_total(row)
        total_side = total_prob = total_odds = total_edge = None
        total_decision = "NO BET"
        total_profit = None
        if tpick:
            total_side, total_prob, total_odds, p_market, total_edge = tpick
            if league_id is not None and total_odds is not None:
                total_decision = decide_total_bet(
                    total_edge, total_odds, league_id, total_prob
                )
            if total_decision in ("A", "B"):
                stake = STAKE_A if total_decision == "A" else STAKE_B
                total_profit = _total_profit(row, total_side, total_odds) * stake

        rows.append(
            {
                "date": str(row.date),
                "league_id": league_id,
                "league": row.league_name or LEAGUE_NAMES.get(league_id, str(league_id)),
                "fixture_id": int(row.fixture_id),
                "home_team": row.home_team,
                "away_team": row.away_team,
                "score": f"{row.home_goals}-{row.away_goals}",
                "outcome_pick": outcome_pick,
                "outcome_prob": outcome_prob,
                "outcome_odds": outcome_odds,
                "outcome_ev": outcome_ev,
                "outcome_decision": outcome_decision,
                "outcome_profit": outcome_profit,
                "total_pick": total_side,
                "total_prob": total_prob,
                "total_odds": total_odds,
                "total_edge": total_edge,
                "total_decision": total_decision,
                "total_profit": total_profit,
            }
        )

    out = pd.DataFrame(rows)

    # summary
    def _sum_block(df, prefix):
        bets = df[df[f"{prefix}_decision"].isin(["A", "B"])].copy()
        bets = bets[bets[f"{prefix}_profit"].notna()]
        stake = (bets[f"{prefix}_decision"] == "A").sum() * STAKE_A + (bets[f"{prefix}_decision"] == "B").sum() * STAKE_B
        profit = bets[f"{prefix}_profit"].sum()
        return {
            "bets": int(len(bets)),
            "stake": float(stake),
            "profit": float(profit),
            "roi": float(profit / stake) if stake else None,
        }

    print(f"\nPeriod: {date_from} .. {date_to}")
    print("Matches:", len(out))

    print("\n=== OUTCOME SUMMARY ===")
    print(_sum_block(out, "outcome"))

    print("\n=== TOTALS SUMMARY ===")
    print(_sum_block(out, "total"))

    print("\n=== BY LEAGUE (OUTCOME) ===")
    if len(out):
        rep_o = (
            out.groupby("league")
            .apply(lambda g: _sum_block(g, "outcome"))
            .apply(pd.Series)
            .sort_values("roi", ascending=False)
        )
        print(rep_o.to_string())

        print("\n=== BY LEAGUE (TOTALS) ===")
        rep_t = (
            out.groupby("league")
            .apply(lambda g: _sum_block(g, "total"))
            .apply(pd.Series)
            .sort_values("roi", ascending=False)
        )
        print(rep_t.to_string())

    # detailed report
    out = out.sort_values(["date", "league", "home_team"]).reset_index(drop=True)
    out_path = Path(out_csv)
    out.to_csv(out_path, index=False)
    print(f"\nSaved: {out_path}")

    # print compact table
    cols = [
        "date",
        "league",
        "home_team",
        "away_team",
        "score",
        "outcome_pick",
        "outcome_prob",
        "outcome_odds",
        "outcome_ev",
        "outcome_decision",
        "outcome_profit",
        "total_pick",
        "total_prob",
        "total_odds",
        "total_edge",
        "total_decision",
        "total_profit",
    ]
    print("\n=== MATCH LEVEL ===")
    print(out[cols].to_string(index=False))


if __name__ == "__main__":
    main()
