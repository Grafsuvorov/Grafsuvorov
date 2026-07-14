#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from pathlib import Path

from sqlalchemy import create_engine, func
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from api.core.config import settings  # noqa: E402
from api.models import Base, HybridGeoLocation, HybridMacroRegion  # noqa: E402


MACRO_REGIONS = [
    {"code": "NORTH_CAUCASUS", "registry_number": 6, "name": "Северо-Кавказский регион"},
    {"code": "MIDDLE_VOLGA", "registry_number": 7, "name": "Средневолжский регион"},
    {"code": "NORTH_WEST", "registry_number": 2, "name": "Северо-Западный регион"},
    {"code": "CENTRAL", "registry_number": 3, "name": "Центральный регион"},
    {"code": "CENTRAL_BLACK_EARTH", "registry_number": 5, "name": "Центрально-Черноземный регион"},
    {"code": "VOLGA_VYATKA", "registry_number": 4, "name": "Волго-Вятский регион"},
    {"code": "LOWER_VOLGA", "registry_number": 8, "name": "Нижневолжский регион"},
    {"code": "WEST_SIBERIA", "registry_number": 10, "name": "Западно-Сибирский регион"},
    {"code": "URAL", "registry_number": 9, "name": "Уральский регион"},
]


LOCATIONS = [
    {
        "name": "Корочанский",
        "normalized_name": "КОРОЧАНСКИЙ",
        "location_type": "district",
        "subject_rf": "Белгородская область",
        "district": "Корочанский район",
        "settlement_name": None,
        "macro_region_code": "CENTRAL_BLACK_EARTH",
    },
    {
        "name": "Новокубанский",
        "normalized_name": "НОВОКУБАНСКИЙ",
        "location_type": "district",
        "subject_rf": "Краснодарский край",
        "district": "Новокубанский район",
        "settlement_name": "г. Новокубанск",
        "macro_region_code": "NORTH_CAUCASUS",
    },
    {
        "name": "Железногорский",
        "normalized_name": "ЖЕЛЕЗНОГОРСКИЙ",
        "location_type": "district",
        "subject_rf": "Курская область",
        "district": "Железногорский район",
        "settlement_name": "г. Железногорск",
        "macro_region_code": "CENTRAL",
        "notes": "Требует проверки, если нужен другой субъект РФ.",
    },
    {
        "name": "Инсарский",
        "normalized_name": "ИНСАРСКИЙ",
        "location_type": "district",
        "subject_rf": "Республика Мордовия",
        "district": "Инсарский район",
        "settlement_name": "г. Инсар",
        "macro_region_code": "MIDDLE_VOLGA",
    },
    {
        "name": "Дальнеконстантиновский",
        "normalized_name": "ДАЛЬНЕКОНСТАНТИНОВСКИЙ",
        "location_type": "district",
        "subject_rf": "Нижегородская область",
        "district": "Дальнеконстантиновский район",
        "settlement_name": "р.п. Дальнее Константиново",
        "macro_region_code": "VOLGA_VYATKA",
    },
    {
        "name": "Норовчатский",
        "normalized_name": "НОРОВЧАТСКИЙ",
        "location_type": "district",
        "subject_rf": "Пензенская область",
        "district": "Норовчатский район",
        "settlement_name": "с. Наровчат",
        "macro_region_code": "MIDDLE_VOLGA",
    },
    {
        "name": "Бутурлинский",
        "normalized_name": "БУТУРЛИНСКИЙ",
        "location_type": "district",
        "subject_rf": "Нижегородская область",
        "district": "Бутурлинский муниципальный округ",
        "settlement_name": "р.п. Бутурлино",
        "macro_region_code": "VOLGA_VYATKA",
    },
    {
        "name": "Армавир",
        "normalized_name": "АРМАВИР",
        "location_type": "city",
        "subject_rf": "Краснодарский край",
        "district": None,
        "settlement_name": "г. Армавир",
        "macro_region_code": "NORTH_CAUCASUS",
    },
    {
        "name": "Сармановский",
        "normalized_name": "САРМАНОВСКИЙ",
        "location_type": "district",
        "subject_rf": "Республика Татарстан",
        "district": "Сармановский район",
        "settlement_name": "с. Сарманово",
        "macro_region_code": "MIDDLE_VOLGA",
    },
    {
        "name": "Кинельский",
        "normalized_name": "КИНЕЛЬСКИЙ",
        "location_type": "district",
        "subject_rf": "Самарская область",
        "district": "Кинельский район",
        "settlement_name": "г. Кинель",
        "macro_region_code": "MIDDLE_VOLGA",
    },
    {
        "name": "н/д.",
        "normalized_name": "НД",
        "location_type": "unknown",
        "subject_rf": None,
        "district": None,
        "settlement_name": None,
        "macro_region_code": None,
        "status": "unknown",
        "notes": "Локация не указана.",
    },
    {
        "name": "Муслюмовский",
        "normalized_name": "МУСЛЮМОВСКИЙ",
        "location_type": "district",
        "subject_rf": "Республика Татарстан",
        "district": "Муслюмовский район",
        "settlement_name": "с. Муслюмово",
        "macro_region_code": "MIDDLE_VOLGA",
    },
    {
        "name": "Атяшевский",
        "normalized_name": "АТЯШЕВСКИЙ",
        "location_type": "district",
        "subject_rf": "Республика Мордовия",
        "district": "Атяшевский район",
        "settlement_name": "п. Атяшево",
        "macro_region_code": "MIDDLE_VOLGA",
    },
    {
        "name": "Починковский",
        "normalized_name": "ПОЧИНКОВСКИЙ",
        "location_type": "district",
        "subject_rf": "Нижегородская область",
        "district": "Починковский муниципальный округ",
        "settlement_name": "с. Починки",
        "macro_region_code": "VOLGA_VYATKA",
    },
    {
        "name": "Выселковский",
        "normalized_name": "ВЫСЕЛКОВСКИЙ",
        "location_type": "district",
        "subject_rf": "Краснодарский край",
        "district": "Выселковский район",
        "settlement_name": "ст. Выселки",
        "macro_region_code": "NORTH_CAUCASUS",
    },
    {
        "name": "Лабинский",
        "normalized_name": "ЛАБИНСКИЙ",
        "location_type": "district",
        "subject_rf": "Краснодарский край",
        "district": "Лабинский район",
        "settlement_name": "г. Лабинск",
        "macro_region_code": "NORTH_CAUCASUS",
    },
]


