#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from api.core.config import settings  # noqa: E402


CLEANUP_RULES = [
    {
        "subject_rf": "Республика Северная Осетия — Алания",
        "district": "Дигорский",
        "where_like": "Северная Осетия%Дигорский",
    },
    {
        "subject_rf": "Республика Северная Осетия — Алания",
        "district": "Правобережный",
        "where_like": "Северная Осетия%Правобережный",
    },
    {
        "subject_rf": "Республика Северная Осетия — Алания",
        "district": "Ардонский",
        "where_like": "Северная Осетия%Ардонский",
    },
    {
        "subject_rf": "Республика Северная Осетия — Алания",
        "district": "Кировский",
        "where_like": "Северная Осетия%Кировский",
    },
    {
        "subject_rf": "Республика Северная Осетия — Алания",
        "district": "Моздокский",
        "where_like": "Северная Осетия%Моздокский",
    },
    {
        "subject_rf": "Кабардино-Балкарская Республика",
        "district": "Майский",
        "where_like": "Балкария Майский",
    },
    {
        "subject_rf": "Ивановская область",
        "district": "Кинешемский",
        "where_like": "Ивановская Кинешемский",
    },
]


def normalize_database_url(url: str) -> str:
    return url.replace("host.docker.internal", "127.0.0.1")


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)

    with Session(engine) as db:
        updated = 0
        for rule in CLEANUP_RULES:
            result = db.execute(
                text(
                    """
                    update hybrids.trial_results
                    set subject_rf = :subject_rf,
                        district = :district,
                        updated_at = now()
                    where coalesce(subject_rf, '') = ''
                      and district like :where_like
                    """
                ),
                rule,
            )
            updated += result.rowcount or 0
        db.commit()
        print(f"[hybrids] cleaned_trial_geo_rows={updated}")


if __name__ == "__main__":
    main()
