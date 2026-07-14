#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
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
    build_trial_hash,
    ensure_metadata,
    normalize_database_url,
    rebuild_summaries,
    upsert_source,
    upsert_trial_result,
    upsert_variety,
)


DEMO_PAGES = [
    {
        "name": "Демонстрационные испытания в Краснодарском крае",
        "url": "https://agroplazma.com/demo/demonstracionnye_ispytaniya_v_krasnodarskom_krae_30",
        "cache_path": "/tmp/agro_demo_krasnodar.html",
        "subject_rf": "Краснодарский край",
        "macro_region": "SOUTH",
    },
    {
        "name": "Демонстрационные испытания в Саратовской области",
        "url": "https://agroplazma.com/demo/demonstracionnye_ispytaniya_v_saratovskoy_oblasti_29",
        "cache_path": "/tmp/agro_demo_saratov.html",
        "subject_rf": "Саратовская область",
        "macro_region": "VOLGA",
    },
    {
        "name": "Демонстрационные испытания в Оренбургской области",
        "url": "https://agroplazma.com/demo/demonstracionnye_ispytaniya_v_orenburgskoy_oblasti_28",
        "cache_path": "/tmp/agro_demo_orenburg.html",
        "subject_rf": "Оренбургская область",
        "macro_region": "URAL",
    },
]


def fetch_soup(url: str, cache_path: str | None = None) -> BeautifulSoup:
    if cache_path and Path(cache_path).exists():
        content = Path(cache_path).read_bytes()
        return BeautifulSoup(content.decode("utf-8", errors="replace"), "lxml")
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    content = response.content
    if cache_path:
        Path(cache_path).write_bytes(content)
    return BeautifulSoup(content.decode("utf-8", errors="replace"), "lxml")


def clean(text: str) -> str:
    return " ".join(text.replace("\xa0", " ").split())


def parse_decimal(value: str) -> float | None:
    match = re.search(r"\d+(?:[.,]\d+)?", value)
    if not match:
        return None
    return float(match.group(0).replace(",", "."))


def normalize_variety_name(name: str) -> str:
    return clean(name).replace("СВ", "").strip()


def crop_from_header(header: list[str]) -> tuple[str, float | None]:
    joined = " | ".join(header)
    if "Технология" in joined:
        return "sunflower", 7.0
    if "Группа спелости (ФАО)" in joined:
        return "corn", 14.0
    if "Вид сорго" in joined:
        return "sorghum", None
    raise RuntimeError(f"Unknown table header: {header}")


def provider_for_variety(crop_code: str, variety_name: str) -> str:
    if variety_name.lower() in {"иностранный стандарт", "стандарт"}:
        return "Benchmark"
    return "Agroplazma"


def source_code(subject_rf: str, crop_code: str) -> str:
    subject_code = re.sub(r"[^A-Za-z0-9А-Яа-яЁё]+", "_", subject_rf.upper()).strip("_")
    return f"AGROPLAZMA_DEMO_2023_{crop_code.upper()}_{subject_code}"[:64]


def parse_demo_page(page_meta: dict[str, str]) -> list[dict[str, Any]]:
    soup = fetch_soup(page_meta["url"], page_meta.get("cache_path"))
    parsed_rows: list[dict[str, Any]] = []

    for table in soup.find_all("table"):
        rows = []
        for tr in table.find_all("tr"):
            cells = [clean(td.get_text(" ", strip=True)) for td in tr.find_all(["td", "th"])]
            if cells:
                rows.append(cells)
        if not rows:
            continue
        if not any("Урожайность" in " ".join(r) for r in rows[:2]):
            continue

        header = rows[0]
        crop_code, standard_moisture_pct = crop_from_header(header)
        current_district: str | None = None
        current_year: int | None = None

        for row in rows[1:]:
            if len(row) < 4:
                continue
            district = row[0]
            if len(row) >= 5 and district and not district.isdigit():
                current_district = district
                current_year = int(row[1]) if row[1].isdigit() else current_year
                variety_name = row[2]
                extra_value = row[3]
                yield_standard_c_ha = parse_decimal(row[4])
            elif len(row) >= 4 and row[0].isdigit():
                current_year = int(row[0]) if row[0].isdigit() else current_year
                variety_name = row[1]
                extra_value = row[2]
                yield_standard_c_ha = parse_decimal(row[3])
            else:
                continue
            if current_district is None or current_year is None or yield_standard_c_ha is None:
                continue

            payload = {
                "provider": "Agroplazma",
                "source_code": source_code(page_meta["subject_rf"], crop_code),
                "crop_code": crop_code,
                "season_year": current_year,
                "macro_region": page_meta["macro_region"],
                "variety_name": variety_name,
                "subject_rf": page_meta["subject_rf"],
                "district": current_district,
                "sowing_date_raw": None,
                "harvest_date_raw": None,
                "plant_density_ths_per_ha": None,
                "harvest_moisture_pct": None,
                "standard_moisture_pct": standard_moisture_pct,
                "yield_standard_c_ha": yield_standard_c_ha,
                "source_url": page_meta["url"],
                "source_page": None,
                "raw_text": " | ".join(row),
                "extra_value": extra_value,
            }
            payload["record_hash"] = build_trial_hash(payload)
            parsed_rows.append(payload)
    return parsed_rows


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    loaded = 0
    with Session(engine) as db:
        for page_meta in DEMO_PAGES:
            rows = parse_demo_page(page_meta)
            source_ids: dict[str, int] = {}
            for row in rows:
                crop_code = row["crop_code"]
                if crop_code not in source_ids:
                    source_ids[crop_code] = upsert_source(
                        db,
                        code=source_code(page_meta["subject_rf"], crop_code),
                        provider="Agroplazma",
                        source_type="trial_page",
                        name=f"{page_meta['name']} / {crop_code}",
                        source_url=page_meta["url"],
                        crop_code=crop_code,
                        season_year=2023,
                        macro_region=page_meta["macro_region"],
                    )

                manufacturer_norm = provider_for_variety(crop_code, row["variety_name"])
                variety_id = upsert_variety(
                    db,
                    crop_code=crop_code,
                    product_type="hybrid",
                    name_raw=normalize_variety_name(row["variety_name"]),
                    manufacturer_norm=manufacturer_norm,
                )
                source_id = source_ids[crop_code]
                upsert_trial_result(db, row, source_id, variety_id)
                loaded += 1

            db.commit()

        rebuild_summaries(db)
        db.commit()

        summary = db.execute(
            text(
                """
                select s.crop_code, count(*) as rows
                from hybrids.trial_results tr
                join hybrids.sources s on s.id = tr.source_id
                where s.provider = 'Agroplazma' and s.source_type = 'trial_page' and s.season_year = 2023
                group by s.crop_code
                order by s.crop_code
                """
            )
        ).mappings().all()
        print("[hybrids] agroplazma demo append summary", {"loaded": loaded, "by_crop": [dict(r) for r in summary]})


if __name__ == "__main__":
    main()
