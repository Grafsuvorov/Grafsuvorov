#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from urllib.parse import urljoin

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


BASE_URL = "https://lgseeds.ru"
LISTING_SOURCES = [
    {"listing_url": "https://lgseeds.ru/cultures/kukuruza/", "crop_code": "corn", "product_type": "hybrid"},
    {"listing_url": "https://lgseeds.ru/cultures/sunflower/", "crop_code": "sunflower", "product_type": "hybrid"},
]


def fetch_soup(url: str) -> BeautifulSoup:
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    return BeautifulSoup(response.text, "lxml")


def parse_label_value(text: str, label: str) -> str | None:
    match = re.search(rf"{re.escape(label)}\s*:\s*(.+)", text, flags=re.I)
    return match.group(1).strip() if match else None


def extract_listing_items(listing_url: str, crop_code: str) -> list[dict[str, str]]:
    soup = fetch_soup(listing_url)
    items: list[dict[str, str]] = []
    seen_urls: set[str] = set()
    for anchor in soup.find_all("a", href=True):
        href = anchor["href"]
        if crop_code == "corn" and "/cultures/kukuruza/" not in href:
            continue
        if crop_code == "sunflower" and "/cultures/sunflower/" not in href:
            continue
        if href.endswith("/filter/clear/apply/") or href.rstrip("/") == f"/cultures/{'kukuruza' if crop_code == 'corn' else 'sunflower'}":
            continue
        abs_url = urljoin(BASE_URL, href)
        if abs_url in seen_urls:
            continue
        text = " ".join(anchor.get_text(" ", strip=True).split())
        if not text:
            continue
        seen_urls.add(abs_url)
        items.append({"url": abs_url, "teaser_text": text})
    return items


def parse_limagrain_item(item: dict[str, str], crop_code: str, product_type: str) -> dict[str, object]:
    page = fetch_soup(item["url"])
    text = "\n".join(line.strip() for line in page.get_text("\n").splitlines() if line.strip())
    title = None
    h1 = page.find("h1")
    if h1:
        title = " ".join(h1.get_text(" ", strip=True).split())
    if not title:
        title = item["teaser_text"].split(" фао ", 1)[0].split(" Группа спелости", 1)[0].strip()

    teaser = item["teaser_text"]
    fao = None
    fao_match = re.search(r"фао\s*(\d+)", teaser, flags=re.I)
    if fao_match:
        fao = int(fao_match.group(1))

    maturity_label = parse_label_value(teaser, "Группа спелости") or parse_label_value(text, "Группа спелости")
    purpose = parse_label_value(teaser, "Назначение") or parse_label_value(text, "Назначение")
    grain_type = parse_label_value(teaser, "Тип зерна") or parse_label_value(text, "Тип зерна")
    cultivation = parse_label_value(teaser, "Технология возделывания") or parse_label_value(text, "Технология возделывания")
    broomrape = parse_label_value(teaser, "Устойчивость к заразихе") or parse_label_value(text, "Устойчивость к заразихе")
    federal_districts = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("+ "):
            federal_districts.append(line.replace("+ ", "", 1))

    oil_pct = None
    oil_match = re.search(r"масличность[:\s]+(\d+[.,]?\d*)%", text, flags=re.I)
    if oil_match:
        oil_pct = float(oil_match.group(1).replace(",", "."))

    return {
        "crop_code": crop_code,
        "product_type": product_type,
        "name": title,
        "maturity_label": maturity_label,
        "fao": fao,
        "payload": {
            "provider": "Limagrain",
            "season_year": 2026,
            "teaser_text": teaser,
            "purpose": purpose,
            "grain_type": grain_type,
            "cultivation_technology": cultivation,
            "broomrape_resistance": broomrape,
            "recommended_federal_districts": federal_districts,
            "raw_text": text,
        },
        "oil_pct": oil_pct,
        "source_url": item["url"],
    }


def make_source_code(crop_code: str, name: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "_", name.upper()).strip("_")
    return f"LG_PAGE_2026_{crop_code.upper()}_{slug}"[:64]


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    loaded = 0
    with Session(engine) as db:
        for source_meta in LISTING_SOURCES:
            items = extract_listing_items(source_meta["listing_url"], source_meta["crop_code"])
            for item in items:
                trait = parse_limagrain_item(item, source_meta["crop_code"], source_meta["product_type"])
                source_id = upsert_source(
                    db,
                    code=make_source_code(source_meta["crop_code"], str(trait["name"])),
                    provider="Limagrain",
                    source_type="product_page",
                    name=str(trait["name"]),
                    source_url=str(trait["source_url"]),
                    crop_code=source_meta["crop_code"],
                    season_year=2026,
                )
                variety_id = upsert_variety(
                    db,
                    crop_code=source_meta["crop_code"],
                    product_type=source_meta["product_type"],
                    name_raw=str(trait["name"]),
                    manufacturer_norm="Limagrain",
                )
                upsert_trait_snapshot(
                    db,
                    variety_id=variety_id,
                    source_id=source_id,
                    crop_code=source_meta["crop_code"],
                    maturity_label=trait["maturity_label"],
                    fao=trait["fao"],
                    standard_moisture_pct=14.0 if source_meta["crop_code"] == "corn" else 7.0,
                    protein_pct=None,
                    oil_pct=trait["oil_pct"],
                    starch_pct=None,
                    yield_min_c_ha=None,
                    yield_max_c_ha=None,
                    payload=trait["payload"],
                    source_url=str(trait["source_url"]),
                )
                loaded += 1
            db.commit()

        summary = db.execute(
            text(
                """
                select
                    count(*) filter (where provider = 'Limagrain' and season_year = 2026) as sources_2026,
                    count(*) filter (where provider = 'Limagrain') as sources_total
                from hybrids.sources
                """
            )
        ).mappings().one()
        trait_summary = db.execute(
            text(
                """
                select count(*) as trait_rows_2026
                from hybrids.trait_snapshots ts
                join hybrids.sources s on s.id = ts.source_id
                where s.provider = 'Limagrain' and s.season_year = 2026
                """
            )
        ).mappings().one()
        print("[hybrids] limagrain append summary", {"loaded": loaded, **dict(summary), **dict(trait_summary)})


if __name__ == "__main__":
    main()
