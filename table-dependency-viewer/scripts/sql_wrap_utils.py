#!/usr/bin/env python3
"""Helpers for wrapping plain SQL into debug-friendly PL/pgSQL and back."""

from __future__ import annotations

import re
from pathlib import Path

BEGIN_MARKER = "-- >>> SQL_PAYLOAD_BEGIN >>>"
END_MARKER = "-- <<< SQL_PAYLOAD_END <<<"
DEBUG_VAR_NAMES = {
    "v_row_cnt",
    "v_row_cnt_agg",
    "v_calc_time",
    "v_start_dttm",
    "v_last_step_finish_dttm",
}


def normalize_newlines(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def read_source_text(path: str | None) -> str:
    if not path:
        from sys import stdin

        return normalize_newlines(stdin.read())
    return normalize_newlines(Path(path).read_text(encoding="utf-8"))


def write_target_text(path: str | None, text: str) -> None:
    if not path:
        from sys import stdout

        stdout.write(text)
        return
    Path(path).write_text(text, encoding="utf-8")


def _trim_leading_blank_lines(lines: list[str]) -> list[str]:
    while lines and not lines[0].strip():
        lines.pop(0)
    return lines


def _trim_trailing_blank_lines(lines: list[str]) -> list[str]:
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def _collapse_blank_lines(lines: list[str]) -> list[str]:
    result = []
    previous_blank = False
    for line in lines:
        is_blank = not line.strip()
        if is_blank and previous_blank:
            continue
        result.append(line)
        previous_blank = is_blank
    return result


def _dedent_lines(lines: list[str]) -> list[str]:
    indents = []
    for line in lines:
        if not line.strip():
            continue
        indents.append(len(line) - len(line.lstrip(" ")))
    if not indents:
        return lines
    common_indent = min(indents)
    if common_indent <= 0:
        return lines
    return [line[common_indent:] if len(line) >= common_indent else "" for line in lines]


def _split_sql_statements(sql_text: str) -> list[str]:
    text = normalize_newlines(sql_text)
    statements = []
    current = []
    i = 0
    in_single = False
    in_double = False
    in_line_comment = False
    in_block_comment = False
    dollar_tag = None

    while i < len(text):
        ch = text[i]
        next_two = text[i : i + 2]

        if in_line_comment:
            current.append(ch)
            if ch == "\n":
                in_line_comment = False
            i += 1
            continue

        if in_block_comment:
            current.append(ch)
            if next_two == "*/":
                current.append("/")
                i += 2
                in_block_comment = False
            else:
                i += 1
            continue

        if dollar_tag is not None:
            if text.startswith(dollar_tag, i):
                current.append(dollar_tag)
                i += len(dollar_tag)
                dollar_tag = None
            else:
                current.append(ch)
                i += 1
            continue

        if not in_single and not in_double:
            if next_two == "--":
                current.append("--")
                i += 2
                in_line_comment = True
                continue
            if next_two == "/*":
                current.append("/*")
                i += 2
                in_block_comment = True
                continue
            if ch == "$":
                match = re.match(r"\$[A-Za-z0-9_]*\$", text[i:])
                if match:
                    dollar_tag = match.group(0)
                    current.append(dollar_tag)
                    i += len(dollar_tag)
                    continue

        if ch == "'" and not in_double:
            current.append(ch)
            if in_single and i + 1 < len(text) and text[i + 1] == "'":
                current.append("'")
                i += 2
                continue
            in_single = not in_single
            i += 1
            continue

        if ch == '"' and not in_single:
            current.append(ch)
            in_double = not in_double
            i += 1
            continue

        if ch == ";" and not in_single and not in_double:
            current.append(ch)
            statement = "".join(current).strip()
            if statement:
                statements.append(statement)
            current = []
            i += 1
            continue

        current.append(ch)
        i += 1

    tail = "".join(current).strip()
    if tail:
        statements.append(tail)
    return statements


def _statement_label(statement_text: str, index: int) -> str:
    cleaned_lines = []
    for line in normalize_newlines(statement_text).split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("--"):
            continue
        cleaned_lines.append(stripped)
    lead = cleaned_lines[0] if cleaned_lines else statement_text.strip()
    normalized = re.sub(r"\s+", " ", lead.lower())

    patterns = [
        (r"^drop table if exists\s+([^\s(;]+)", "drop {}"),
        (r"^create (?:temporary|temp)?\s*table\s+([^\s(;]+)", "create {}"),
        (r"^truncate table\s+([^\s(;]+)", "truncate {}"),
        (r"^insert into\s+([^\s(;]+)", "insert {}"),
        (r"^analyze\s+([^\s(;]+)", "analyze {}"),
        (r"^delete from\s+([^\s(;]+)", "delete {}"),
        (r"^update\s+([^\s(;]+)", "update {}"),
    ]
    for pattern, template in patterns:
        match = re.search(pattern, normalized)
        if match:
            return template.format(match.group(1))
    preview = normalized[:48].strip() or "statement"
    return "step_{}_{}".format(index, preview)


def _is_debug_assignment(stripped_line: str) -> bool:
    for name in DEBUG_VAR_NAMES:
        if stripped_line.startswith(name + " :="):
            return True
    return False


def _extract_sql_from_debug_plpgsql(plpgsql_text: str) -> str:
    lines = normalize_newlines(plpgsql_text).split("\n")
    body_lines = []
    in_declare = False
    in_outer_body = False
    if_depth = 0

    for raw_line in lines:
        stripped = raw_line.strip()
        lower = stripped.lower()

        if not in_outer_body:
            if lower == "declare":
                in_declare = True
                continue
            if in_declare and lower == "begin":
                in_declare = False
                in_outer_body = True
                continue
            continue

        if lower in {"end", "end;"}:
            break

        if lower.startswith("if ") and lower.endswith(" then"):
            if_depth += 1
            continue
        if lower == "end if;":
            if_depth = max(0, if_depth - 1)
            continue
        if if_depth > 0:
            continue

        if not stripped:
            body_lines.append("")
            continue

        if stripped in {BEGIN_MARKER, END_MARKER}:
            continue
        if lower.startswith("raise notice"):
            continue
        if lower.startswith("get diagnostics"):
            continue
        if _is_debug_assignment(stripped):
            continue
        if lower.startswith("-- generated by wrap_sql_to_plpgsql_debug.py"):
            continue
        if lower.startswith("-- source:"):
            continue
        if lower in {"do", "do $$", "$$", "$$ language plpgsql;"}:
            continue
        if lower in {"begin"}:
            continue
        if lower.startswith("-- /* xxx") or lower.startswith("-- */ -- xxx"):
            continue

        body_lines.append(raw_line)

    body_lines = _trim_leading_blank_lines(body_lines)
    body_lines = _trim_trailing_blank_lines(body_lines)
    body_lines = _dedent_lines(body_lines)
    body_lines = _collapse_blank_lines(body_lines)
    return "\n".join(body_lines) + ("\n" if body_lines else "")


def wrap_sql_to_plpgsql(sql_text: str, source_name: str) -> str:
    payload = normalize_newlines(sql_text).rstrip("\n")
    statements = _split_sql_statements(payload)
    lines = [
        "-- generated by wrap_sql_to_plpgsql_debug.py",
        f"-- source: {source_name}",
        "DO $$",
        "DECLARE",
        "  v_row_cnt int8;",
        "  v_row_cnt_agg int8 = 0;",
        "  v_calc_time interval;",
        "  v_start_dttm timestamp(0);",
        "  v_last_step_finish_dttm timestamp(0);",
        f"  _source text := {sql_literal(source_name)};",
        "BEGIN",
        "  RAISE NOTICE 'wrap_sql_to_plpgsql_debug: start %', _source;",
        "  v_start_dttm := clock_timestamp();",
        "  v_last_step_finish_dttm := clock_timestamp();",
    ]

    for idx, statement in enumerate(statements, start=1):
        label = _statement_label(statement, idx)
        statement_lines = statement.split("\n")
        lines.append("")
        lines.append(f"  -- >>> STEP {idx}: {label} >>>")
        lines.extend(statement_lines)
        if not statement.rstrip().endswith(";"):
            lines[-1] = lines[-1] + ";"
        lines.extend(
            [
                "  get diagnostics v_row_cnt = row_count;",
                "  raise notice '% [%] {} (%)', to_char(clock_timestamp(),'hh24:mi:ss'), (clock_timestamp() - v_last_step_finish_dttm)::interval, v_row_cnt;".format(label.replace("'", "''")),
                "  v_last_step_finish_dttm := clock_timestamp();",
                "  v_row_cnt_agg := v_row_cnt_agg + v_row_cnt;",
            ]
        )

    lines.extend(
        [
            "",
            "  v_calc_time := clock_timestamp() - v_start_dttm;",
            "  RAISE NOTICE 'wrap_sql_to_plpgsql_debug: done % (%).', _source, v_calc_time;",
            "END;",
            "$$ LANGUAGE plpgsql;",
            "",
        ]
    )
    return "\n".join(lines)


def unwrap_plpgsql_to_sql(plpgsql_text: str) -> str:
    lines = normalize_newlines(plpgsql_text).split("\n")
    try:
        begin_index = lines.index(BEGIN_MARKER)
        end_index = lines.index(END_MARKER)
    except ValueError:
        return _extract_sql_from_debug_plpgsql(plpgsql_text)

    if end_index < begin_index:
        raise ValueError("Payload markers are in the wrong order.")

    payload = "\n".join(lines[begin_index + 1 : end_index]).rstrip("\n")
    return payload + ("\n" if payload else "")


def default_source_name(path: str | None) -> str:
    if not path:
        return "stdin.sql"
    return Path(path).name
