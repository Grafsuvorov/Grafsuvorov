#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Residual correction layer on top of prognoz_v1 predictions."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence

import joblib
import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text, inspect
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.impute import SimpleImputer
from sklearn.metrics import brier_score_loss, log_loss
from sklearn.pipeline import Pipeline

HERE = Path(__file__).resolve().parent

DEFAULT_MODEL_FILE = "residual_layer_v2.pkl"
CLASS_ORDER = ["Home", "Draw", "Away"]
PREDICTION_COLUMNS = {
    "home": "p_home",
    "draw": "p_draw",
    "away": "p_away",
}

OUTCOME_FEATURE_CANDIDATES = [
    "p_home",
    "p_draw",
    "p_away",
    "p_home_norm",
    "p_draw_norm",
    "p_away_norm",
    "avg_odds_home",
    "avg_odds_draw",
    "avg_odds_away",
    "edge_home",
    "edge_draw",
    "edge_away",
    "fair_home",
    "fair_draw",
    "fair_away",
    "kelly_home",
    "kelly_draw",
    "kelly_away",
    "ev_home",
    "ev_draw",
    "ev_away",
    "n_bookmakers",
    "league_draw_prior",
    "overround_1x2",
    "alpha_blend_outcome",
]

TOTAL_FEATURE_CANDIDATES = [
    "p_over25",
    "p_under25",
    "avg_odds_over25",
    "avg_odds_under25",
    "edge_over",
    "edge_under",
    "fair_over",
    "fair_under",
    "ev_over",
    "ev_under",
    "alpha_blend_total",
    "p_over_mkt",
    "n_bookmakers",
    "p_home",
    "p_draw",
    "p_away",
]

REQUIRED_PREDICTION_COLUMNS = {
    "fixture_id",
    "p_home",
    "p_draw",
    "p_away",
}

OPTIONAL_PREDICTION_COLUMNS = [
    "ts_generated",
    "p_over25",
    "p_under25",
    "avg_odds_home",
    "avg_odds_draw",
    "avg_odds_away",
    "avg_odds_over25",
    "avg_odds_under25",
    "p_home_norm",
    "p_draw_norm",
    "p_away_norm",
    "p_over_mkt",
    "edge_home",
    "edge_draw",
    "edge_away",
    "edge_over",
    "edge_under",
    "fair_home",
    "fair_draw",
    "fair_away",
    "fair_over",
    "fair_under",
    "kelly_home",
    "kelly_draw",
    "kelly_away",
    "ev_home",
    "ev_draw",
    "ev_away",
    "ev_over",
    "ev_under",
    "league_draw_prior",
    "overround_1x2",
    "n_bookmakers",
    "alpha_blend_outcome",
    "alpha_blend_total",
    "bet_rating",
]

SCHEDULE_SELECT_COLUMNS = [
    "s.date AS match_datetime",
    "s.league_id",
    "s.home_team",
    "s.away_team",
    "s.home_goals",
    "s.away_goals",
]

PROB_EPS = 1e-4
TOTAL_SAMPLE_FLOOR = 80


def _load_env_file(path: Path) -> None:
    """Load environment variables from a .env-like file."""

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
    except FileNotFoundError:
        return


def _bootstrap_env() -> None:
    """Hydrate process env from common .env files."""

    candidates = [
        HERE / ".env.local",
        HERE / ".env",
        HERE / "api" / ".env",
        HERE / "api" / ".env_test",
        HERE / "api" / ".test_env",
    ]
    for candidate in candidates:
        if candidate.exists():
            _load_env_file(candidate)


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
        raise RuntimeError("Set DB_URL/DATABASE_URL or DB_USER/DB_PASSWORD for database access.")
    return f"{scheme}://{user}:{password}@{host}:{port}/{name}"


def _parse_date(value: Optional[str]) -> Optional[pd.Timestamp]:
    if value is None:
        return None
    ts = pd.to_datetime(value, utc=True, errors="coerce")
    if pd.isna(ts):
        raise ValueError(f"Cannot parse date value '{value}'")
    return ts


def _get_prediction_columns(engine, schema: str, table: str) -> set[str]:
    stmt = text(f'SELECT * FROM "{schema}"."{table}" LIMIT 0')
    with engine.connect() as conn:
        try:
            result = conn.execute(stmt)
            columns = list(result.keys())
        except Exception:
            inspector = inspect(engine)
            try:
                info_cols = inspector.get_columns(table, schema=schema)
            except Exception:
                query = text('''
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_schema = :schema
                      AND table_name = :table
                ''')
                rows = conn.execute(query, {"schema": schema, "table": table}).fetchall()
                info_cols = [{"name": row[0]} for row in rows]
            columns = [col.get("name") for col in info_cols]
    if not columns:
        raise RuntimeError(f'Cannot introspect columns for {schema}.{table}')
    return {col for col in columns if col}




