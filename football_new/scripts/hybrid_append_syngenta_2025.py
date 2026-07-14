#!/usr/bin/env python3
from __future__ import annotations

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


SYNGENTA_2025_PRODUCT_SOURCES = [
    # Corn
    {"code": "SYN_PAGE_2025_CORN_SY_ROTANGO", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/sy-rotango/"},
    {"code": "SYN_PAGE_2025_CORN_SY_TELIAS", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/sy-telias/"},
    {"code": "SYN_PAGE_2025_CORN_SY_CARIOCA", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/sy-carioca/"},
    {"code": "SYN_PAGE_2025_CORN_SY_OZON", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/ozon/"},
    {"code": "SYN_PAGE_2025_CORN_SY_SCORPIUS", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/sy-scorpius/"},
    {"code": "SYN_PAGE_2025_CORN_SY_FENOMEN", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/sy-fenomen/"},
    {"code": "SYN_PAGE_2025_CORN_SY_FORTAGO", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/sy-fortago/"},
    {"code": "SYN_PAGE_2025_CORN_SY_CHORINTOS", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/sy-chorintos/"},
    {"code": "SYN_PAGE_2025_CORN_SI_PREMEO", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/si-premeo/"},
    {"code": "SYN_PAGE_2025_CORN_ENERMAX", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/enermax/"},
    {"code": "SYN_PAGE_2025_CORN_SY_KARDONA", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/sy-kardona/"},
    {"code": "SYN_PAGE_2025_CORN_SY_UNITOP", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/sy-unitop/"},
    {"code": "SYN_PAGE_2025_CORN_SY_AQUARIUS", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/corn/sy-aquarius"},
    {"code": "SYN_PAGE_2025_CORN_SI_DIPLOMAT", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/corn/si-diplomat"},
    # Sunflower
    {"code": "SYN_PAGE_2025_SUN_TEOS", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/teos"},
    {"code": "SYN_PAGE_2025_SUN_ROZETA_CLP", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/sy-rozeta-clp"},
    {"code": "SYN_PAGE_2025_SUN_AVENGER", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/avenger"},
    {"code": "SYN_PAGE_2025_SUN_SUBEO", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/subeo"},
    {"code": "SYN_PAGE_2025_SUN_SUZUKA", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/suzuka"},
    {"code": "SYN_PAGE_2025_SUN_SUBERIK", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/suberik"},
    {"code": "SYN_PAGE_2025_SUN_BACARDI_CLP", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/sy-bacardi-clp"},
    {"code": "SYN_PAGE_2025_SUN_DUNKAN_CLP", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/dunkan-clp"},
    {"code": "SYN_PAGE_2025_SUN_ARCO", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/sy-arco"},
    {"code": "SYN_PAGE_2025_SUN_SUOMI", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/suomi"},
    {"code": "SYN_PAGE_2025_SUN_CHESTER", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/sy-chester"},
    {"code": "SYN_PAGE_2025_SUN_LASCALA", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/sy-lascala"},
]


def fetch_text(url: str) -> str:
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "lxml")
    return "\n".join(line.strip() for line in soup.get_text("\n").splitlines() if line.strip())


def normalize_title(title: str) -> str:
    title = title.split("—", 1)[0].strip()
    return re.sub(r"\s+", " ", title)


def match_value(text: str, label: str) -> str | None:
    pattern = rf"{re.escape(label)}:\s*(.+?)(?:\n[A-ЯЁA-Z][^:\n]+:|\n(?:Основная информация|Документы|Свойства|Регламенты применения|Технологическое качество|Густота на период уборки|Материалы для скачивания|Disease Resistance)|$)"
    match = re.search(pattern, text, flags=re.S)
    if not match:
        return None
    value = re.sub(r"\s+", " ", match.group(1)).strip()
    return value or None


def parse_syngenta_product(meta: dict[str, Any]) -> dict[str, Any]:
    text = fetch_text(meta["source_url"])
    lines = [line for line in text.splitlines() if line]
    title = normalize_title(lines[0]) if lines else meta["code"]
    updated_at = match_value(text, "Актуализация")
    fao_match = re.search(r"ФАО:\s*(\d+)", text, flags=re.I)
    maturity_label = match_value(text, "Группа спелости")
    culture_name = match_value(text, "Культура")
    purpose = match_value(text, "Назначение кукурузы") or match_value(text, "Назначение")
    cultivation = match_value(text, "Технология возделывания")
    admission_regions = match_value(text, "Регионы допуска")
    adaptation_regions = match_value(text, "Регионы адаптации")
    registration_code = match_value(text, "Регистрациолнный код")
    note = match_value(text, "Примечания")
    starch_match = re.search(r"Содержание крахмала(?: в зерне)?:\s*до\s*(\d+)%", text, flags=re.I)
    oil_match = re.search(r"Содержание масла\s*\|\s*star", text, flags=re.I)
    intro = None
    if "Основная информация" in text:
        intro_match = re.search(r"Основная информация\s+(.+?)(?:Документы|Свойства|Подпишитесь на рассылку|$)", text, flags=re.S)
        if intro_match:
            intro = re.sub(r"\s+", " ", intro_match.group(1)).strip()

    return {
        "crop_code": meta["crop_code"],
        "product_type": meta["product_type"],
        "name": title,
        "maturity_label": maturity_label,
        "fao": int(fao_match.group(1)) if fao_match else None,
        "starch_pct": float(starch_match.group(1)) if starch_match else None,
        "oil_pct": None if not oil_match else None,
        "payload": {
            "provider": "Syngenta",
            "season_year": 2025,
            "updated_at_raw": updated_at,
            "culture_name": culture_name,
            "purpose": purpose,
            "cultivation_technology": cultivation,
            "admission_regions": admission_regions,
            "adaptation_regions": adaptation_regions,
            "registration_code": registration_code,
            "note": note,
            "intro": intro,
            "raw_text": text,
        },
        "source_url": meta["source_url"],
    }


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    loaded_sources = 0
    loaded_traits = 0
    skipped_sources: list[dict[str, str]] = []
    with Session(engine) as db:
        for meta in SYNGENTA_2025_PRODUCT_SOURCES:
            try:
                trait = parse_syngenta_product(meta)
            except HTTPError as exc:
                skipped_sources.append({"code": meta["code"], "url": meta["source_url"], "error": str(exc)})
                print(f"[hybrids] skipped {meta['code']}: {exc}")
                continue
            source_id = upsert_source(
                db,
                code=meta["code"],
                provider="Syngenta",
                source_type="product_page",
                name=trait["name"],
                source_url=meta["source_url"],
                crop_code=meta["crop_code"],
                season_year=2025,
            )
            variety_id = upsert_variety(
                db,
                crop_code=trait["crop_code"],
                product_type=trait["product_type"],
                name_raw=trait["name"],
                manufacturer_norm="Syngenta",
            )
            upsert_trait_snapshot(
                db,
                variety_id=variety_id,
                source_id=source_id,
                crop_code=trait["crop_code"],
                maturity_label=trait["maturity_label"],
                fao=trait["fao"],
                standard_moisture_pct=14.0 if trait["crop_code"] == "corn" else 7.0,
                protein_pct=None,
                oil_pct=trait["oil_pct"],
                starch_pct=trait["starch_pct"],
                yield_min_c_ha=None,
                yield_max_c_ha=None,
                payload=trait["payload"],
                source_url=trait["source_url"],
            )
            db.commit()
            loaded_sources += 1
            loaded_traits += 1
            print(f"[hybrids] loaded {meta['code']} -> {trait['name']}")

        summary = db.execute(
            text(
                """
                select
                    count(*) filter (where season_year = 2025 and provider = 'Syngenta') as syngenta_2025_sources,
                    count(*) filter (where provider = 'Syngenta') as syngenta_sources_total
                from hybrids.sources
                """
            )
        ).mappings().one()
        trait_summary = db.execute(
            text(
                """
                select
                    count(*) as trait_rows_2025
                from hybrids.trait_snapshots ts
                join hybrids.sources s on s.id = ts.source_id
                where s.provider = 'Syngenta' and s.season_year = 2025
                """
            )
        ).mappings().one()
        print(
            "[hybrids] append summary",
            {
                "loaded_sources": loaded_sources,
                "loaded_traits": loaded_traits,
                "skipped_sources": skipped_sources,
                **dict(summary),
                **dict(trait_summary),
            },
        )


if __name__ == "__main__":
    main()
