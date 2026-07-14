#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any

import requests
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


MAP_URL = "https://yandex.ru/map-widget/v1/?um=constructor%3A6e5d4fa629905ad1de631849e18d1104408c8db5834b5b61d155c4d985dffe90&source=constructor"
CACHE_PATH = Path("/tmp/agroplazma_yield_map_widget.html")


def fetch_widget_html() -> str:
    if CACHE_PATH.exists():
        return CACHE_PATH.read_text(encoding="utf-8")
    response = requests.get(MAP_URL, timeout=60)
    response.raise_for_status()
    CACHE_PATH.write_text(response.text, encoding="utf-8")
    return response.text


def extract_features(html: str) -> list[dict[str, Any]]:
    marker = '"features":['
    start = html.find(marker)
    if start == -1:
        raise RuntimeError("features array not found in widget HTML")
    start = html.find("[", start)
    depth = 0
    end = None
    for i, ch in enumerate(html[start:], start):
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise RuntimeError("failed to locate end of features array")
    return json.loads(html[start:end])


def clean(text: str) -> str:
    return " ".join(text.replace("\xa0", " ").split())


def parse_decimal(text: str) -> float | None:
    m = re.search(r"(\d+(?:[.,]\d+)?)", text)
    return float(m.group(1).replace(",", ".")) if m else None


def classify_crop(line: str) -> str | None:
    low = line.lower()
    if "подсолнеч" in low:
        return "sunflower"
    if "кукуруз" in low:
        return "corn"
    if "сорго" in low:
        return "sorghum"
    if "нут" in low:
        return "chickpea"
    return None


def product_type_for_crop(crop_code: str) -> str:
    if crop_code == "chickpea":
        return "variety"
    return "hybrid"


def manufacturer_for_name(name: str) -> str:
    low = name.lower()
    if "стандарт" in low:
        return "Benchmark"
    return "Agroplazma"


def parse_feature(feature: dict[str, Any]) -> list[dict[str, Any]]:
    title = clean(feature.get("title", ""))
    subtitle = feature.get("subtitle", "")
    coords = feature.get("coordinates")
    lines = [clean(line) for line in subtitle.split("\n") if clean(line)]

    rows: list[dict[str, Any]] = []
    current_year: int | None = None
    current_crop: str | None = None

    for line in lines:
        year_matches = re.findall(r"20\d{2}", line)
        crop_from_line = classify_crop(line)

        if year_matches:
            current_year = int(year_matches[-1])
        if crop_from_line:
            current_crop = crop_from_line

        if " - " not in line:
            continue
        variety_name, rhs = [part.strip() for part in line.split(" - ", 1)]
        yield_value = parse_decimal(rhs)
        if yield_value is None:
            continue
        if current_crop is None:
            crop_guess = classify_crop(subtitle)
            current_crop = crop_guess
        if current_year is None or current_crop is None:
            continue

        oil_pct = None
        oil_match = re.search(r"масличност[ьи]\s*(\d+(?:[.,]\d+)?)%", rhs, flags=re.I)
        if oil_match:
            oil_pct = float(oil_match.group(1).replace(",", "."))

        standard_moisture_pct = 14.0 if current_crop == "corn" else 7.0 if current_crop == "sunflower" else None
        source_code = f"AGROPLAZMA_MAP_{current_crop.upper()}_{current_year}"
        payload = {
            "provider": "Agroplazma",
            "source_code": source_code,
            "crop_code": current_crop,
            "season_year": current_year,
            "macro_region": None,
            "variety_name": variety_name,
            "subject_rf": None,
            "district": None,
            "sowing_date_raw": None,
            "harvest_date_raw": None,
            "plant_density_ths_per_ha": None,
            "harvest_moisture_pct": None,
            "standard_moisture_pct": standard_moisture_pct,
            "yield_standard_c_ha": yield_value,
            "source_url": MAP_URL,
            "source_page": None,
            "raw_text": f"{title} | {subtitle}",
            "payload": {
                "site_name": title,
                "coordinates": coords,
                "subtitle": subtitle,
                "oil_pct": oil_pct,
            },
        }
        payload["record_hash"] = build_trial_hash(payload)
        rows.append(payload)
    return rows


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    html = fetch_widget_html()
    features = extract_features(html)
    rows = []
    for feature in features:
        rows.extend(parse_feature(feature))

    loaded = 0
    with Session(engine) as db:
        source_ids: dict[tuple[str, int], int] = {}
        for row in rows:
            key = (row["crop_code"], row["season_year"])
            if key not in source_ids:
                source_ids[key] = upsert_source(
                    db,
                    code=f"AGROPLAZMA_MAP_{row['crop_code'].upper()}_{row['season_year']}",
                    provider="Agroplazma",
                    source_type="map_widget",
                    name=f"Agroplazma yield map {row['crop_code']} {row['season_year']}",
                    source_url=MAP_URL,
                    crop_code=row["crop_code"],
                    season_year=row["season_year"],
                    macro_region=None,
                )
            variety_id = upsert_variety(
                db,
                crop_code=row["crop_code"],
                product_type=product_type_for_crop(row["crop_code"]),
                name_raw=row["variety_name"],
                manufacturer_norm=manufacturer_for_name(row["variety_name"]),
            )
            upsert_trial_result(db, row, source_ids[key], variety_id)
            loaded += 1
        db.commit()
        rebuild_summaries(db)
        db.commit()

        summary = db.execute(
            text(
                """
                select s.crop_code, s.season_year, count(*) as rows
                from hybrids.trial_results tr
                join hybrids.sources s on s.id = tr.source_id
                where s.provider = 'Agroplazma' and s.source_type = 'map_widget'
                group by s.crop_code, s.season_year
                order by s.season_year, s.crop_code
                """
            )
        ).mappings().all()
        print("[hybrids] agroplazma map append summary", {"loaded": loaded, "by_crop_year": [dict(r) for r in summary]})


if __name__ == "__main__":
    main()
