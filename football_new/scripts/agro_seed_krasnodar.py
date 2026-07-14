#!/usr/bin/env python3
"""
Создаёт агро-схему и загружает стартовые агрономические данные
по Краснодарскому краю из Open-Meteo и NASA POWER.
"""
from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any
from urllib.parse import urlencode
from urllib.request import urlopen

from sqlalchemy import create_engine, func, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from api.core.config import settings
from api.models import (  # noqa: E402
    AgroCrop,
    AgroDailyAgronomyMetric,
    AgroDailyWeatherObservation,
    AgroDataSource,
    AgroLocation,
    AgroRegion,
    Base,
)


OPEN_METEO_CODE = "OPEN_METEO"
NASA_POWER_CODE = "NASA_POWER"


@dataclass(frozen=True)
class SeedLocation:
    name: str
    district_name: str
    latitude: float
    longitude: float
    location_type: str = "city"
    elevation_m: int | None = None


SEED_LOCATIONS = [
    SeedLocation("Краснодар", "город Краснодар", 45.04484, 38.97603, elevation_m=35),
    SeedLocation("Армавир", "город Армавир", 45.00117, 41.13238, elevation_m=190),
    SeedLocation("Ейск", "Ейский район", 46.71152, 38.27688, elevation_m=8),
    SeedLocation("Анапа", "город-курорт Анапа", 44.89497, 37.31660, elevation_m=10),
    SeedLocation("Кропоткин", "Кавказский район", 45.43417, 40.57556, elevation_m=80),
]

SEED_CROPS = [
    {"code": "winter_wheat", "name": "Озимая пшеница", "category": "grain", "season_start_month": 9, "season_end_month": 7},
    {"code": "corn", "name": "Кукуруза", "category": "grain", "season_start_month": 4, "season_end_month": 10},
    {"code": "sunflower", "name": "Подсолнечник", "category": "oilseed", "season_start_month": 4, "season_end_month": 9},
    {"code": "soybean", "name": "Соя", "category": "oilseed", "season_start_month": 4, "season_end_month": 10},
]


def normalize_database_url(url: str) -> str:
    return url.replace("host.docker.internal", "localhost")


def json_get(url: str) -> dict[str, Any]:
    with urlopen(url, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def q(value: Any, scale: str) -> Decimal | None:
    if value is None:
        return None
    return Decimal(str(value)).quantize(Decimal(scale), rounding=ROUND_HALF_UP)


def clean_metric(value: Any) -> Any:
    if value in (None, "", "NaN"):
        return None
    try:
        numeric_value = float(value)
    except (TypeError, ValueError):
        return value
    if numeric_value <= -900:
        return None
    return value


def ensure_schema(engine) -> None:
    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS agro"))


def ensure_base_metadata(engine) -> None:
    ensure_schema(engine)
    Base.metadata.create_all(bind=engine)


def seed_reference_data(db: Session) -> tuple[int, dict[str, int], dict[str, int]]:
    region = db.query(AgroRegion).filter(AgroRegion.region_code == "RU-KDA").one_or_none()
    if region is None:
        region = AgroRegion(
            country_code="RU",
            region_code="RU-KDA",
            name="Краснодарский край",
            slug="krasnodar-krai",
            notes="Стартовый регион для агроклиматического слоя.",
        )
        db.add(region)
        db.flush()

    source_ids: dict[str, int] = {}
    for code, name, endpoint_url, description in [
        (OPEN_METEO_CODE, "Open-Meteo Historical API", "https://archive-api.open-meteo.com/v1/archive", "Историческая погода, почвенная влага и ET0."),
        (NASA_POWER_CODE, "NASA POWER Daily API", "https://power.larc.nasa.gov/api/temporal/daily/point", "Ежедневные агроклиматические показатели NASA POWER."),
    ]:
        source = db.query(AgroDataSource).filter(AgroDataSource.code == code).one_or_none()
        if source is None:
            source = AgroDataSource(code=code, name=name, endpoint_url=endpoint_url, description=description)
            db.add(source)
            db.flush()
        source_ids[code] = source.id

    location_ids: dict[str, int] = {}
    for item in SEED_LOCATIONS:
        location = (
            db.query(AgroLocation)
            .filter(
                AgroLocation.region_id == region.id,
                AgroLocation.name == item.name,
            )
            .one_or_none()
        )
        if location is None:
            location = AgroLocation(
                region_id=region.id,
                name=item.name,
                district_name=item.district_name,
                location_type=item.location_type,
                latitude=q(item.latitude, "0.000001"),
                longitude=q(item.longitude, "0.000001"),
                elevation_m=item.elevation_m,
            )
            db.add(location)
            db.flush()
        location_ids[item.name] = location.id

    for crop_payload in SEED_CROPS:
        crop = db.query(AgroCrop).filter(AgroCrop.code == crop_payload["code"]).one_or_none()
        if crop is None:
            db.add(AgroCrop(**crop_payload))

    db.commit()
    return region.id, source_ids, location_ids


def build_open_meteo_url(latitude: float, longitude: float, start_date: date, end_date: date) -> str:
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "daily": ",".join(
            [
                "temperature_2m_mean",
                "temperature_2m_max",
                "temperature_2m_min",
                "precipitation_sum",
                "shortwave_radiation_sum",
                "et0_fao_evapotranspiration",
                "soil_moisture_0_to_7cm_mean",
                "soil_moisture_7_to_28cm_mean",
                "soil_moisture_28_to_100cm_mean",
            ]
        ),
        "timezone": "Europe/Moscow",
    }
    return "https://archive-api.open-meteo.com/v1/archive?" + urlencode(params)


