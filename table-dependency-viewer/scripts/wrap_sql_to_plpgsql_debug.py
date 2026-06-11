#!/usr/bin/env python3
"""Wrap plain SQL into a debug-friendly PL/pgSQL DO block."""

from __future__ import annotations

import argparse

from sql_wrap_utils import default_source_name, read_source_text, wrap_sql_to_plpgsql, write_target_text


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Wrap plain SQL into a PL/pgSQL DO block with payload markers."
    )
    parser.add_argument("input", nargs="?", help="Input SQL file. Reads from stdin when omitted.")
    parser.add_argument(
        "-o",
        "--output",
        help="Write the wrapped PL/pgSQL to this file instead of stdout.",
    )
    parser.add_argument(
        "--source-name",
        help="Label stored in the wrapper metadata. Defaults to the input file name.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_name = args.source_name or default_source_name(args.input)
    sql_text = read_source_text(args.input)
    wrapped = wrap_sql_to_plpgsql(sql_text, source_name)
    write_target_text(args.output, wrapped)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
