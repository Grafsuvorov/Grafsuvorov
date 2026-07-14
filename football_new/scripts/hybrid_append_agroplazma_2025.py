#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import Any

import requests
from bs4 import BeautifulSoup
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


AGROPLAZMA_SOURCES = [
    {
        "listing_url": "https://agroplazma.com/production/gibridi_kukuruzi",
        "crop_code": "corn",
        "product_type": "hybrid",
        "season_year": 2025,
    },
    {
        "listing_url": "https://agroplazma.com/production/gibridy_podsolnechnika",
        "crop_code": "sunflower",
        "product_type": "hybrid",
        "season_year": 2025,
    },
]


def fetch_soup(url: str) -> BeautifulSoup:
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    return BeautifulSoup(response.content.decode("utf-8", errors="replace"), "lxml")


def clean(text: str) -> str:
    return " ".join(text.replace("\xa0", " ").split())


def parse_range(value: str) -> tuple[float | None, float | None]:
    value = value.replace(",", ".").replace(">", "").strip()
    numbers = [float(x) for x in re.findall(r"\d+(?:\.\d+)?", value)]
    if not numbers:
        return None, None
    if len(numbers) == 1:
        return numbers[0], None
    return numbers[0], numbers[-1]


def parse_oil_pct(value: str) -> float | None:
    low, high = parse_range(value)
    if low is None:
        return None
    if high is None:
        return low
    return round((low + high) / 2.0, 2)


def parse_agroplazma_corn(soup: BeautifulSoup) -> list[dict[str, Any]]:
    table = soup.select_one("div.gibrids__table table")
    if table is None:
        raise RuntimeError("Agroplazma corn table not found")

    traits: list[dict[str, Any]] = []
    section_name: str | None = None
    for tr in table.find_all("tr"):
        cells = [clean(td.get_text(" ", strip=True)) for td in tr.find_all(["td", "th"])]
        if not cells:
            continue
        if cells[0] == "Гибрид":
            continue
        if len(cells) == 1:
            section_name = cells[0]
            continue
        if len(cells) < 5:
            continue
        yield_min, yield_max = parse_range(cells[4])
        traits.append(
            {
                "name": cells[0],
                "crop_code": "corn",
                "product_type": "hybrid",
                "maturity_label": None,
                "fao": int(cells[1]) if cells[1].isdigit() else None,
                "standard_moisture_pct": 14.0,
                "yield_min_c_ha": yield_min,
                "yield_max_c_ha": yield_max,
                "oil_pct": None,
                "payload": {
                    "provider": "Agroplazma",
                    "season_year": 2025,
                    "section": section_name,
                    "grain_type": cells[2],
                    "direction_of_use": cells[3],
                    "yield_raw": cells[4],
                },
            }
        )
    return traits


def parse_agroplazma_sunflower(soup: BeautifulSoup) -> list[dict[str, Any]]:
    table = soup.select_one("div.gibrids__table table")
    if table is None:
        raise RuntimeError("Agroplazma sunflower table not found")

    traits: list[dict[str, Any]] = []
    section_name: str | None = None
    for tr in table.find_all("tr"):
        cells = [clean(td.get_text(" ", strip=True)) for td in tr.find_all(["td", "th"])]
        if not cells:
            continue
        if cells[0] == "Гибрид":
            continue
        if len(cells) == 1:
            section_name = cells[0]
            continue
        if len(cells) < 6:
            continue
        yield_min, _ = parse_range(cells[5])
        traits.append(
            {
                "name": cells[0],
                "crop_code": "sunflower",
                "product_type": "hybrid",
                "maturity_label": cells[1],
                "fao": None,
                "standard_moisture_pct": 7.0,
                "yield_min_c_ha": yield_min,
                "yield_max_c_ha": None,
                "oil_pct": parse_oil_pct(cells[4]),
                "payload": {
                    "provider": "Agroplazma",
                    "season_year": 2025,
                    "section": section_name,
                    "cultivation_technology": cells[2],
                    "broomrape_resistance": cells[3],
                    "oil_pct_raw": cells[4],
                    "yield_raw": cells[5],
                },
            }
        )
    return traits


def source_code(crop_code: str, name: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9А-Яа-яЁё]+", "_", name.upper()).strip("_")
    return f"AGROPLAZMA_PAGE_2025_{crop_code.upper()}_{slug}"[:64]


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    loaded = 0
    with Session(engine) as db:
        for source_meta in AGROPLAZMA_SOURCES:
            soup = fetch_soup(source_meta["listing_url"])
            if source_meta["crop_code"] == "corn":
                items = parse_agroplazma_corn(soup)
            else:
                items = parse_agroplazma_sunflower(soup)
            for item in items:
                source_id = upsert_source(
                    db,
                    code=source_code(item["crop_code"], item["name"]),
                    provider="Agroplazma",
                    source_type="product_page",
                    name=item["name"],
                    source_url=source_meta["listing_url"],
                    crop_code=item["crop_code"],
                    season_year=source_meta["season_year"],
                )
                variety_id = upsert_variety(
                    db,
                    crop_code=item["crop_code"],
                    product_type=item["product_type"],
                    name_raw=item["name"],
                    manufacturer_norm="Agroplazma",
                )
                upsert_trait_snapshot(
                    db,
                    variety_id=variety_id,
                    source_id=source_id,
                    crop_code=item["crop_code"],
                    maturity_label=item["maturity_label"],
                    fao=item["fao"],
                    standard_moisture_pct=item["standard_moisture_pct"],
                    protein_pct=None,
                    oil_pct=item["oil_pct"],
                    starch_pct=None,
                    yield_min_c_ha=item["yield_min_c_ha"],
                    yield_max_c_ha=item["yield_max_c_ha"],
                    payload=item["payload"],
                    source_url=source_meta["listing_url"],
                )
                loaded += 1
            db.commit()

        summary = db.execute(
            text(
                """
                select
                    count(*) filter (where provider = 'Agroplazma' and season_year = 2025) as sources_2025,
                    count(*) filter (where provider = 'Agroplazma') as sources_total
                from hybrids.sources
                """
            )
        ).mappings().one()
        trait_summary = db.execute(
            text(
                """
                select count(*) as trait_rows_2025
                from hybrids.trait_snapshots ts
                join hybrids.sources s on s.id = ts.source_id
                where s.provider = 'Agroplazma' and s.season_year = 2025
                """
            )
        ).mappings().one()
        print("[hybrids] agroplazma append summary", {"loaded": loaded, **dict(summary), **dict(trait_summary)})


if __name__ == "__main__":
    main()