def normalize_database_url(url: str) -> str:
    return url.replace("host.docker.internal", "127.0.0.1")


def ensure_metadata(engine) -> None:
    Base.metadata.create_all(bind=engine)


def upsert_macro_region(db: Session, payload: dict) -> int:
    stmt = insert(HybridMacroRegion).values(**payload)
    stmt = stmt.on_conflict_do_update(
        index_elements=[HybridMacroRegion.code],
        set_={
            "registry_number": stmt.excluded.registry_number,
            "name": stmt.excluded.name,
            "updated_at": func.now(),
        },
    ).returning(HybridMacroRegion.id)
    return db.execute(stmt).scalar_one()


def upsert_location(db: Session, payload: dict) -> None:
    stmt = insert(HybridGeoLocation).values(**payload)
    stmt = stmt.on_conflict_do_update(
        constraint="uq_hybrids_geo_name_type_subject",
        set_={
            "macro_region_id": stmt.excluded.macro_region_id,
            "normalized_name": stmt.excluded.normalized_name,
            "district": stmt.excluded.district,
            "settlement_name": stmt.excluded.settlement_name,
            "status": stmt.excluded.status,
            "notes": stmt.excluded.notes,
            "payload": stmt.excluded.payload,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    with Session(engine) as db:
        region_ids = {}
        for item in MACRO_REGIONS:
            region_ids[item["code"]] = upsert_macro_region(db, item)

        for item in LOCATIONS:
            payload = {
                "macro_region_id": region_ids.get(item.get("macro_region_code")) if item.get("macro_region_code") else None,
                "name": item["name"],
                "normalized_name": item["normalized_name"],
                "location_type": item["location_type"],
                "subject_rf": item.get("subject_rf"),
                "district": item.get("district"),
                "settlement_name": item.get("settlement_name"),
                "status": item.get("status", "active"),
                "notes": item.get("notes"),
                "payload": {"seeded_from_user_request": True},
            }
            upsert_location(db, payload)
        db.commit()
        print(f"[hybrids] macro_regions={len(MACRO_REGIONS)} geo_locations={len(LOCATIONS)}")


if __name__ == "__main__":
    main()