def fetch_open_meteo_series(latitude: float, longitude: float, start_date: date, end_date: date) -> list[dict[str, Any]]:
    payload = json_get(build_open_meteo_url(latitude, longitude, start_date, end_date))
    daily = payload["daily"]
    rows = []
    for idx, observed_at in enumerate(daily["time"]):
        rows.append(
            {
                "observation_date": observed_at,
                "temperature_mean_c": daily.get("temperature_2m_mean", [None])[idx],
                "temperature_max_c": daily.get("temperature_2m_max", [None])[idx],
                "temperature_min_c": daily.get("temperature_2m_min", [None])[idx],
                "precipitation_mm": daily.get("precipitation_sum", [None])[idx],
                "shortwave_radiation_sum": daily.get("shortwave_radiation_sum", [None])[idx],
                "reference_et0_mm": daily.get("et0_fao_evapotranspiration", [None])[idx],
                "soil_moisture_0_7cm": daily.get("soil_moisture_0_to_7cm_mean", [None])[idx],
                "soil_moisture_7_28cm": daily.get("soil_moisture_7_to_28cm_mean", [None])[idx],
                "soil_moisture_28_100cm": daily.get("soil_moisture_28_to_100cm_mean", [None])[idx],
                "payload": payload,
            }
        )
    return rows


def build_nasa_power_url(latitude: float, longitude: float, start_date: date, end_date: date) -> str:
    params = {
        "parameters": "T2M,T2M_MAX,T2M_MIN,PRECTOTCORR,RH2M,WS10M,ALLSKY_SFC_SW_DWN",
        "community": "AG",
        "longitude": longitude,
        "latitude": latitude,
        "start": start_date.strftime("%Y%m%d"),
        "end": end_date.strftime("%Y%m%d"),
        "format": "JSON",
        "time-standard": "UTC",
    }
    return "https://power.larc.nasa.gov/api/temporal/daily/point?" + urlencode(params)