def _comma_params(values: Iterable[int], prefix: str = "val") -> tuple[str, Dict[str, int]]:
    params: Dict[str, int] = {}
    holders: List[str] = []
    for idx, val in enumerate(values):
        key = f"{prefix}_{idx}"
        holders.append(f":{key}")
        params[key] = int(val)
    return ", ".join(holders), params



def _fetch_predictions(
    engine,
    schema: str,
    table: str,
    date_from: Optional[pd.Timestamp],
    date_to: Optional[pd.Timestamp],
    fixture_ids: Optional[Sequence[int]],
    league_ids: Optional[Sequence[int]],
    require_scores: bool,
) -> pd.DataFrame:
    available_cols = _get_prediction_columns(engine, schema, table)
    required_cols = {"fixture_id", "p_home", "p_draw", "p_away"}
    missing_required = required_cols - available_cols
    if missing_required:
        missing_list = ", ".join(sorted(missing_required))
        raise RuntimeError(
            f"Prediction table {schema}.{table} missing required columns: {missing_list}"
        )

    base_select = []
    for col in REQUIRED_PREDICTION_COLUMNS:
        if col not in available_cols:
            missing_list = ", ".join(sorted(REQUIRED_PREDICTION_COLUMNS - available_cols))
            raise RuntimeError(f"Prediction table {schema}.{table} missing required columns: {missing_list}")
        base_select.append(f"p.{col}")
    skipped_optional: set[str] = set()
    for opt in OPTIONAL_PREDICTION_COLUMNS:
        if opt in available_cols:
            base_select.append(f"p.{opt}")
        else:
            skipped_optional.add(opt)
    base_select.extend(SCHEDULE_SELECT_COLUMNS)

    select_cols: List[str] = []
    for expr in base_select:
        if expr.startswith("p."):
            base = expr.split(" AS ", 1)[0]
            col_name = base.split(".", 1)[1]
            if col_name not in available_cols:
                skipped_optional.add(col_name)
                continue
        select_cols.append(expr)

    if skipped_optional:
        skipped_list = ", ".join(sorted(skipped_optional))
        print(f"[WARN] Skipped missing prediction columns: {skipped_list}")

    where_parts: List[str] = []
    params: Dict[str, object] = {}

    if date_from is not None:
        where_parts.append("s.date >= :date_from")
        params["date_from"] = date_from.to_pydatetime()
    if date_to is not None:
        where_parts.append("s.date <= :date_to")
        params["date_to"] = date_to.to_pydatetime()

    if fixture_ids:
        holders, holder_params = _comma_params(fixture_ids, prefix="fixture")
        where_parts.append(f"p.fixture_id IN ({holders})")
        params.update(holder_params)

    if league_ids:
        holders, holder_params = _comma_params(league_ids, prefix="league")
        where_parts.append(f"s.league_id IN ({holders})")
        params.update(holder_params)

    if require_scores:
        where_parts.append("s.home_goals IS NOT NULL")
        where_parts.append("s.away_goals IS NOT NULL")

    where_sql = " AND ".join(where_parts) if where_parts else "TRUE"

    query = text(
        f"""
        SELECT {', '.join(select_cols)}
        FROM {schema}.{table} AS p
        JOIN football.api_football_schedule AS s
          ON p.fixture_id = s.fixture_id
        WHERE {where_sql}
        ORDER BY s.date ASC
        """
    )

    with engine.connect() as conn:
        df = pd.read_sql(query, conn, params=params)

    if "ts_generated" in df.columns:
        df = df.sort_values("ts_generated").drop_duplicates("fixture_id", keep="last")

    if not df.empty and "match_datetime" in df.columns:
        df["match_datetime"] = pd.to_datetime(df["match_datetime"], errors="coerce", utc=True)

    return df.reset_index(drop=True)


def _ensure_numeric(df: pd.DataFrame, columns: Iterable[str]) -> None:
    for col in columns:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")


