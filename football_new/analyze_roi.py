
#!/usr/bin/env python3
"""ROI analytics for generated football betting predictions."""

from __future__ import annotations

import argparse
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

import numpy as np
import pandas as pd
import sys
from sqlalchemy import create_engine, text, inspect

try:
    from dotenv import load_dotenv  # type: ignore
except ImportError:  # optional dependency for local runs
    load_dotenv = None

# -----------------------------
# Environment helpers
# -----------------------------


def _load_env_file(path: Path) -> None:
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


def _print_text(text: str) -> None:
    try:
        print(text)
    except UnicodeEncodeError:
        encoding = sys.stdout.encoding or "utf-8"
        print(text.encode(encoding, errors="replace").decode(encoding, errors="replace"))


def _bootstrap_env() -> None:
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


# -----------------------------
# Data helpers
# -----------------------------


@dataclass
class Filters:
    date_from: Optional[str]
    date_to: Optional[str]
    min_rating: Optional[str]


def _get_prediction_columns(engine, schema: str, table: str) -> set[str]:
    try:
        inspector = inspect(engine)
        cols = inspector.get_columns(table, schema=schema)
        return {c["name"] for c in cols}
    except Exception:
        return set()


def _col_expr(columns: set[str], name: str, alias: Optional[str] = None, dtype: str = "double precision") -> str:
    alias = alias or name
    if name in columns:
        return f"p.{name} AS {alias}" if alias != name else f"p.{name}"
    return f"NULL::{dtype} AS {alias}"


def _alpha_outcome_expr(columns: set[str]) -> str:
    if "alpha_blend_outcome" in columns:
        return "p.alpha_blend_outcome"
    if "alpha_blend" in columns:
        return "p.alpha_blend AS alpha_blend_outcome"
    return "NULL::double precision AS alpha_blend_outcome"


def _alpha_total_expr(columns: set[str]) -> str:
    if "alpha_blend_total" in columns:
        return "p.alpha_blend_total"
    return "NULL::double precision AS alpha_blend_total"


def _fetch_predictions(engine, schema: str, table: str, filters: Filters) -> pd.DataFrame:
    table_columns = _get_prediction_columns(engine, schema, table)

    where_clauses = ["s.home_goals IS NOT NULL", "s.away_goals IS NOT NULL"]
    params: dict[str, object] = {}

    date_column = "s.date"

    if filters.date_from:
        where_clauses.append(f"{date_column} >= :date_from")
        params["date_from"] = filters.date_from
    if filters.date_to:
        where_clauses.append(f"{date_column} <= :date_to")
        params["date_to"] = filters.date_to

    where_sql = " AND ".join(where_clauses)

    select_parts = [
        "p.fixture_id",
        "s.date AS match_datetime",
        "s.league_id",
        _col_expr(table_columns, "best_bet_type", dtype="text"),
        _col_expr(table_columns, "best_bet_outcome", dtype="text"),
        _col_expr(table_columns, "best_bet_odds"),
        _col_expr(table_columns, "bet_rating", dtype="text"),
        _col_expr(table_columns, "best_bet_edge"),
        _col_expr(table_columns, "best_bet_ev"),
        _alpha_outcome_expr(table_columns),
        _alpha_total_expr(table_columns),
        _col_expr(table_columns, "p_home"),
        _col_expr(table_columns, "p_draw"),
        _col_expr(table_columns, "p_away"),
        _col_expr(table_columns, "p_over25"),
        _col_expr(table_columns, "p_under25"),
        _col_expr(table_columns, "decision_1x2", dtype="text"),
        _col_expr(table_columns, "decision_total", dtype="text"),
        _col_expr(table_columns, "ts_generated", alias="prediction_generated_at", dtype="timestamp"),
    ]

    select_clause = ",\n            ".join(select_parts)

    query = text(
        f"""
        SELECT
            {select_clause},
            s.league_id AS schedule_league_id,
            s.league_name,
            s.home_team,
            s.away_team,
            s.home_goals,
            s.away_goals
        FROM {schema}.{table} AS p
        JOIN football.api_football_schedule AS s
          ON p.fixture_id = s.fixture_id
        WHERE {where_sql}
        """
    )

    with engine.connect() as conn:
        df = pd.read_sql(query, conn, params=params)
    if filters.min_rating and not df.empty:
        allowed = list(_expand_rating_filters(filters.min_rating))
        df = df[df["bet_rating"].isin(allowed)]
    return df