def fetch_nasa_power_series(latitude: float, longitude: float, start_date: date, end_date: date) -> list[dict[str, Any]]:
    payload = json_get(build_nasa_power_url(latitude, longitude, start_date, end_date))
    parameter = payload["properties"]["parameter"]
    rows = []
    for observed_at, temp_mean in parameter["T2M"].items():
        rows.append(
            {
                "observation_date": datetime.strptime(observed_at, "%Y%m%d").date().isoformat(),
                "temperature_mean_c": clean_metric(temp_mean),
                "temperature_max_c": clean_metric(parameter["T2M_MAX"].get(observed_at)),
                "temperature_min_c": clean_metric(parameter["T2M_MIN"].get(observed_at)),
                "precipitation_mm": clean_metric(parameter["PRECTOTCORR"].get(observed_at)),
                "shortwave_radiation_sum": clean_metric(parameter["ALLSKY_SFC_SW_DWN"].get(observed_at)),
                "reference_et0_mm": None,
                "relative_humidity_pct": clean_metric(parameter["RH2M"].get(observed_at)),
                "wind_speed_10m_ms": clean_metric(parameter["WS10M"].get(observed_at)),
                "payload": payload,
            }
        )
    return rows


def compute_agronomy_row(row: dict[str, Any], source_code: str) -> dict[str, Any]:
    t_mean = row.get("temperature_mean_c")
    t_max = row.get("temperature_max_c")
    t_min = row.get("temperature_min_c")
    precipitation = row.get("precipitation_mm")
    et0 = row.get("reference_et0_mm")
    gdd = max((t_mean or 0) - 5.0, 0.0) if t_mean is not None else None
    moisture_balance = (precipitation - et0) if precipitation is not None and et0 is not None else None
    ratio = (precipitation / et0) if precipitation is not None and et0 not in (None, 0) else None
    return {
        "observation_date": row["observation_date"],
        "growing_degree_days_base_5": gdd,
        "moisture_balance_mm": moisture_balance,
        "heat_stress_flag": bool(t_max is not None and t_max >= 30),
        "frost_flag": bool(t_min is not None and t_min <= 0),
        "precipitation_to_et0_ratio": ratio,
        "source_code": source_code,
        "payload": {
            "temperature_mean_c": t_mean,
            "temperature_max_c": t_max,
            "temperature_min_c": t_min,
            "precipitation_mm": precipitation,
            "reference_et0_mm": et0,
        },
    }


