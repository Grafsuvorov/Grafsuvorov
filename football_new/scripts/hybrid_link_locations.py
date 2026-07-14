#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

from sqlalchemy import create_engine, delete, func, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from api.core.config import settings  # noqa: E402
from api.models import (  # noqa: E402
    Base,
    HybridGeoLocation,
    HybridMacroRegion,
    HybridTrialGeoLink,
)


SUBJECT_TO_MACRO = {
    "Белгородская область": "CENTRAL_BLACK_EARTH",
    "Брянская область": "CENTRAL",
    "Волгоградская область": "LOWER_VOLGA",
    "Воронежская область": "CENTRAL_BLACK_EARTH",
    "Кабардино-Балкарская Республика": "NORTH_CAUCASUS",
    "Карачаево-Черкесская Республика": "NORTH_CAUCASUS",
    "Краснодарский край": "NORTH_CAUCASUS",
    "Курская область": "CENTRAL",
    "Ивановская область": "CENTRAL",
    "Липецкая область": "CENTRAL_BLACK_EARTH",
    "Московская область": "CENTRAL",
    "Орловская область": "CENTRAL",
    "Пензенская область": "MIDDLE_VOLGA",
    "Ростовская область": "NORTH_CAUCASUS",
    "Республика Адыгея": "NORTH_CAUCASUS",
    "Республика Мордовия": "MIDDLE_VOLGA",
    "Республика Северная Осетия — Алания": "NORTH_CAUCASUS",
    "Рязанская область": "CENTRAL",
    "Ставропольский край": "NORTH_CAUCASUS",
    "Тамбовская область": "CENTRAL_BLACK_EARTH",
    "Чеченская Республика": "NORTH_CAUCASUS",
}


def normalize_database_url(url: str) -> str:
    return url.replace("host.docker.internal", "127.0.0.1")


def ensure_metadata(engine) -> None:
    Base.metadata.create_all(bind=engine)


def normalize_token(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip().replace("ё", "е").replace("Ё", "Е")
    value = re.sub(r"\b(район|муниципальный округ|город|г\.|ст\.|с\.|п\.|р\.п\.)\b", "", value, flags=re.IGNORECASE)
    value = re.sub(r"[-–]", " ", value)
    value = re.sub(r"\s+", " ", value)
    return value.strip().upper() or None


def infer_location_type(district: str | None) -> str:
    if not district:
        return "unknown"
    if district in {"Краснодар", "Армавир"}:
        return "city"
    return "district"


def upsert_location(db: Session, payload: dict) -> int:
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
    ).returning(HybridGeoLocation.id)
    return db.execute(stmt).scalar_one()


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_metadata(engine)

    with Session(engine) as db:
        macro_ids = {
            code: region_id
            for code, region_id in db.execute(text("select code, id from hybrids.macro_regions")).all()
        }

        observed = db.execute(
            text(
                """
                select distinct subject_rf, district
                from hybrids.trial_results
                where subject_rf is not null and district is not null
                order by subject_rf, district
                """
            )
        ).all()

        for subject_rf, district in observed:
            normalized = normalize_token(district)
            macro_code = SUBJECT_TO_MACRO.get(subject_rf)
            payload = {
                "macro_region_id": macro_ids.get(macro_code),
                "name": district,
                "normalized_name": normalized,
                "location_type": infer_location_type(district),
                "subject_rf": subject_rf,
                "district": district,
                "settlement_name": None if infer_location_type(district) == "district" else district,
                "status": "active",
                "notes": "Auto-seeded from hybrids.trial_results",
                "payload": {"auto_seeded_from_trial_results": True},
            }
            upsert_location(db, payload)

        db.commit()

        db.execute(delete(HybridTrialGeoLink))
        db.commit()

        linked_rows = db.execute(
            text(
                """
                with trial_norm as (
                    select
                        r.id as trial_result_id,
                        r.subject_rf,
                        upper(trim(regexp_replace(replace(replace(r.district, 'ё', 'е'), 'Ё', 'Е'),
                            '(район|муниципальный округ|город|г\\.|ст\\.|с\\.|п\\.|р\\.п\\.)', '', 'gi'))) as district_norm
                    from hybrids.trial_results r
                    where r.subject_rf is not null and r.district is not null
                ),
                geo_norm as (
                    select
                        g.id as geo_location_id,
                        g.subject_rf,
                        upper(trim(regexp_replace(replace(replace(g.normalized_name, 'ё', 'е'), 'Ё', 'Е'),
                            '(район|муниципальный округ|город|г\\.|ст\\.|с\\.|п\\.|р\\.п\\.)', '', 'gi'))) as district_norm
                    from hybrids.geo_locations g
                    where g.subject_rf is not null
                )
                select t.trial_result_id, g.geo_location_id
                from trial_norm t
                join geo_norm g
                  on g.subject_rf = t.subject_rf
                 and g.district_norm = t.district_norm
                """
            )
        ).all()

        for trial_result_id, geo_location_id in linked_rows:
            stmt = insert(HybridTrialGeoLink).values(
                trial_result_id=trial_result_id,
                geo_location_id=geo_location_id,
                match_type="normalized_exact",
                match_confidence=1.00,
            )
            stmt = stmt.on_conflict_do_update(
                constraint="uq_hybrids_trial_geo_trial",
                set_={
                    "geo_location_id": stmt.excluded.geo_location_id,
                    "match_type": stmt.excluded.match_type,
                    "match_confidence": stmt.excluded.match_confidence,
                    "updated_at": func.now(),
                },
            )
            db.execute(stmt)
        db.commit()

        totals = db.execute(
            text(
                """
                select
                    (select count(*) from hybrids.geo_locations) as geo_locations,
                    (select count(*) from hybrids.trial_results) as trial_results,
                    (select count(*) from hybrids.trial_geo_links) as trial_geo_links
                """
            )
        ).mappings().one()
        print(f"[hybrids] geo_locations={totals['geo_locations']} trial_results={totals['trial_results']} trial_geo_links={totals['trial_geo_links']}")


if __name__ == "__main__":
    main()
