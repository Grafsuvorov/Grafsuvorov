#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from statistics import mean, pstdev
from typing import Any

import requests
from bs4 import BeautifulSoup
from pypdf import PdfReader
from sqlalchemy import create_engine, delete, func, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from api.core.config import settings  # noqa: E402
from api.models import (  # noqa: E402
    Base,
    HybridSource,
    HybridTraitSnapshot,
    HybridTrialResult,
    HybridTrialSummary,
    HybridVariety,
)


MONTH_RE = r"(?:янв|фев|мар|апр|май|июн|июл|авг|сен|окт|ноя|дек)"
TRIAL_ROW_RE = re.compile(
    rf"^(?P<location>.+?)\s+(?P<sowing>\d{{1,2}}\s+{MONTH_RE})\s+(?P<harvest>\d{{1,2}}\s+{MONTH_RE})\s+"
    r"(?P<density>\d{1,3})\s+(?P<moisture>\d{1,2},\d)\s+(?P<yield>\d{1,3},\d)\s*$",
    re.IGNORECASE,
)
YEAR_HEADER_RE = re.compile(r"Урожайность гибрида в сезоне (\d{4}) года", re.IGNORECASE)
VALUE_RE = re.compile(r"^\s*([^:]+):\s*(.+?)\s*$")
PDF_SOURCES = [
    {
        "code": "SYN_PDF_2022_CENTER",
        "provider": "Syngenta",
        "source_type": "trial_pdf",
        "name": "Syngenta crop yield 2022 center",
        "source_url": "https://www.syngenta.ru/upload/pdf/crop_yield_2022_center.pdf",
        "macro_region": "CENTER",
    },
    {
        "code": "SYN_PDF_2022_SOUTH",
        "provider": "Syngenta",
        "source_type": "trial_pdf",
        "name": "Syngenta crop yield 2022 south",
        "source_url": "https://www.syngenta.ru/upload/pdf/crop_yield_2022_south.pdf",
        "macro_region": "SOUTH",
    },
    {
        "code": "SYN_PDF_2023_CENTER",
        "provider": "Syngenta",
        "source_type": "trial_pdf",
        "name": "Syngenta crop yield 2023 center",
        "source_url": "https://www.syngenta.ru/upload/pdf/crop_yield_2023_centre.pdf",
        "macro_region": "CENTER",
    },
    {
        "code": "SYN_PDF_2023_SOUTH",
        "provider": "Syngenta",
        "source_type": "trial_pdf",
        "name": "Syngenta crop yield 2023 south",
        "source_url": "https://www.syngenta.ru/upload/pdf/crop_yield_2023_south.pdf",
        "macro_region": "SOUTH",
    },
    {
        "code": "SYN_PDF_2024_CENTER",
        "provider": "Syngenta",
        "source_type": "trial_pdf",
        "name": "Syngenta crop yield 2024 center",
        "source_url": "https://www.syngenta.ru/upload/pdf/urozhaynost_centr_2024.pdf",
        "macro_region": "CENTER",
    },
    {
        "code": "SYN_PDF_2024_SOUTH",
        "provider": "Syngenta",
        "source_type": "trial_pdf",
        "name": "Syngenta crop yield 2024 south",
        "source_url": "https://www.syngenta.ru/upload/pdf/urozhaynost_yug_2024.pdf",
        "macro_region": "SOUTH",
    },
]

