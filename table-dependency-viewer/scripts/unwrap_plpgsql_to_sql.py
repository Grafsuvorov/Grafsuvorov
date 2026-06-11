#!/usr/bin/env python3
"""Extract the original SQL payload from a debug-wrapped PL/pgSQL DO block."""

from __future__ import annotations

import argparse

from sql_wrap_utils import read_source_text, unwrap_plpgsql_to_sql, write_target_text


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Unwrap SQL payload from a PL/pgSQL wrapper created by wrap_sql_to_plpgsql_debug.py."
    )
    parser.add_argument("input", nargs="?", help="Input PL/pgSQL file. Reads from stdin when omitted.")
    parser.add_argument(
        "-o",
        "--output",
        help="Write the recovered SQL to this file instead of stdout.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    plpgsql_text = read_source_text(args.input)
    sql_text = unwrap_plpgsql_to_sql(plpgsql_text)
    write_target_text(args.output, sql_text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
