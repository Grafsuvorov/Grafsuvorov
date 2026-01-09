#!/usr/bin/env python
"""Utility script to load YouTrack incidents from an Excel export into the database."""

from pathlib import Path
import argparse
import sys

from api.main import import_ytrek_from_excel


def main(argv=None):
    parser = argparse.ArgumentParser(description="Import YouTrack incidents from Excel")
    parser.add_argument("excel_path", type=str, help="Path to tabl.xlsx export")
    args = parser.parse_args(argv)

    file_path = Path(args.excel_path)
    try:
        inserted = import_ytrek_from_excel(file_path)
    except Exception as exc:
        print(f"Failed to import incidents: {exc}", file=sys.stderr)
        return 1

    print(f"Loaded {inserted} incidents into the database from {file_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
