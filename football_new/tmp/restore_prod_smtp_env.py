from pathlib import Path


SRC = Path("/opt/football-app/deploy/.env.prod")
DST = Path("/opt/football-app/.env")
NEED = {"SMTP_LOGIN", "YANDEX_APP_PASSWORD", "FROM_EMAIL"}


def parse_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text().splitlines():
        if "=" not in line or line.lstrip().startswith("#"):
            continue
        key, value = line.split("=", 1)
        out[key] = value
    return out


def main() -> None:
    src_vals = parse_env(SRC)
    dst_vals = parse_env(DST) if DST.exists() else {}

    for key in NEED:
        if key in src_vals:
            dst_vals[key] = src_vals[key]

    lines: list[str] = []
    existing_lines = DST.read_text().splitlines() if DST.exists() else []
    seen: set[str] = set()
    for line in existing_lines:
        if "=" in line and not line.lstrip().startswith("#"):
            key = line.split("=", 1)[0]
            if key in dst_vals:
                lines.append(f"{key}={dst_vals[key]}")
                seen.add(key)
                continue
        lines.append(line)

    for key in sorted(dst_vals):
        if key not in seen:
            lines.append(f"{key}={dst_vals[key]}")

    DST.write_text("\n".join(lines) + "\n")
    print("restored", ",".join(sorted(NEED)))


if __name__ == "__main__":
    main()