LIDEA_PRODUCT_SOURCES = [
    {"code": "LIDEA_CORN_CLORIFI", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/clorifi"},
    {"code": "LIDEA_CORN_EPILOG", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/epilog"},
    {"code": "LIDEA_CORN_MILEDI", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/miledi"},
    {"code": "LIDEA_CORN_CIRRIUS", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/cirrius"},
    {"code": "LIDEA_CORN_METHOD", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/method"},
    {"code": "LIDEA_CORN_FARADEY", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/faradey"},
    {"code": "LIDEA_CORN_SPICY", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/spicy"},
    {"code": "LIDEA_CORN_CREATIVE", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/creative"},
    {"code": "LIDEA_CORN_BOND", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/bond"},
    {"code": "LIDEA_CORN_CONSTELLATION", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/constellation"},
    {"code": "LIDEA_CORN_KATAMARAN", "crop_code": "corn", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/katamaran"},
    {"code": "LIDEA_SUN_BELFIS", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/belfis"},
    {"code": "LIDEA_SUN_BALISTIK", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/balistik"},
    {"code": "LIDEA_SUN_OAZIS", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/oazis"},
    {"code": "LIDEA_SUN_ARCADIA", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/arcadia"},
    {"code": "LIDEA_SUN_IZIDA", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/izida"},
    {"code": "LIDEA_SUN_SAVANA", "crop_code": "sunflower", "product_type": "hybrid", "source_url": "https://lidea-seeds.ru/products/savana"},
    {"code": "LIDEA_SOY_KOMANDOR", "crop_code": "soy", "product_type": "variety", "source_url": "https://lidea-seeds.ru/products/komandor"},
    {"code": "LIDEA_SOY_FAVOR", "crop_code": "soy", "product_type": "variety", "source_url": "https://lidea-seeds.ru/products/favor"},
    {"code": "LIDEA_SOY_COMPOZITOR", "crop_code": "soy", "product_type": "variety", "source_url": "https://lidea-seeds.ru/products/compozitor"},
]

LIDEA_ARTICLE_SOURCES = [
    {
        "code": "LIDEA_SOY_RESULTS_2024",
        "crop_code": "soy",
        "product_type": "variety",
        "season_year": 2024,
        "source_url": "https://lidea-seeds.ru/news/blog/soy-leaders",
    }
]

SUBJECT_PREFIX_MAP = {
    "Адыгея": "Республика Адыгея",
    "Белгородская": "Белгородская область",
    "Брянская": "Брянская область",
    "Воронежская": "Воронежская область",
    "Кабардино-Балкария": "Кабардино-Балкарская Республика",
    "Карачаево-Черкесия": "Карачаево-Черкесская Республика",
    "Курская": "Курская область",
    "Липецкая": "Липецкая область",
    "Мордовия": "Республика Мордовия",
    "Московская": "Московская область",
    "Орловская": "Орловская область",
    "Пензенская": "Пензенская область",
    "Ростовская": "Ростовская область",
    "Рязанская": "Рязанская область",
    "Северная Осетия – Алания": "Республика Северная Осетия — Алания",
    "Северная Осетия-Алания": "Республика Северная Осетия — Алания",
    "Ставропольский": "Ставропольский край",
    "Тамбовская": "Тамбовская область",
    "Чечня": "Чеченская Республика",
    "Краснодарский": "Краснодарский край",
    "Волгоградская": "Волгоградская область",
    "Саратовская": "Саратовская область",
}
SUBJECT_PREFIXES = sorted(SUBJECT_PREFIX_MAP.keys(), key=len, reverse=True)


def normalize_database_url(url: str) -> str:
    return url.replace("host.docker.internal", "127.0.0.1")


def q(value: Any, scale: str) -> Decimal | None:
    if value is None:
        return None
    return Decimal(str(value)).quantize(Decimal(scale), rounding=ROUND_HALF_UP)


def clean_text(value: str) -> str:
    value = value.replace("\xa0", " ")
    value = value.replace("–", "-")
    value = re.sub(r"\b([А-ЯЁ])\s+([а-яё])", r"\1\2", value)
    value = re.sub(r"[ \t]+", " ", value)
    return value.strip()


def normalize_name(name: str) -> str:
    name = clean_text(name)
    name = re.sub(r"\s+New!?$", "", name, flags=re.IGNORECASE)
    return name.upper().replace("  ", " ").strip()


def http_get(url: str) -> requests.Response:
    response = requests.get(url, timeout=120)
    response.raise_for_status()
    return response


def ensure_schema(engine) -> None:
    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS hybrids"))


def ensure_metadata(engine) -> None:
    ensure_schema(engine)
    Base.metadata.create_all(bind=engine)


def clear_existing_data(db: Session) -> None:
    db.execute(delete(HybridTrialSummary))
    db.execute(delete(HybridTrialResult))
    db.execute(delete(HybridTraitSnapshot))
    db.execute(delete(HybridVariety))
    db.execute(delete(HybridSource))
    db.commit()


def upsert_source(db: Session, *, code: str, provider: str, source_type: str, name: str, source_url: str, crop_code: str | None = None, season_year: int | None = None, macro_region: str | None = None) -> int:
    stmt = insert(HybridSource).values(
        code=code,
        provider=provider,
        source_type=source_type,
        name=name,
        source_url=source_url,
        crop_code=crop_code,
        season_year=season_year,
        macro_region=macro_region,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=[HybridSource.code],
        set_={
            "provider": stmt.excluded.provider,
            "source_type": stmt.excluded.source_type,
            "name": stmt.excluded.name,
            "source_url": stmt.excluded.source_url,
            "crop_code": stmt.excluded.crop_code,
            "season_year": stmt.excluded.season_year,
            "macro_region": stmt.excluded.macro_region,
            "updated_at": func.now(),
        },
    ).returning(HybridSource.id)
    return db.execute(stmt).scalar_one()


def upsert_variety(db: Session, *, crop_code: str, product_type: str, name_raw: str, manufacturer_norm: str) -> int:
    name_norm = normalize_name(name_raw)
    stmt = insert(HybridVariety).values(
        crop_code=crop_code,
        product_type=product_type,
        name_raw=name_raw,
        name_norm=name_norm,
        manufacturer_norm=manufacturer_norm,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_hybrids_variety_crop_name_mfr",
        set_={
            "product_type": stmt.excluded.product_type,
            "name_raw": stmt.excluded.name_raw,
            "updated_at": func.now(),
        },
    ).returning(HybridVariety.id)
    return db.execute(stmt).scalar_one()


def extract_hybrid_name_from_page(text: str) -> str | None:
    for line in [clean_text(x) for x in text.splitlines()]:
        if not line:
            continue
        if line in {
            "ХИТ",
            "СЕЗОНА",
            "Орошение",
            "Республика,",
            "Область Район Дата",
            "Край, область Район Дата",
            "Республика, край, область Район Дата",
            "Край, область Район, город Дата",
            "Республика, край, область Район, город Дата",
        }:
            continue
        if line.startswith(("•", "Урожайность", "Гибриды ", "Регион ", "ФАО ", "Направления использования", "Толерантность")):
            continue
        if re.match(r"^\d+\s*\|", line):
            continue
        if re.match(r"^(?:край|область|республика)[ ,].*Район", line, flags=re.IGNORECASE):
            continue
        if len(line) <= 12 and line == line.upper():
            continue
        if len(line) > 2 and not line.isdigit():
            return re.sub(r"\s+New!?$", "", line).strip()
    return None


def split_location(raw_location: str) -> tuple[str | None, str | None]:
    raw_location = clean_text(raw_location)
    for prefix in SUBJECT_PREFIXES:
        if raw_location.startswith(prefix + " "):
            return SUBJECT_PREFIX_MAP[prefix], raw_location[len(prefix) + 1 :].strip()
        if raw_location == prefix:
            return SUBJECT_PREFIX_MAP[prefix], None
    return None, raw_location


def parse_decimal(value: str) -> float:
    return float(value.replace(",", "."))


def build_trial_hash(payload: dict[str, Any]) -> str:
    ordered = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(ordered.encode("utf-8")).hexdigest()


def parse_syngenta_trials(source_meta: dict[str, Any]) -> list[dict[str, Any]]:
    pdf_path = Path("/tmp") / f"{source_meta['code'].lower()}.pdf"
    if not pdf_path.exists() or pdf_path.stat().st_size == 0:
        pdf_path.write_bytes(http_get(source_meta["source_url"]).content)
    reader = PdfReader(str(pdf_path))
    rows: list[dict[str, Any]] = []
    current_hybrid_name: str | None = None

    for page_idx, page in enumerate(reader.pages, start=1):
        text = page.extract_text() or ""
        page_hybrid_name = extract_hybrid_name_from_page(text)
        if page_hybrid_name and page_hybrid_name not in {"Область Район Дата", "Край, область Район Дата", "Республика, край, область Район Дата"}:
            current_hybrid_name = page_hybrid_name
        if "Урожайность гибрида в сезоне" not in text:
            continue

        crop_code = None
        if "(7 %)" in text or "(7,0 %)" in text:
            crop_code = "sunflower"
        elif "(14 %)" in text or "(14,0 %)" in text:
            crop_code = "corn"
        if crop_code is None:
            continue

        standard_moisture_pct = 7.0 if crop_code == "sunflower" else 14.0
        hybrid_name = page_hybrid_name or current_hybrid_name
        if not hybrid_name:
            continue

        current_year: int | None = None
        page_has_2024 = "Урожайность гибрида в сезоне 2024 года" in text
        page_has_2023 = "Урожайность гибрида в сезоне 2023 года" in text
        if source_meta["code"].endswith("2024_CENTER") or source_meta["code"].endswith("2024_SOUTH"):
            if page_has_2024:
                current_year = 2024
        seen_data = False

        for raw_line in text.splitlines():
            line = clean_text(raw_line)
            if not line:
                continue
            year_match = YEAR_HEADER_RE.search(line)
            if year_match:
                if page_has_2024 and page_has_2023:
                    continue
                current_year = int(year_match.group(1))
                continue

            if (
                seen_data
                and page_has_2024
                and page_has_2023
                and line.startswith(("Область", "Край, область", "Республика,", "Республика, край, область"))
            ):
                current_year = 2023
                continue
            if current_year is None:
                continue

            row_match = TRIAL_ROW_RE.match(line)
            if not row_match:
                continue
            seen_data = True

            location_raw = row_match.group("location")
            subject_rf, district = split_location(location_raw)
            payload = {
                "provider": source_meta["provider"],
                "source_code": source_meta["code"],
                "crop_code": crop_code,
                "season_year": current_year,
                "macro_region": source_meta["macro_region"],
                "variety_name": hybrid_name,
                "subject_rf": subject_rf,
                "district": district,
                "sowing_date_raw": row_match.group("sowing"),
                "harvest_date_raw": row_match.group("harvest"),
                "plant_density_ths_per_ha": parse_decimal(row_match.group("density")),
                "harvest_moisture_pct": parse_decimal(row_match.group("moisture")),
                "standard_moisture_pct": standard_moisture_pct,
                "yield_standard_c_ha": parse_decimal(row_match.group("yield")),
                "source_url": source_meta["source_url"],
                "source_page": page_idx,
                "raw_text": line,
            }
            payload["record_hash"] = build_trial_hash(payload)
            rows.append(payload)
    return rows


def fetch_soup(url: str) -> BeautifulSoup:
    return BeautifulSoup(http_get(url).text, "lxml")


def page_text(url: str) -> str:
    soup = fetch_soup(url)
    return "\n".join(line.strip() for line in soup.get_text("\n").splitlines() if line.strip())


def parse_lidea_product(source_meta: dict[str, Any]) -> dict[str, Any]:
    soup = fetch_soup(source_meta["source_url"])
    text = "\n".join(line.strip() for line in soup.get_text("\n").splitlines() if line.strip())
    lines = [line for line in text.splitlines() if line]
    title = soup.title.get_text(strip=True) if soup.title else lines[0]
    title = re.sub(r"^Lidea\s*-\s*", "", title).strip()
    title = re.sub(r"\s+", " ", title)
    name = title
    payload: dict[str, Any] = {
        "raw_text": text,
        "advantages": [],
        "characteristics": {},
        "recommendations": {},
        "agronomic_profile": {},
        "disease_tolerance": {},
        "nutritional_value": {},
    }

    current_block = None
    for line in lines:
        if line in {
            "ПРЕИМУЩЕСТВА",
            "ХАРАКТЕРИСТИКИ",
            "РЕКОМЕНДАЦИИ",
            "АГРОНОМИЧЕСКИЙ ПРОФИЛЬ",
            "ТОЛЕРАНТНОСТЬ К БОЛЕЗНЯМ",
            "ПИТАТЕЛЬНАЯ ЦЕННОСТЬ",
            "КАЧЕСТВЕННЫЕ ХАРАКТЕРИСТИКИ",
            "УСТОЙЧИВОСТЬ К ГЕРБИЦИДАМ",
            "ЗАРАЗИХОУСТОЙЧИВОСТЬ",
        }:
            current_block = line
            continue
        if line.startswith("НА ГЛАВНУЮ"):
            break
        value_match = VALUE_RE.match(line)
        if current_block == "ПРЕИМУЩЕСТВА":
            payload["advantages"].append(line)
        elif current_block == "ХАРАКТЕРИСТИКИ" and value_match:
            payload["characteristics"][value_match.group(1).strip()] = value_match.group(2).strip()
        elif current_block == "РЕКОМЕНДАЦИИ" and value_match:
            payload["recommendations"][value_match.group(1).strip()] = value_match.group(2).strip()
        elif current_block == "АГРОНОМИЧЕСКИЙ ПРОФИЛЬ" and value_match:
            payload["agronomic_profile"][value_match.group(1).strip()] = value_match.group(2).strip()
        elif current_block == "ТОЛЕРАНТНОСТЬ К БОЛЕЗНЯМ" and value_match:
            payload["disease_tolerance"][value_match.group(1).strip()] = value_match.group(2).strip()
        elif current_block in {"ПИТАТЕЛЬНАЯ ЦЕННОСТЬ", "КАЧЕСТВЕННЫЕ ХАРАКТЕРИСТИКИ"} and value_match:
            payload["nutritional_value"][value_match.group(1).strip()] = value_match.group(2).strip()
        elif current_block in {"УСТОЙЧИВОСТЬ К ГЕРБИЦИДАМ", "ЗАРАЗИХОУСТОЙЧИВОСТЬ"} and value_match:
            payload.setdefault("special_tolerance", {})[value_match.group(1).strip()] = value_match.group(2).strip()

    fao_match = re.search(r"ФАО\s*(\d+)", text, flags=re.IGNORECASE)
    protein_match = re.search(r"Содержание белка:\s*(\d+[.,]\d+)", text, flags=re.IGNORECASE)
    oil_match = re.search(r"(?:Содержание масла|Масличность)\s*:?\s*(\d+[.,]\d+)(?:[-/](\d+[.,]\d+))?", text, flags=re.IGNORECASE)
    maturity_match = re.search(r"(Ранний сорт.*?|Среднеранний гибрид|Среднеспелый гибрид|Ранний|Среднеранний|Среднеспелый гибрид|Среднеранний сорт.*?|Среднеранний гибрид)", text, flags=re.IGNORECASE)

    oil_value = None
    if oil_match:
        oil_value = parse_decimal(oil_match.group(1))
        if oil_match.group(2):
            oil_value = (oil_value + parse_decimal(oil_match.group(2))) / 2

    return {
        "crop_code": source_meta["crop_code"],
        "product_type": source_meta["product_type"],
        "name": clean_text(name),
        "maturity_label": maturity_match.group(1) if maturity_match else None,
        "fao": int(fao_match.group(1)) if fao_match else None,
        "protein_pct": parse_decimal(protein_match.group(1)) if protein_match else None,
        "oil_pct": oil_value,
        "payload": payload,
        "source_url": source_meta["source_url"],
    }


def parse_lidea_soy_article(source_meta: dict[str, Any]) -> list[dict[str, Any]]:
    text = page_text(source_meta["source_url"])
    rows = []
    for variety_name, protein_pct, oil_pct in [
        ("Командор", 41.5, 19.5),
        ("Фавор", 40.3, 21.4),
    ]:
        yield_match = None
        if variety_name == "Командор":
            yield_match = re.search(r"У Командора значения варьируются от (\d+[.,]\d+) ц/га до (\d+[.,]\d+) ц/га", text)
        elif variety_name == "Фавора" or variety_name == "Фавор":
            yield_match = re.search(r"у Фавора - от (\d+[.,]\d+) ц/га до (\d+[.,]\d+) ц/га", text, flags=re.IGNORECASE)
        if yield_match is None and variety_name == "Фавор":
            yield_match = re.search(r"у Фавора\s*-\s*от (\d+[.,]\d+) ц/га до (\d+[.,]\d+) ц/га", text, flags=re.IGNORECASE)

        rows.append(
            {
                "crop_code": "soy",
                "product_type": "variety",
                "name": variety_name,
                "maturity_label": "Ранний сорт (начало группы 000)",
                "protein_pct": protein_pct,
                "oil_pct": oil_pct,
                "yield_min_c_ha": parse_decimal(yield_match.group(1)) if yield_match else None,
                "yield_max_c_ha": parse_decimal(yield_match.group(2)) if yield_match else None,
                "payload": {
                    "article_text": text,
                    "standard_moisture_pct": 12.0,
                    "season_year": source_meta["season_year"],
                    "source_note": "Диапазон урожайности по областям ЦФО из статьи Lidea.",
                },
                "source_url": source_meta["source_url"],
            }
        )
    return rows


def upsert_trait_snapshot(db: Session, *, variety_id: int, source_id: int, crop_code: str, maturity_label: str | None, fao: int | None, standard_moisture_pct: float | None, protein_pct: float | None, oil_pct: float | None, starch_pct: float | None, yield_min_c_ha: float | None, yield_max_c_ha: float | None, payload: dict[str, Any], source_url: str) -> None:
    stmt = insert(HybridTraitSnapshot).values(
        variety_id=variety_id,
        source_id=source_id,
        crop_code=crop_code,
        maturity_label=maturity_label,
        fao=fao,
        standard_moisture_pct=q(standard_moisture_pct, "0.01"),
        protein_pct=q(protein_pct, "0.01"),
        oil_pct=q(oil_pct, "0.01"),
        starch_pct=q(starch_pct, "0.01"),
        yield_min_c_ha=q(yield_min_c_ha, "0.01"),
        yield_max_c_ha=q(yield_max_c_ha, "0.01"),
        payload=payload,
        source_url=source_url,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_hybrids_trait_variety_source",
        set_={
            "maturity_label": stmt.excluded.maturity_label,
            "fao": stmt.excluded.fao,
            "standard_moisture_pct": stmt.excluded.standard_moisture_pct,
            "protein_pct": stmt.excluded.protein_pct,
            "oil_pct": stmt.excluded.oil_pct,
            "starch_pct": stmt.excluded.starch_pct,
            "yield_min_c_ha": stmt.excluded.yield_min_c_ha,
            "yield_max_c_ha": stmt.excluded.yield_max_c_ha,
            "payload": stmt.excluded.payload,
            "source_url": stmt.excluded.source_url,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def upsert_trial_result(db: Session, row: dict[str, Any], source_id: int, variety_id: int) -> None:
    payload = {"provider": row["provider"], "source_code": row["source_code"]}
    extra_payload = row.get("payload")
    if isinstance(extra_payload, dict):
        payload.update(extra_payload)
    stmt = insert(HybridTrialResult).values(
        variety_id=variety_id,
        source_id=source_id,
        crop_code=row["crop_code"],
        season_year=row["season_year"],
        macro_region=row["macro_region"],
        subject_rf=row["subject_rf"],
        district=row["district"],
        sowing_date_raw=row["sowing_date_raw"],
        harvest_date_raw=row["harvest_date_raw"],
        plant_density_ths_per_ha=q(row["plant_density_ths_per_ha"], "0.01"),
        harvest_moisture_pct=q(row["harvest_moisture_pct"], "0.01"),
        standard_moisture_pct=q(row["standard_moisture_pct"], "0.01"),
        yield_standard_c_ha=q(row["yield_standard_c_ha"], "0.01"),
        yield_standard_t_ha=q(row["yield_standard_c_ha"] / 10.0, "0.001"),
        record_hash=row["record_hash"],
        source_url=row["source_url"],
        source_page=row["source_page"],
        raw_text=row["raw_text"],
        payload=payload,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_hybrids_trial_record_hash",
        set_={
            "variety_id": stmt.excluded.variety_id,
            "source_id": stmt.excluded.source_id,
            "crop_code": stmt.excluded.crop_code,
            "season_year": stmt.excluded.season_year,
            "macro_region": stmt.excluded.macro_region,
            "subject_rf": stmt.excluded.subject_rf,
            "district": stmt.excluded.district,
            "sowing_date_raw": stmt.excluded.sowing_date_raw,
            "harvest_date_raw": stmt.excluded.harvest_date_raw,
            "plant_density_ths_per_ha": stmt.excluded.plant_density_ths_per_ha,
            "harvest_moisture_pct": stmt.excluded.harvest_moisture_pct,
            "standard_moisture_pct": stmt.excluded.standard_moisture_pct,
            "yield_standard_c_ha": stmt.excluded.yield_standard_c_ha,
            "yield_standard_t_ha": stmt.excluded.yield_standard_t_ha,
            "source_url": stmt.excluded.source_url,
            "source_page": stmt.excluded.source_page,
            "raw_text": stmt.excluded.raw_text,
            "payload": stmt.excluded.payload,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def rebuild_summaries(db: Session) -> None:
    db.execute(delete(HybridTrialSummary))
    rows = (
        db.query(
            HybridTrialResult.variety_id,
            HybridTrialResult.crop_code,
            HybridTrialResult.season_year,
            HybridTrialResult.macro_region,
            func.array_agg(func.distinct(HybridSource.code)),
        )
        .join(HybridSource, HybridSource.id == HybridTrialResult.source_id)
        .group_by(
            HybridTrialResult.variety_id,
            HybridTrialResult.crop_code,
            HybridTrialResult.season_year,
            HybridTrialResult.macro_region,
        )
        .all()
    )
    for row in rows:
        trial_rows = (
            db.query(HybridTrialResult)
            .filter(
                HybridTrialResult.variety_id == row[0],
                HybridTrialResult.crop_code == row[1],
                HybridTrialResult.season_year == row[2],
                HybridTrialResult.macro_region == row[3],
            )
            .all()
        )
        yields = [float(item.yield_standard_c_ha) for item in trial_rows]
        moistures = [float(item.harvest_moisture_pct) for item in trial_rows if item.harvest_moisture_pct is not None]
        cv_yield = None
        if len(yields) > 1 and mean(yields) != 0:
            cv_yield = pstdev(yields) / mean(yields) * 100.0
        db.add(
            HybridTrialSummary(
                variety_id=row[0],
                crop_code=row[1],
                season_year=row[2],
                macro_region=row[3],
                trials_count=len(trial_rows),
                avg_yield_c_ha=q(mean(yields), "0.01"),
                min_yield_c_ha=q(min(yields), "0.01"),
                max_yield_c_ha=q(max(yields), "0.01"),
                avg_harvest_moisture_pct=q(mean(moistures), "0.01") if moistures else None,
                cv_yield_pct=q(cv_yield, "0.01") if cv_yield is not None else None,
                source_codes=list(row[4]),
            )
        )
    db.commit()


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    with Session(engine) as db:
        clear_existing_data(db)

        for meta in PDF_SOURCES:
            source_id = upsert_source(db, **meta)
            trial_rows = parse_syngenta_trials(meta)
            for row in trial_rows:
                variety_id = upsert_variety(
                    db,
                    crop_code=row["crop_code"],
                    product_type="hybrid",
                    name_raw=row["variety_name"],
                    manufacturer_norm="Syngenta",
                )
                upsert_trial_result(db, row, source_id, variety_id)
            db.commit()
            print(f"[hybrids] loaded trials from {meta['code']}: {len(trial_rows)}")

        for meta in LIDEA_PRODUCT_SOURCES:
            source_id = upsert_source(
                db,
                code=meta["code"],
                provider="Lidea",
                source_type="product_page",
                name=meta["code"],
                source_url=meta["source_url"],
                crop_code=meta["crop_code"],
            )
            trait = parse_lidea_product(meta)
            variety_id = upsert_variety(
                db,
                crop_code=trait["crop_code"],
                product_type=trait["product_type"],
                name_raw=trait["name"],
                manufacturer_norm="Lidea",
            )
            upsert_trait_snapshot(
                db,
                variety_id=variety_id,
                source_id=source_id,
                crop_code=trait["crop_code"],
                maturity_label=trait["maturity_label"],
                fao=trait["fao"],
                standard_moisture_pct=12.0 if trait["crop_code"] == "soy" else None,
                protein_pct=trait["protein_pct"],
                oil_pct=trait["oil_pct"],
                starch_pct=None,
                yield_min_c_ha=None,
                yield_max_c_ha=None,
                payload=trait["payload"],
                source_url=trait["source_url"],
            )
            db.commit()
            print(f"[hybrids] loaded trait page {meta['code']}")

        for meta in LIDEA_ARTICLE_SOURCES:
            source_id = upsert_source(
                db,
                code=meta["code"],
                provider="Lidea",
                source_type="article",
                name=meta["code"],
                source_url=meta["source_url"],
                crop_code=meta["crop_code"],
                season_year=meta["season_year"],
            )
            for claim in parse_lidea_soy_article(meta):
                variety_id = upsert_variety(
                    db,
                    crop_code=claim["crop_code"],
                    product_type=claim["product_type"],
                    name_raw=claim["name"],
                    manufacturer_norm="Lidea",
                )
                upsert_trait_snapshot(
                    db,
                    variety_id=variety_id,
                    source_id=source_id,
                    crop_code=claim["crop_code"],
                    maturity_label=claim["maturity_label"],
                    fao=None,
                    standard_moisture_pct=12.0,
                    protein_pct=claim["protein_pct"],
                    oil_pct=claim["oil_pct"],
                    starch_pct=None,
                    yield_min_c_ha=claim["yield_min_c_ha"],
                    yield_max_c_ha=claim["yield_max_c_ha"],
                    payload=claim["payload"],
                    source_url=claim["source_url"],
                )
            db.commit()
            print(f"[hybrids] loaded article claims {meta['code']}")

        rebuild_summaries(db)
        summary = db.execute(
            text(
                """
                select
                    (select count(*) from hybrids.varieties) as varieties,
                    (select count(*) from hybrids.sources) as sources,
                    (select count(*) from hybrids.trait_snapshots) as trait_snapshots,
                    (select count(*) from hybrids.trial_results) as trial_results,
                    (select count(*) from hybrids.trial_summaries) as trial_summaries
                """
            )
        ).mappings().one()
        print("[hybrids] summary", dict(summary))


if __name__ == "__main__":
    main()