def _derive_actuals(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    if "home_goals" not in df.columns or "away_goals" not in df.columns:
        raise RuntimeError("Dataset lacks home_goals/away_goals columns for residual training.")

    mask_scores = df["home_goals"].notna() & df["away_goals"].notna()
    df = df.loc[mask_scores].copy()
    df["home_goals"] = df["home_goals"].astype(float)
    df["away_goals"] = df["away_goals"].astype(float)

    outcome = np.where(df["home_goals"] > df["away_goals"], "Home", "")
    outcome = np.where(df["home_goals"] < df["away_goals"], "Away", outcome)
    outcome = np.where(df["home_goals"] == df["away_goals"], "Draw", outcome)
    df["actual_result"] = outcome
    df["target_home"] = (df["actual_result"] == "Home").astype(float)
    df["target_draw"] = (df["actual_result"] == "Draw").astype(float)
    df["target_away"] = (df["actual_result"] == "Away").astype(float)
    df["target_over25"] = ((df["home_goals"] + df["away_goals"]) > 2).astype(float)
    return df


def _make_regressor() -> Pipeline:
    return Pipeline([
        ("impute", SimpleImputer(strategy="median")),
        (
            "gbr",
            GradientBoostingRegressor(
                random_state=42,
                n_estimators=400,
                learning_rate=0.05,
            ),
        ),
    ])


def _train_outcome_models(df: pd.DataFrame, features: Sequence[str]) -> Dict[str, Pipeline]:
    models: Dict[str, Pipeline] = {}
    X = df.loc[:, features]
    for label, target_col in zip(CLASS_ORDER, ["target_home", "target_draw", "target_away"]):
        pred_col = PREDICTION_COLUMNS[label.lower()]
        base = pd.to_numeric(df[pred_col], errors="coerce").fillna(0.0)
        residual = df[target_col] - base
        model = _make_regressor()
        model.fit(X, residual)
        models[label] = model
    return models


def _train_total_model(df: pd.DataFrame, features: Sequence[str]) -> Optional[Pipeline]:
    if "p_over25" not in df.columns:
        return None
    mask = df["p_over25"].notna()
    if mask.sum() < TOTAL_SAMPLE_FLOOR:
        return None
    X = df.loc[mask, features]
    base = pd.to_numeric(df.loc[mask, "p_over25"], errors="coerce").fillna(0.5)
    residual = df.loc[mask, "target_over25"] - base
    model = _make_regressor()
    model.fit(X, residual)
    return model


def _apply_outcome_models(df: pd.DataFrame, models: Dict[str, Pipeline], features: Sequence[str]) -> pd.DataFrame:
    df = df.copy()
    X = df.reindex(columns=features)
    adjusted = {}
    for label in CLASS_ORDER:
        pred_col = PREDICTION_COLUMNS[label.lower()]
        base = pd.to_numeric(df[pred_col], errors="coerce")
        corr = pd.Series(models[label].predict(X), index=df.index)
        adjusted[label] = base.fillna(1.0 / len(CLASS_ORDER)) + corr
    adj_frame = pd.DataFrame(adjusted, index=df.index)
    adj_frame = adj_frame.clip(lower=PROB_EPS, upper=1 - PROB_EPS)
    denom = adj_frame.sum(axis=1)
    for label in CLASS_ORDER:
        df[f"p_{label.lower()}_v2"] = adj_frame[label] / denom
        df[f"delta_{label.lower()}"] = df[f"p_{label.lower()}_v2"] - pd.to_numeric(df[PREDICTION_COLUMNS[label.lower()]], errors="coerce")
    return df


def _apply_total_model(df: pd.DataFrame, model: Optional[Pipeline], features: Sequence[str]) -> pd.DataFrame:
    df = df.copy()
    if model is None or not features:
        df["p_over25_v2"] = df.get("p_over25")
        df["p_under25_v2"] = df.get("p_under25")
        df["delta_over25"] = np.nan
        return df
    X = df.reindex(columns=features)
    base = pd.to_numeric(df["p_over25"], errors="coerce")
    corr = pd.Series(model.predict(X), index=df.index)
    adj = base.fillna(0.5) + corr
    adj = adj.clip(lower=PROB_EPS, upper=1 - PROB_EPS)
    df["p_over25_v2"] = adj
    df["p_under25_v2"] = 1.0 - adj
    df["delta_over25"] = df["p_over25_v2"] - base
    return df


def _evaluate_outcome(df: pd.DataFrame) -> Dict[str, float]:
    metrics: Dict[str, float] = {}
    label_to_idx = {label: idx for idx, label in enumerate(CLASS_ORDER)}
    y = df["actual_result"].map(label_to_idx)
    mask = y.notna()
    if mask.sum() == 0:
        return metrics
    y_int = y.loc[mask].astype(int)
    probs_v1 = df.loc[mask, ["p_home", "p_draw", "p_away"]].to_numpy()
    probs_v2 = df.loc[mask, ["p_home_v2", "p_draw_v2", "p_away_v2"]].to_numpy()
    metrics["logloss_v1"] = float(log_loss(y_int, probs_v1, labels=[0, 1, 2]))
    metrics["logloss_v2"] = float(log_loss(y_int, probs_v2, labels=[0, 1, 2]))
    for label, col in zip(CLASS_ORDER, ["p_home", "p_draw", "p_away"]):
        mask_label = mask.copy()
        metrics[f"brier_{label.lower()}_v1"] = float(brier_score_loss((y_int == label_to_idx[label]).astype(int), df.loc[mask_label, col]))
    for label, col in zip(CLASS_ORDER, ["p_home_v2", "p_draw_v2", "p_away_v2"]):
        mask_label = mask.copy()
        metrics[f"brier_{label.lower()}_v2"] = float(brier_score_loss((y_int == label_to_idx[label]).astype(int), df.loc[mask_label, col]))
    return metrics


def _evaluate_total(df: pd.DataFrame) -> Dict[str, float]:
    metrics: Dict[str, float] = {}
    if "target_over25" not in df.columns or df["target_over25"].isna().all():
        return metrics
    mask = df["target_over25"].notna() & df["p_over25"].notna()
    if mask.sum() == 0:
        return metrics
    y = df.loc[mask, "target_over25"].astype(int)
    p_v1 = df.loc[mask, "p_over25"].clip(PROB_EPS, 1 - PROB_EPS)
    metrics["brier_over25_v1"] = float(brier_score_loss(y, p_v1))
    if "p_over25_v2" in df.columns:
        p_v2 = df.loc[mask, "p_over25_v2"].clip(PROB_EPS, 1 - PROB_EPS)
        metrics["brier_over25_v2"] = float(brier_score_loss(y, p_v2))
    return metrics


def cmd_train(args: argparse.Namespace) -> None:
    db_schema = args.schema or os.getenv("DB_SCHEMA", "football")
    db_table = args.table or os.getenv("DB_TABLE", "ml_predictions")
    date_from = _parse_date(args.date_from)
    date_to = _parse_date(args.date_to)

    engine = create_engine(_compose_db_url())
    df_raw = _fetch_predictions(
        engine,
        schema=db_schema,
        table=db_table,
        date_from=date_from,
        date_to=date_to,
        fixture_ids=args.fixture_ids,
        league_ids=args.league_ids,
        require_scores=True,
    )

    if df_raw.empty:
        raise RuntimeError("No finished matches found for the specified filters.")

    _ensure_numeric(df_raw, OUTCOME_FEATURE_CANDIDATES + TOTAL_FEATURE_CANDIDATES + list(PREDICTION_COLUMNS.values()))
    df = _derive_actuals(df_raw)
    if df.empty or len(df) < args.min_samples:
        raise RuntimeError(f"Not enough samples for training ({len(df)} < {args.min_samples}).")

    outcome_features = [col for col in OUTCOME_FEATURE_CANDIDATES if col in df.columns]
    if not outcome_features:
        raise RuntimeError("No usable outcome features detected.")

    outcome_models = _train_outcome_models(df, outcome_features)
    df_outcomes = _apply_outcome_models(df, outcome_models, outcome_features)

    total_features = [col for col in TOTAL_FEATURE_CANDIDATES if col in df.columns]
    total_model = _train_total_model(df_outcomes, total_features) if total_features else None
    df_totals = _apply_total_model(df_outcomes, total_model, total_features if total_model else [])

    outcome_metrics = _evaluate_outcome(df_totals)
    total_metrics = _evaluate_total(df_totals)

    package = {
        "schema": db_schema,
        "table": db_table,
        "outcome_features": outcome_features,
        "total_features": total_features if total_model else [],
        "outcome_models": outcome_models,
        "total_model": total_model,
        "metrics": {
            "outcome": outcome_metrics,
            "total": total_metrics,
        },
        "trained_rows": int(len(df_totals)),
        "date_range": {
            "from": df_totals["match_datetime"].min().isoformat() if "match_datetime" in df_totals.columns else None,
            "to": df_totals["match_datetime"].max().isoformat() if "match_datetime" in df_totals.columns else None,
        },
    }

    output_path = Path(args.output or DEFAULT_MODEL_FILE)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(package, output_path)

    print(f"[TRAIN] Stored residual package to {output_path}")
    print(f"[TRAIN] Samples used: {len(df_totals)}")
    if outcome_metrics:
        print(
            "[TRAIN] Outcome logloss v1 -> {0:.5f}, v2 -> {1:.5f}".format(
                outcome_metrics.get("logloss_v1", float("nan")),
                outcome_metrics.get("logloss_v2", float("nan")),
            )
        )
    for key, val in sorted(outcome_metrics.items()):
        if key.startswith("brier_"):
            print(f"    {key}: {val:.5f}")
    if total_metrics:
        for key, val in sorted(total_metrics.items()):
            print(f"[TRAIN] {key}: {val:.5f}")


def _load_package(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Model package '{path}' does not exist")
    package = joblib.load(path)
    if not isinstance(package, dict):
        raise TypeError("Loaded package is not a dict")
    return package


def cmd_apply(args: argparse.Namespace) -> None:
    package_path = Path(args.model)
    package = _load_package(package_path)

    db_schema = args.schema or package.get("schema") or os.getenv("DB_SCHEMA", "football")
    db_table = args.table or package.get("table") or os.getenv("DB_TABLE", "ml_predictions")
    date_from = _parse_date(args.date_from)
    date_to = _parse_date(args.date_to)

    engine = create_engine(_compose_db_url())
    df_raw = _fetch_predictions(
        engine,
        schema=db_schema,
        table=db_table,
        date_from=date_from,
        date_to=date_to,
        fixture_ids=args.fixture_ids,
        league_ids=args.league_ids,
        require_scores=False,
    )

    if df_raw.empty:
        print("[APPLY] No predictions found for the specified filters.")
        return

    _ensure_numeric(df_raw, OUTCOME_FEATURE_CANDIDATES + TOTAL_FEATURE_CANDIDATES + list(PREDICTION_COLUMNS.values()))

    outcome_models = package.get("outcome_models")
    if not outcome_models:
        raise RuntimeError("Model package lacks outcome models")

    outcome_features: Sequence[str] = package.get("outcome_features", [])
    df_outcomes = _apply_outcome_models(df_raw, outcome_models, outcome_features)

    total_model = package.get("total_model")
    total_features: Sequence[str] = package.get("total_features", [])
    df_totals = _apply_total_model(df_outcomes, total_model, total_features)

    preview_cols = [
        "fixture_id",
        "match_datetime",
        "p_home",
        "p_home_v2",
        "p_draw",
        "p_draw_v2",
        "p_away",
        "p_away_v2",
        "delta_home",
        "delta_draw",
        "delta_away",
        "p_over25",
        "p_over25_v2",
        "delta_over25",
    ]
    missing_preview = [col for col in preview_cols if col not in df_totals.columns]
    preview = df_totals[[col for col in preview_cols if col not in missing_preview]].head(args.preview)

    if args.output_csv:
        out_path = Path(args.output_csv)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        df_totals.to_csv(out_path, index=False)
        print(f"[APPLY] Saved corrected predictions to {out_path}")
    else:
        print(df_totals.head(args.preview or 10).to_string(index=False))

    if not preview.empty:
        print("\n[APPLY] Preview of adjustments:")
        print(preview.to_string(index=False))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Residual layer for prognoz_v1 predictions")
    subparsers = parser.add_subparsers(dest="command", required=True)

    train = subparsers.add_parser("train", help="Train residual correction models")
    train.add_argument("--date-from", required=True, help="Lower bound date (inclusive), e.g. 2024-01-01")
    train.add_argument("--date-to", required=True, help="Upper bound date (inclusive), e.g. 2024-06-30")
    train.add_argument("--schema", default=None, help="DB schema for predictions table")
    train.add_argument("--table", default=None, help="Predictions table name")
    train.add_argument("--fixture-ids", nargs="*", type=int, help="Specific fixture IDs to include")
    train.add_argument("--league-ids", nargs="*", type=int, help="Filter by league IDs")
    train.add_argument("--min-samples", type=int, default=300, help="Minimal number of finished matches for training")
    train.add_argument("--output", default=DEFAULT_MODEL_FILE, help="Path to store the trained package")

    apply = subparsers.add_parser("apply", help="Apply residual correction to stored predictions")
    apply.add_argument("--model", required=True, help="Path to a trained residual package")
    apply.add_argument("--date-from", help="Lower bound date (inclusive)")
    apply.add_argument("--date-to", help="Upper bound date (inclusive)")
    apply.add_argument("--schema", default=None, help="DB schema for predictions table")
    apply.add_argument("--table", default=None, help="Predictions table name")
    apply.add_argument("--fixture-ids", nargs="*", type=int, help="Specific fixture IDs to include")
    apply.add_argument("--league-ids", nargs="*", type=int, help="Filter by league IDs")
    apply.add_argument("--output-csv", help="Optional path to write corrected predictions")
    apply.add_argument("--preview", type=int, default=10, help="Number of rows to display in preview")

    return parser


def main(argv: Optional[Sequence[str]] = None) -> None:
    _bootstrap_env()
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "train":
        cmd_train(args)
    elif args.command == "apply":
        cmd_apply(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()