def _expand_rating_filters(min_rating: str) -> Iterable[str]:
    order = ["Strong", "Medium", "Weak"]
    min_rating = min_rating.strip().capitalize()
    if min_rating not in order:
        raise ValueError(f"Unknown rating '{min_rating}'. Choose from Strong/Medium/Weak.")
    idx = order.index(min_rating)
    return order[: idx + 1]


def _prepare_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df

    for dt_col in ("match_datetime", "prediction_generated_at"):
        if dt_col in df.columns:
            df[dt_col] = pd.to_datetime(df[dt_col], errors="coerce", utc=True)

    numeric_cols = ["best_bet_odds", "best_bet_edge", "best_bet_ev", "alpha_blend_outcome", "alpha_blend_total"]
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    if "league_id" in df.columns:
        df["league_id"] = pd.to_numeric(df["league_id"], errors="coerce")
    df["home_goals"] = pd.to_numeric(df["home_goals"], errors="coerce")
    df["away_goals"] = pd.to_numeric(df["away_goals"], errors="coerce")
    df["total_goals"] = df[["home_goals", "away_goals"]].sum(axis=1, numeric_only=True)
    df["actual_outcome"] = np.where(
        df["home_goals"] > df["away_goals"],
        "Home",
        np.where(df["home_goals"] < df["away_goals"], "Away", "Draw"),
    )

    def _league_label(row) -> str:
        name = row.get("league_name")
        if isinstance(name, str) and name.strip():
            return name.strip()
        lid = row.get("league_id") or row.get("schedule_league_id")
        return f"League {int(lid)}" if pd.notna(lid) else "Unknown"

    df["league_label"] = df.apply(_league_label, axis=1)
    return df


