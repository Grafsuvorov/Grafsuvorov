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


MAS_SOURCES = [
    {
        "listing_url": "https://www.masseeds.ru/poisk-produktov/?seed=kukuruza",
        "crop_code": "corn",
        "product_type": "hybrid",
        "season_year": 2025,
    },
    {
        "listing_url": "https://www.masseeds.ru/poisk-produktov/?seed=podsolnechnik",
        "crop_code": "sunflower",
        "product_type": "hybrid",
        "season_year": 2025,
    },
]


def fetch_soup(url: str) -> BeautifulSoup:
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    return BeautifulSoup(response.text, "lxml")


def clean(text: str) -> str:
    return " ".join(text.replace("\xa0", " ").split())


def parse_fao(raw: str) -> tuple[int | None, str]:
    raw = clean(raw)
    nums = [int(x) for x in re.findall(r"\d+", raw)]
    if not nums:
        return None, raw
    if len(nums) == 1:
        return nums[0], raw
    return round(sum(nums) / len(nums)), raw


def extract_items(listing_url: str, crop_code: str) -> list[dict[str, Any]]:
    soup = fetch_soup(listing_url)
    items: list[dict[str, Any]] = []
    for anchor in soup.select("a.wp-block-product"):
        title_node = anchor.select_one(".wp-block-product__title")
        if title_node is None:
            continue
        name = clean(title_node.get_text(" ", strip=True))
        href = anchor.get("href")
        terms = [clean(node.get_text(" ", strip=True)) for node in anchor.select(".wp-block-product__term")]
        terms = [term for term in terms if term]
        marker_nodes = [clean(node.get_text(" ", strip=True)) for node in anchor.select(".wp-block-product__marker")]
        items.append(
            {
                "name": name,
                "crop_code": crop_code,
                "product_type": "hybrid",
                "source_url": href,
                "terms": terms,
                "markers": [m for m in marker_nodes if m],
            }
        )
    return items


def map_corn(item: dict[str, Any]) -> dict[str, Any]:
    maturity_label = item["terms"][0] if item["terms"] else None
    fao_raw = item["terms"][1] if len(item["terms"]) > 1 else ""
    fao, fao_raw = parse_fao(fao_raw)
    use_terms = [term for term in item["terms"][2:] if term]
    return {
        "name": item["name"],
        "crop_code": "corn",
        "product_type": "hybrid",
        "maturity_label": maturity_label,
        "fao": fao,
        "standard_moisture_pct": 14.0,
        "yield_min_c_ha": None,
        "yield_max_c_ha": None,
        "oil_pct": None,
        "payload": {
            "provider": "MAS Seeds",
            "season_year": 2025,
            "fao_raw": fao_raw,
            "direction_of_use": use_terms,
            "markers": item["markers"],
            "listing_terms": item["terms"],
        },
        "source_url": item["source_url"],
    }


def map_sunflower(item: dict[str, Any]) -> dict[str, Any]:
    maturity_label = None
    oil_type = None
    broomrape = None
    technology = None
    for term in item["terms"]:
        lower = term.lower()
        if "ранн" in lower or "спел" in lower:
            maturity_label = term
        elif "линолев" in lower or "олеин" in lower:
            oil_type = term
        elif "заразих" in lower:
            broomrape = term.replace("Устойчивость к расам заразихи", "").strip()
        elif lower in {"express", "clearfield", "clearfield®", "clearfield®plus"}:
            technology = term
    return {
        "name": item["name"],
        "crop_code": "sunflower",
        "product_type": "hybrid",
        "maturity_label": maturity_label,
        "fao": None,
        "standard_moisture_pct": 7.0,
        "yield_min_c_ha": None,
        "yield_max_c_ha": None,
        "oil_pct": None,
        "payload": {
            "provider": "MAS Seeds",
            "season_year": 2025,
            "oil_type": oil_type,
            "broomrape_resistance": broomrape,
            "cultivation_technology": technology,
            "markers": item["markers"],
            "listing_terms": item["terms"],
        },
        "source_url": item["source_url"],
    }


def source_code(crop_code: str, name: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9А-Яа-яЁё]+", "_", name.upper()).strip("_")
    return f"MAS_PAGE_2025_{crop_code.upper()}_{slug}"[:64]


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    loaded = 0
    with Session(engine) as db:
        for source_meta in MAS_SOURCES:
            raw_items = extract_items(source_meta["listing_url"], source_meta["crop_code"])
            mapped = [map_corn(item) if source_meta["crop_code"] == "corn" else map_sunflower(item) for item in raw_items]
            for item in mapped:
                source_id = upsert_source(
                    db,
                    code=source_code(item["crop_code"], item["name"]),
                    provider="MAS Seeds",
                    source_type="product_page",
                    name=item["name"],
                    source_url=item["source_url"],
                    crop_code=item["crop_code"],
                    season_year=source_meta["season_year"],
                )
                variety_id = upsert_variety(
                    db,
                    crop_code=item["crop_code"],
                    product_type=item["product_type"],
                    name_raw=item["name"],
                    manufacturer_norm="MAS Seeds",
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
                    source_url=item["source_url"],
                )
                loaded += 1
            db.commit()

        summary = db.execute(
            text(
                """
                select
                    count(*) filter (where provider = 'MAS Seeds' and season_year = 2025) as sources_2025,
                    count(*) filter (where provider = 'MAS Seeds') as sources_total
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
                where s.provider = 'MAS Seeds' and s.season_year = 2025
                """
            )
        ).mappings().one()
        print("[hybrids] mas seeds append summary", {"loaded": loaded, **dict(summary), **dict(trait_summary)})


if __name__ == "__main__":
    main()