def upsert_weather_rows(db: Session, location_id: int, source_id: int, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    payload = []
    for row in rows:
        payload.append(
            {
                "source_id": source_id,
                "location_id": location_id,
                "observation_date": row["observation_date"],
                "temperature_mean_c": q(row.get("temperature_mean_c"), "0.01"),
                "temperature_max_c": q(row.get("temperature_max_c"), "0.01"),
                "temperature_min_c": q(row.get("temperature_min_c"), "0.01"),
                "precipitation_mm": q(row.get("precipitation_mm"), "0.01"),
                "shortwave_radiation_sum": q(row.get("shortwave_radiation_sum"), "0.01"),
                "reference_et0_mm": q(row.get("reference_et0_mm"), "0.01"),
                "relative_humidity_pct": q(row.get("relative_humidity_pct"), "0.01"),
                "wind_speed_10m_ms": q(row.get("wind_speed_10m_ms"), "0.01"),
                "soil_moisture_0_7cm": q(row.get("soil_moisture_0_7cm"), "0.0001"),
                "soil_moisture_7_28cm": q(row.get("soil_moisture_7_28cm"), "0.0001"),
                "soil_moisture_28_100cm": q(row.get("soil_moisture_28_100cm"), "0.0001"),
                "payload": row.get("payload"),
            }
        )

    stmt = insert(AgroDailyWeatherObservation).values(payload)
    stmt = stmt.on_conflict_do_update(
        constraint="uq_agro_daily_weather_source_location_date",
        set_={
            "temperature_mean_c": stmt.excluded.temperature_mean_c,
            "temperature_max_c": stmt.excluded.temperature_max_c,
            "temperature_min_c": stmt.excluded.temperature_min_c,
            "precipitation_mm": stmt.excluded.precipitation_mm,
            "shortwave_radiation_sum": stmt.excluded.shortwave_radiation_sum,
            "reference_et0_mm": stmt.excluded.reference_et0_mm,
            "relative_humidity_pct": stmt.excluded.relative_humidity_pct,
            "wind_speed_10m_ms": stmt.excluded.wind_speed_10m_ms,
            "soil_moisture_0_7cm": stmt.excluded.soil_moisture_0_7cm,
            "soil_moisture_7_28cm": stmt.excluded.soil_moisture_7_28cm,
            "soil_moisture_28_100cm": stmt.excluded.soil_moisture_28_100cm,
            "payload": stmt.excluded.payload,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def upsert_agronomy_rows(db: Session, location_id: int, rows: list[dict[str, Any]], source_code: str) -> None:
    if not rows:
        return
    payload = []
    for row in rows:
        metric = compute_agronomy_row(row, source_code)
        payload.append(
            {
                "location_id": location_id,
                "observation_date": metric["observation_date"],
                "growing_degree_days_base_5": q(metric.get("growing_degree_days_base_5"), "0.01"),
                "moisture_balance_mm": q(metric.get("moisture_balance_mm"), "0.01"),
                "heat_stress_flag": metric["heat_stress_flag"],
                "frost_flag": metric["frost_flag"],
                "precipitation_to_et0_ratio": q(metric.get("precipitation_to_et0_ratio"), "0.0001"),
                "source_code": metric["source_code"],
                "payload": metric["payload"],
            }
        )

    stmt = insert(AgroDailyAgronomyMetric).values(payload)
    stmt = stmt.on_conflict_do_update(
        constraint="uq_agro_daily_agronomy_location_date",
        set_={
            "growing_degree_days_base_5": stmt.excluded.growing_degree_days_base_5,
            "moisture_balance_mm": stmt.excluded.moisture_balance_mm,
            "heat_stress_flag": stmt.excluded.heat_stress_flag,
            "frost_flag": stmt.excluded.frost_flag,
            "precipitation_to_et0_ratio": stmt.excluded.precipitation_to_et0_ratio,
            "source_code": stmt.excluded.source_code,
            "payload": stmt.excluded.payload,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def load_data(db: Session, source_ids: dict[str, int], location_ids: dict[str, int], start_date: date, end_date: date) -> None:
    for item in SEED_LOCATIONS:
        location_id = location_ids[item.name]

        open_meteo_rows = fetch_open_meteo_series(item.latitude, item.longitude, start_date, end_date)
        upsert_weather_rows(db, location_id, source_ids[OPEN_METEO_CODE], open_meteo_rows)
        upsert_agronomy_rows(db, location_id, open_meteo_rows, OPEN_METEO_CODE)

        nasa_power_rows = fetch_nasa_power_series(item.latitude, item.longitude, start_date, end_date)
        upsert_weather_rows(db, location_id, source_ids[NASA_POWER_CODE], nasa_power_rows)

        db.commit()
        print(f"[agro] loaded {item.name}: open-meteo={len(open_meteo_rows)} days, nasa-power={len(nasa_power_rows)} days")


def summarize(db: Session) -> None:
    rows = db.execute(
        text(
            """
            select
                l.name,
                count(*) filter (where d.code = 'OPEN_METEO') as open_meteo_days,
                count(*) filter (where d.code = 'NASA_POWER') as nasa_power_days,
                min(w.observation_date) as min_date,
                max(w.observation_date) as max_date
            from agro.daily_weather_observations w
            join agro.locations l on l.id = w.location_id
            join agro.data_sources d on d.id = w.source_id
            group by l.name
            order by l.name
            """
        )
    ).fetchall()
    for row in rows:
        print(
            "[agro] summary",
            {
                "location": row.name,
                "open_meteo_days": row.open_meteo_days,
                "nasa_power_days": row.nasa_power_days,
                "min_date": row.min_date.isoformat() if row.min_date else None,
                "max_date": row.max_date.isoformat() if row.max_date else None,
            },
        )


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    start_date = date.fromisoformat(os.getenv("AGRO_START_DATE", "2026-04-01"))
    end_date = date.fromisoformat(os.getenv("AGRO_END_DATE", "2026-04-22"))

    engine = create_engine(database_url, pool_pre_ping=True)
    ensure_base_metadata(engine)

    with Session(engine) as db:
        _, source_ids, location_ids = seed_reference_data(db)
        load_data(db, source_ids, location_ids, start_date, end_date)
        summarize(db)


if __name__ == "__main__":
    main()