def _evaluate_bets(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df

    wins = []
    profits = []
    reasons = []

    for row in df.itertuples():
        bet_type = (row.best_bet_type or "").upper()
        bet_outcome = (row.best_bet_outcome or "").strip()
        odds = row.best_bet_odds

        if not bet_type or bet_type == "NONE" or not bet_outcome:
            wins.append(np.nan)
            profits.append(np.nan)
            reasons.append("no bet")
            continue

        if odds is None or not np.isfinite(odds) or odds <= 1.0:
            wins.append(np.nan)
            profits.append(np.nan)
            reasons.append("invalid odds")
            continue

        home_goals = row.home_goals
        away_goals = row.away_goals
        total_goals = row.total_goals

        if pd.isna(home_goals) or pd.isna(away_goals):
            wins.append(np.nan)
            profits.append(np.nan)
            reasons.append("missing score")
            continue

        if bet_type == "1X2":
            win = row.actual_outcome == bet_outcome
            note = row.actual_outcome
        else:
            win, note = _evaluate_total_bet(bet_outcome, total_goals)
            if win is None:
                wins.append(np.nan)
                profits.append(np.nan)
                reasons.append(note)
                continue

        profit = odds - 1.0 if win else -1.0
        wins.append(bool(win))
        profits.append(profit)
        reasons.append(note)

    df = df.assign(bet_win=wins, profit=profits, result_note=reasons)
    valid = df[df["profit"].notna()].copy()
    return valid


def _evaluate_total_bet(outcome: str, total_goals: float) -> tuple[Optional[bool], str]:
    outcome_upper = outcome.upper()
    direction = None
    if "OVER" in outcome_upper:
        direction = "over"
    elif "UNDER" in outcome_upper:
        direction = "under"

    threshold_match = re.search(r"(\d+(?:\.\d+)?)", outcome_upper)
    if direction is None or threshold_match is None:
        return None, "unsupported outcome"

    threshold = float(threshold_match.group(1))
    if not np.isfinite(total_goals):
        return None, "missing score"

    # Treat exact-threshold as push for integer lines; rare in data but handle gracefully.
    if abs(total_goals - threshold) <= 1e-8:
        return None, "push"

    if direction == "over":
        return total_goals > threshold, f"{total_goals:.1f} goals"
    return total_goals < threshold, f"{total_goals:.1f} goals"


def _notes_to_profile(notes: str, close_flag: bool) -> str:
    if not notes:
        return "Baseline"

    tags: list[str] = []
    if "switch=draw_close" in notes:
        tags.append("Draw switch")
    if "switch=total" in notes:
        tags.append("Total switch")
    if "suppress_close_low_ev" in notes:
        tags.append("Filtered close")
    if "filtered_by_tau" in notes:
        tags.append("Tau filter")

    if not tags:
        if close_flag:
            tags.append("Close flagged")
        else:
            tags.append("Other note")

    return ", ".join(tags)


def _annotate_decision_metadata(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df

    annotated = df.copy()

    close_gap = float(os.getenv("BET_CLOSE_GAP", 0.06))
    close_draw_prob = float(os.getenv("BET_CLOSE_DRAW_PROB", 0.32))

    for col in ("p_home", "p_away", "p_draw"):
        if col not in annotated.columns:
            annotated[col] = np.nan

    annotated["close_game_flag"] = (
        (annotated["p_home"] - annotated["p_away"]).abs() <= close_gap
    ) & annotated["p_home"].notna() & annotated["p_away"].notna()
    annotated["high_draw_flag"] = annotated["p_draw"] >= close_draw_prob

    if "bet_decision_notes" not in annotated.columns:
        annotated["bet_decision_notes"] = ""
    annotated["bet_decision_notes"] = annotated["bet_decision_notes"].fillna("")

    annotated["close_bucket"] = np.where(
        annotated["close_game_flag"], "Close", "Not close"
    )

    annotated["decision_profile"] = [
        _notes_to_profile(notes, close_flag)
        for notes, close_flag in zip(
            annotated["bet_decision_notes"], annotated["close_game_flag"]
        )
    ]

    annotated["decision_profile"] = annotated["decision_profile"].fillna("Baseline")

    annotated["draw_switch_flag"] = annotated["bet_decision_notes"].str.contains(
        "switch=draw_close", na=False
    )
    annotated["total_switch_flag"] = annotated["bet_decision_notes"].str.contains(
        "switch=total", na=False
    )

    return annotated


# -----------------------------
# Reporting helpers
# -----------------------------


def _format_table(df: pd.DataFrame, sort_by: str, ascending: bool = False, min_bets: int = 1) -> str:
    if df.empty:
        return "(no data)"
    trimmed = df[df["bets"] >= min_bets].copy()
    if trimmed.empty:
        return "(no rows meeting the minimum sample size)"
    trimmed = trimmed.sort_values(sort_by, ascending=ascending)
    with pd.option_context("display.max_rows", None, "display.width", 120):
        return trimmed.to_string(index=False, float_format=lambda v: f"{v:0.3f}")


def _group_summary(df: pd.DataFrame, group_cols: list[str]) -> pd.DataFrame:
    agg_args = {
        "bets": ("profit", "size"),
        "profit": ("profit", "sum"),
        "roi": ("profit", lambda s: s.sum() / len(s) if len(s) else np.nan),
        "hit_rate": ("bet_win", "mean"),
    }
    if "best_bet_odds" in df.columns:
        agg_args["avg_odds"] = ("best_bet_odds", "mean")
    if "best_bet_ev" in df.columns:
        agg_args["avg_ev"] = ("best_bet_ev", "mean")

    grouped = df.groupby(group_cols, observed=False).agg(**agg_args).reset_index()
    grouped["hit_rate"] = grouped["hit_rate"].fillna(0.0)
    return grouped


def _print_overall_summary(df: pd.DataFrame) -> None:
    total_bets = int(len(df))
    total_profit = float(df["profit"].sum())
    roi = total_profit / total_bets if total_bets else 0.0
    hit_rate = float(df["bet_win"].mean()) if total_bets else 0.0
    avg_odds = float(df["best_bet_odds"].mean()) if total_bets else float("nan")
    avg_ev = float(df["best_bet_ev"].mean()) if "best_bet_ev" in df else float("nan")

    print("=== Overall performance ===")
    print(f"Bets: {total_bets}")
    print(f"Total profit (1u stake): {total_profit:0.2f}")
    print(f"ROI per bet: {roi:0.3f}")
    print(f"Hit rate: {hit_rate:0.3f}")
    if np.isfinite(avg_odds):
        print(f"Average odds: {avg_odds:0.3f}")
    if np.isfinite(avg_ev):
        print(f"Average model EV: {avg_ev:0.3f}")
    print()


def _print_section(title: str, table_text: str) -> None:
    print(f"=== {title} ===")
    print(table_text)
    print()


def _smart_highlights(df: pd.DataFrame) -> None:
    if df.empty:
        return

    by_combo = _group_summary(df, ["league_label", "best_bet_type", "bet_rating"])
    by_combo = by_combo[by_combo["bets"] >= 10]
    if not by_combo.empty:
        best = by_combo.sort_values("roi", ascending=False).head(5)
        worst = by_combo.sort_values("roi", ascending=True).head(5)
        print("=== Smart highlights (league + bet type + rating) ===")
        print("Top clusters:")
        with pd.option_context("display.width", 160):
            print(best.to_string(index=False, float_format=lambda v: f"{v:0.3f}"))
            print()
            print("Underperformers:")
            print(worst.to_string(index=False, float_format=lambda v: f"{v:0.3f}"))
            print()

    if "best_bet_ev" in df.columns and df["best_bet_ev"].notna().any():
        bins = pd.cut(df["best_bet_ev"], bins=[-np.inf, 0, 0.05, 0.10, 0.20, np.inf])
        ev_summary = _group_summary(df.assign(ev_bucket=bins), ["ev_bucket"])
        print("=== Realized ROI by predicted EV bucket ===")
        print(
            ev_summary.sort_values("ev_bucket").to_string(
                index=False, float_format=lambda v: f"{v:0.3f}"
            )
        )
        print()


def _build_bet_display_table(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df.copy()

    table = df.copy()
    table["match_datetime"] = pd.to_datetime(
        table.get("match_datetime"), utc=True, errors="coerce"
    )
    table["date"] = table["match_datetime"].dt.strftime("%Y-%m-%d %H:%M")

    table["league"] = table.get("league_name")
    table.loc[table["league"].isna(), "league"] = table.loc[
        table["league"].isna(), "league_label"
    ]

    def _score_repr(row: pd.Series) -> str:
        home_goals = row.get("home_goals")
        away_goals = row.get("away_goals")
        if np.isfinite(home_goals) and np.isfinite(away_goals):
            return f"{int(home_goals)}-{int(away_goals)}"
        return "?"

    table["score"] = table.apply(_score_repr, axis=1)

    table["result"] = table["bet_win"].map({True: "Win", False: "Loss"})
    table.loc[table["bet_win"].isna(), "result"] = "N/A"

    columns = [
        "date",
        "league",
        "fixture_id",
        "home_team",
        "away_team",
        "score",
        "best_bet_type",
        "best_bet_outcome",
        "bet_rating",
        "best_bet_odds",
        "best_bet_ev",
        "result_note",
        "result",
        "profit",
        "bet_decision_notes",
        "close_bucket",
        "decision_profile",
    ]

    available = [c for c in columns if c in table.columns]
    display_table = table.sort_values("match_datetime")[available]
    return display_table.reset_index(drop=True)


def _output_bet_table(
    df: pd.DataFrame, show_table: bool, export_path: Optional[str]
) -> None:
    if df.empty:
        text = "(no settled bets)"
        if show_table:
            print(text)
        if export_path:
            Path(export_path).open("w", encoding="utf-8").write(text)
        return

    display_table = _build_bet_display_table(df)

    if export_path:
        display_table.to_csv(export_path, index=False, encoding="utf-8")
        print(f"Saved bets table to {export_path}")

    if show_table:
        with pd.option_context(
            "display.max_rows", None,
            "display.max_columns", None,
            "display.width", 160,
            "display.float_format", lambda v: f"{v:0.3f}"
        ):
            print("=== Settled bets ===")
            table_text = display_table.to_string(index=False)
            _print_text(table_text)
            print()


def _print_bet_samples(df: pd.DataFrame, sample_size: int) -> None:
    if df.empty:
        return

    display_table = _build_bet_display_table(df)

    def _render(label: str, section: pd.DataFrame, ascending: bool) -> None:
        if section.empty:
            print(f"No {label.lower()} for the selected filters.")
            print()
            return

        ordered = section.sort_values("profit", ascending=ascending)
        if sample_size > 0:
            ordered = ordered.head(sample_size)

        with pd.option_context(
            "display.max_rows", None,
            "display.max_columns", None,
            "display.width", 160,
            "display.float_format", lambda v: f"{v:0.3f}"
        ):
            print(f"=== {label} ===")
            table_text = ordered.to_string(index=False)
            _print_text(table_text)
            print()

    winners = display_table[display_table["result"] == "Win"]
    losers = display_table[display_table["result"] == "Loss"]

    _render("Winning bets", winners, ascending=False)
    _render("Losing bets", losers, ascending=True)

# -----------------------------
# CLI entry point
# -----------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyse realised ROI for ml_predictions bets (requires final scores)."
    )
    parser.add_argument("--date-from", dest="date_from", type=str, default=None, help="Lower bound for prediction date_utc.")
    parser.add_argument("--date-to", dest="date_to", type=str, default=None, help="Upper bound for prediction date_utc.")
    parser.add_argument(
        "--min-rating",
        dest="min_rating",
        type=str,
        default=None,
        help="Only use bets with rating >= threshold (Strong/Medium/Weak).",
    )
    parser.add_argument(
        "--schema",
        dest="schema",
        type=str,
        default=os.getenv("DB_SCHEMA", "football"),
        help="Schema containing the predictions table (default: football).",
    )
    parser.add_argument(
        "--table",
        dest="table",
        type=str,
        default=os.getenv("DB_TABLE", "ml_predictions"),
        help="Predictions table name (default: ml_predictions).",
    )
    parser.add_argument(
        "--min-bets",
        dest="min_bets",
        type=int,
        default=5,
        help="Minimum bets required for group rows in summaries (default: 5).",
    )
    parser.add_argument(
        "--show-bets",
        dest="show_bets",
        action="store_true",
        help="Print the list of settled bets with odds and final score.",
    )
    parser.add_argument(
        "--max-bet-rows",
        dest="max_bet_rows",
        type=int,
        default=15,
        help="Rows to show in the winning/losing bet breakdown (0 to show all).",
    )
    parser.add_argument(
        "--export-bets",
        dest="export_bets",
        type=str,
        default=None,
        help="Optional path to save the detailed bets table as CSV.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    _bootstrap_env()
    db_url = _compose_db_url()
    engine = create_engine(db_url)

    filters = Filters(
        date_from=args.date_from,
        date_to=args.date_to,
        min_rating=args.min_rating,
    )

    raw = _fetch_predictions(engine, args.schema, args.table, filters)
    data = _prepare_dataframe(raw)
    evaluated = _evaluate_bets(data)

    if evaluated.empty:
        print("No settled bets found for the specified filters.")
        return

    evaluated = _annotate_decision_metadata(evaluated)

    _print_overall_summary(evaluated)

    league_table = _format_table(
        _group_summary(evaluated, ["league_label"]),
        sort_by="roi",
        min_bets=args.min_bets,
    )
    _print_section("ROI by league", league_table)

    rating_table = _format_table(
        _group_summary(evaluated, ["bet_rating"]),
        sort_by="roi",
        min_bets=1,
    )
    _print_section("ROI by rating", rating_table)

    bet_type_table = _format_table(
        _group_summary(evaluated, ["best_bet_type", "best_bet_outcome"]),
        sort_by="roi",
        min_bets=args.min_bets,
    )
    _print_section("ROI by bet type", bet_type_table)

    _smart_highlights(evaluated)

    profile_table = _format_table(
        _group_summary(evaluated, ["decision_profile"]),
        sort_by="roi",
        min_bets=1,
    )
    _print_section("ROI by decision profile", profile_table)

    close_table = _format_table(
        _group_summary(evaluated, ["close_bucket"]),
        sort_by="roi",
        min_bets=1,
    )
    _print_section("ROI by close flag", close_table)

    _print_bet_samples(evaluated, args.max_bet_rows)

    if args.show_bets or args.export_bets:
        _output_bet_table(evaluated, args.show_bets, args.export_bets)


if __name__ == "__main__":  # pragma: no cover
    main()
