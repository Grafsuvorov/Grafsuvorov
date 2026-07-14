#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import os
import re
import sys
from pathlib import Path
from typing import Any

import requests
from bs4 import BeautifulSoup
from requests import HTTPError
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from api.core.config import settings  # noqa: E402
from scripts.hybrid_seed_loader import (  # noqa: E402
    ensure_metadata,
    normalize_database_url,
    upsert_source,
    upsert_trait_snapshot,
    upsert_variety,
)


KWS_CORN_SOURCES = [
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/frederiko-kws/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/kws-allegro/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/kws-akustika/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/%D0%BA%D0%B2%D1%81-%D0%BA%D0%B0%D1%88%D0%BC%D0%B8%D1%80/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/kws-3381/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/%D0%BA%D0%B2%D1%81-%D0%BE%D0%B4%D0%BE%D1%80%D0%B8%D0%BA%D0%BE/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/agro-janus/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/%D0%BAws-cura%D1%81%D0%B0%D0%BE/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/kws-kavalier/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/%D0%BA%D0%B2%D1%81-%D0%BB%D0%B8%D0%BE%D0%BD%D0%B5%D0%BB%D1%8C/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/kromvell/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/amarok/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/kubitus/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/klifton/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/kws-nestor/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/silvinio/",
    "https://www.kws.com/ru/ru/produkty/kukuruza/obzor-gibridov/komandos/",
]


def fetch_text(url: str) -> str:
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "lxml")
    return "\n".join(line.strip() for line in soup.get_text("\n").splitlines() if line.strip())


def normalize_title(line: str) -> str:
    return re.sub(r"\s+", " ", line.split(" - ", 1)[0]).strip()


def extract_usage(text: str) -> list[str]:
    section = re.search(
        r"Направление использования\s+(.+?)(?:Агрономические характеристики|Потенциал урожайности|Рекомендуемая густота|$)",
        text,
        flags=re.S,
    )
    if not section:
        return []
    usage = []
    for line in section.group(1).splitlines():
        value = line.strip(" -\t")
        if value:
            usage.append(value)
    return usage


def extract_potential(text: str, label: str) -> float | None:
    match = re.search(rf"{re.escape(label)}\s+(\d+[.,]?\d*)\s*ц/га", text, flags=re.I)
    if not match:
        return None
    return float(match.group(1).replace(",", "."))


def extract_line_value(text: str, label: str) -> str | None:
    match = re.search(rf"{re.escape(label)}\s*:?\s*(.+)", text, flags=re.I)
    return match.group(1).strip() if match else None


def parse_kws_product(url: str) -> dict[str, Any]:
    text = fetch_text(url)
    lines = [line for line in text.splitlines() if line]
    name = normalize_title(lines[0]) if lines else url.rstrip("/").rsplit("/", 1)[-1]
    fao_match = re.search(r"ФАО\s*(\d+)", text, flags=re.I)
    maturity_like = None
    for candidate in [
        "Раннеспелый",
        "Среднеранний",
        "Среднеспелый",
        "Среднепоздний",
    ]:
        if candidate.lower() in text.lower():
            maturity_like = candidate
            break

    usage = extract_usage(text)
    grain_potential = extract_potential(text, "Зерна")
    silage_potential = extract_potential(text, "Зелёной массы")
    grain_type = extract_line_value(text, "Тип зерна")
    moisture_release = extract_line_value(text, "Влагоотдача")
    intro_match = re.search(rf"{re.escape(name)}\s+ФАО\s*\d+\s+(.+?)Направление использования", text, flags=re.S)
    intro = re.sub(r"\s+", " ", intro_match.group(1)).strip() if intro_match else None

    starch_note = None
    if "крахмала" in text.lower():
        starch_note = "Упоминается крахмал/кормовая ценность"

    return {
        "name": name,
        "fao": int(fao_match.group(1)) if fao_match else None,
        "maturity_label": maturity_like,
        "standard_moisture_pct": 14.0,
        "yield_grain_potential_c_ha": grain_potential,
        "yield_silage_potential_c_ha": silage_potential,
        "payload": {
            "provider": "KWS",
            "season_year": 2026,
            "direction_of_use": usage,
            "grain_type": grain_type,
            "moisture_release": moisture_release,
            "intro": intro,
            "starch_note": starch_note,
            "raw_text": text,
        },
        "source_url": url,
    }


def source_code(name: str) -> str:
    digest = hashlib.sha1(name.encode("utf-8")).hexdigest()[:12].upper()
    return f"KWS_PAGE_2026_CORN_{digest}"


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    loaded = 0
    skipped: list[dict[str, str]] = []
    with Session(engine) as db:
        for url in KWS_CORN_SOURCES:
            try:
                product = parse_kws_product(url)
            except HTTPError as exc:
                skipped.append({"url": url, "error": str(exc)})
                print(f"[hybrids] skipped KWS {url}: {exc}")
                continue
            src_id = upsert_source(
                db,
                code=source_code(product["name"]),
                provider="KWS",
                source_type="product_page",
                name=product["name"],
                source_url=product["source_url"],
                crop_code="corn",
                season_year=2026,
            )
            variety_id = upsert_variety(
                db,
                crop_code="corn",
                product_type="hybrid",
                name_raw=product["name"],
                manufacturer_norm="KWS",
            )
            upsert_trait_snapshot(
                db,
                variety_id=variety_id,
                source_id=src_id,
                crop_code="corn",
                maturity_label=product["maturity_label"],
                fao=product["fao"],
                standard_moisture_pct=product["standard_moisture_pct"],
                protein_pct=None,
                oil_pct=None,
                starch_pct=None,
                yield_min_c_ha=product["yield_grain_potential_c_ha"],
                yield_max_c_ha=product["yield_silage_potential_c_ha"],
                payload=product["payload"],
                source_url=product["source_url"],
            )
            db.commit()
            loaded += 1
            print(f"[hybrids] loaded KWS {product['name']}")

        summary = db.execute(
            text(
                """
                select
                    count(*) filter (where provider = 'KWS' and season_year = 2026) as sources_2026,
                    count(*) filter (where provider = 'KWS') as sources_total
                from hybrids.sources
                """
            )
        ).mappings().one()
        traits = db.execute(
            text(
                """
                select count(*) as trait_rows_2026
                from hybrids.trait_snapshots ts
                join hybrids.sources s on s.id = ts.source_id
                where s.provider = 'KWS' and s.season_year = 2026
                """
            )
        ).mappings().one()
        print("[hybrids] kws append summary", {"loaded": loaded, "skipped": skipped, **dict(summary), **dict(traits)})


if __name__ == "__main__":
    main()
