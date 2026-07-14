from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from .base import Base


class AgroDataSource(Base):
    __tablename__ = "data_sources"
    __table_args__ = {"schema": "agro"}

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(32), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    endpoint_url = Column(Text, nullable=True)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

    observations = relationship("AgroDailyWeatherObservation", back_populates="source")


class AgroRegion(Base):
    __tablename__ = "regions"
    __table_args__ = {"schema": "agro"}

    id = Column(Integer, primary_key=True, index=True)
    country_code = Column(String(8), nullable=False, default="RU")
    region_code = Column(String(32), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    slug = Column(String(255), unique=True, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

    locations = relationship("AgroLocation", back_populates="region")


class AgroLocation(Base):
    __tablename__ = "locations"
    __table_args__ = (
        UniqueConstraint("region_id", "name", "latitude", "longitude", name="uq_agro_locations_region_name_lat_lon"),
        {"schema": "agro"},
    )

    id = Column(Integer, primary_key=True, index=True)
    region_id = Column(Integer, ForeignKey("agro.regions.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    district_name = Column(String(255), nullable=True)
    location_type = Column(String(64), nullable=False, default="city")
    latitude = Column(Numeric(9, 6), nullable=False)
    longitude = Column(Numeric(9, 6), nullable=False)
    elevation_m = Column(Integer, nullable=True)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

    region = relationship("AgroRegion", back_populates="locations")
    observations = relationship("AgroDailyWeatherObservation", back_populates="location")
    agronomy_metrics = relationship("AgroDailyAgronomyMetric", back_populates="location")


class AgroCrop(Base):
    __tablename__ = "crops"
    __table_args__ = {"schema": "agro"}

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(32), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    category = Column(String(128), nullable=True)
    season_start_month = Column(Integer, nullable=True)
    season_end_month = Column(Integer, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)


class AgroDailyWeatherObservation(Base):
    __tablename__ = "daily_weather_observations"
    __table_args__ = (
        UniqueConstraint("source_id", "location_id", "observation_date", name="uq_agro_daily_weather_source_location_date"),
        {"schema": "agro"},
    )

    id = Column(BigInteger, primary_key=True, index=True)
    source_id = Column(Integer, ForeignKey("agro.data_sources.id"), nullable=False, index=True)
    location_id = Column(Integer, ForeignKey("agro.locations.id"), nullable=False, index=True)
    observation_date = Column(Date, nullable=False, index=True)
    temperature_mean_c = Column(Numeric(6, 2), nullable=True)
    temperature_max_c = Column(Numeric(6, 2), nullable=True)
    temperature_min_c = Column(Numeric(6, 2), nullable=True)
    precipitation_mm = Column(Numeric(8, 2), nullable=True)
    shortwave_radiation_sum = Column(Numeric(10, 2), nullable=True)
    reference_et0_mm = Column(Numeric(8, 2), nullable=True)
    relative_humidity_pct = Column(Numeric(6, 2), nullable=True)
    wind_speed_10m_ms = Column(Numeric(6, 2), nullable=True)
    soil_moisture_0_7cm = Column(Numeric(8, 4), nullable=True)
    soil_moisture_7_28cm = Column(Numeric(8, 4), nullable=True)
    soil_moisture_28_100cm = Column(Numeric(8, 4), nullable=True)
    payload = Column(JSONB, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

    source = relationship("AgroDataSource", back_populates="observations")
    location = relationship("AgroLocation", back_populates="observations")


class AgroDailyAgronomyMetric(Base):
    __tablename__ = "daily_agronomy_metrics"
    __table_args__ = (
        UniqueConstraint("location_id", "observation_date", name="uq_agro_daily_agronomy_location_date"),
        {"schema": "agro"},
    )

    id = Column(BigInteger, primary_key=True, index=True)
    location_id = Column(Integer, ForeignKey("agro.locations.id"), nullable=False, index=True)
    observation_date = Column(Date, nullable=False, index=True)
    growing_degree_days_base_5 = Column(Numeric(8, 2), nullable=True)
    moisture_balance_mm = Column(Numeric(8, 2), nullable=True)
    heat_stress_flag = Column(Boolean, nullable=False, default=False)
    frost_flag = Column(Boolean, nullable=False, default=False)
    precipitation_to_et0_ratio = Column(Numeric(8, 4), nullable=True)
    source_code = Column(String(32), nullable=False, default="OPEN_METEO")
    notes = Column(Text, nullable=True)
    payload = Column(JSONB, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

    location = relationship("AgroLocation", back_populates="agronomy_metrics")
