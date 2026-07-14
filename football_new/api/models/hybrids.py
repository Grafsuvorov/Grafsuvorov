from sqlalchemy import (
    BigInteger,
    Column,
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


class HybridSource(Base):
    __tablename__ = "sources"
    __table_args__ = {"schema": "hybrids"}

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(64), unique=True, nullable=False, index=True)
    provider = Column(String(128), nullable=False)
    source_type = Column(String(64), nullable=False)
    name = Column(String(255), nullable=False)
    source_url = Column(Text, nullable=False)
    crop_code = Column(String(32), nullable=True)
    season_year = Column(Integer, nullable=True)
    macro_region = Column(String(64), nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)


class HybridMacroRegion(Base):
    __tablename__ = "macro_regions"
    __table_args__ = {"schema": "hybrids"}

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(32), unique=True, nullable=False, index=True)
    registry_number = Column(Integer, nullable=True, index=True)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)


class HybridGeoLocation(Base):
    __tablename__ = "geo_locations"
    __table_args__ = (
        UniqueConstraint("name", "location_type", "subject_rf", name="uq_hybrids_geo_name_type_subject"),
        {"schema": "hybrids"},
    )

    id = Column(Integer, primary_key=True, index=True)
    macro_region_id = Column(Integer, ForeignKey("hybrids.macro_regions.id"), nullable=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    normalized_name = Column(String(255), nullable=False, index=True)
    location_type = Column(String(32), nullable=False, default="district")
    subject_rf = Column(String(255), nullable=True, index=True)
    district = Column(String(255), nullable=True)
    settlement_name = Column(String(255), nullable=True)
    status = Column(String(32), nullable=False, default="active")
    notes = Column(Text, nullable=True)
    payload = Column(JSONB, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)


class HybridTrialGeoLink(Base):
    __tablename__ = "trial_geo_links"
    __table_args__ = (
        UniqueConstraint("trial_result_id", name="uq_hybrids_trial_geo_trial"),
        {"schema": "hybrids"},
    )

    id = Column(BigInteger, primary_key=True, index=True)
    trial_result_id = Column(BigInteger, ForeignKey("hybrids.trial_results.id"), nullable=False, index=True)
    geo_location_id = Column(Integer, ForeignKey("hybrids.geo_locations.id"), nullable=False, index=True)
    match_type = Column(String(32), nullable=False, default="exact")
    match_confidence = Column(Numeric(6, 2), nullable=False, default=1.00)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)


class HybridVariety(Base):
    __tablename__ = "varieties"
    __table_args__ = (
        UniqueConstraint("crop_code", "name_norm", "manufacturer_norm", name="uq_hybrids_variety_crop_name_mfr"),
        {"schema": "hybrids"},
    )

    id = Column(Integer, primary_key=True, index=True)
    crop_code = Column(String(32), nullable=False, index=True)
    product_type = Column(String(32), nullable=False, default="hybrid")
    name_raw = Column(String(255), nullable=False)
    name_norm = Column(String(255), nullable=False, index=True)
    manufacturer_norm = Column(String(128), nullable=False, index=True)
    external_code = Column(String(64), nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

    trait_snapshots = relationship("HybridTraitSnapshot", back_populates="variety")
    trial_results = relationship("HybridTrialResult", back_populates="variety")
    trial_summaries = relationship("HybridTrialSummary", back_populates="variety")


class HybridTraitSnapshot(Base):
    __tablename__ = "trait_snapshots"
    __table_args__ = (
        UniqueConstraint("variety_id", "source_id", name="uq_hybrids_trait_variety_source"),
        {"schema": "hybrids"},
    )

    id = Column(BigInteger, primary_key=True, index=True)
    variety_id = Column(Integer, ForeignKey("hybrids.varieties.id"), nullable=False, index=True)
    source_id = Column(Integer, ForeignKey("hybrids.sources.id"), nullable=False, index=True)
    crop_code = Column(String(32), nullable=False, index=True)
    maturity_label = Column(String(128), nullable=True)
    fao = Column(Integer, nullable=True)
    standard_moisture_pct = Column(Numeric(6, 2), nullable=True)
    protein_pct = Column(Numeric(6, 2), nullable=True)
    oil_pct = Column(Numeric(6, 2), nullable=True)
    starch_pct = Column(Numeric(6, 2), nullable=True)
    yield_min_c_ha = Column(Numeric(8, 2), nullable=True)
    yield_max_c_ha = Column(Numeric(8, 2), nullable=True)
    payload = Column(JSONB, nullable=True)
    source_url = Column(Text, nullable=False)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

    variety = relationship("HybridVariety", back_populates="trait_snapshots")


class HybridTrialResult(Base):
    __tablename__ = "trial_results"
    __table_args__ = (
        UniqueConstraint("record_hash", name="uq_hybrids_trial_record_hash"),
        {"schema": "hybrids"},
    )

    id = Column(BigInteger, primary_key=True, index=True)
    variety_id = Column(Integer, ForeignKey("hybrids.varieties.id"), nullable=False, index=True)
    source_id = Column(Integer, ForeignKey("hybrids.sources.id"), nullable=False, index=True)
    crop_code = Column(String(32), nullable=False, index=True)
    season_year = Column(Integer, nullable=False, index=True)
    macro_region = Column(String(64), nullable=True, index=True)
    subject_rf = Column(String(255), nullable=True, index=True)
    district = Column(String(255), nullable=True)
    sowing_date_raw = Column(String(64), nullable=True)
    harvest_date_raw = Column(String(64), nullable=True)
    plant_density_ths_per_ha = Column(Numeric(8, 2), nullable=True)
    harvest_moisture_pct = Column(Numeric(6, 2), nullable=True)
    standard_moisture_pct = Column(Numeric(6, 2), nullable=True)
    yield_standard_c_ha = Column(Numeric(8, 2), nullable=False)
    yield_standard_t_ha = Column(Numeric(8, 3), nullable=False)
    record_hash = Column(String(64), nullable=False, index=True)
    source_url = Column(Text, nullable=False)
    source_page = Column(Integer, nullable=True)
    raw_text = Column(Text, nullable=True)
    payload = Column(JSONB, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

    variety = relationship("HybridVariety", back_populates="trial_results")


class HybridTrialSummary(Base):
    __tablename__ = "trial_summaries"
    __table_args__ = (
        UniqueConstraint("variety_id", "season_year", "macro_region", name="uq_hybrids_summary_variety_year_region"),
        {"schema": "hybrids"},
    )

    id = Column(BigInteger, primary_key=True, index=True)
    variety_id = Column(Integer, ForeignKey("hybrids.varieties.id"), nullable=False, index=True)
    crop_code = Column(String(32), nullable=False, index=True)
    season_year = Column(Integer, nullable=False, index=True)
    macro_region = Column(String(64), nullable=True, index=True)
    trials_count = Column(Integer, nullable=False, default=0)
    avg_yield_c_ha = Column(Numeric(8, 2), nullable=True)
    min_yield_c_ha = Column(Numeric(8, 2), nullable=True)
    max_yield_c_ha = Column(Numeric(8, 2), nullable=True)
    avg_harvest_moisture_pct = Column(Numeric(6, 2), nullable=True)
    cv_yield_pct = Column(Numeric(8, 2), nullable=True)
    source_codes = Column(JSONB, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)

    variety = relationship("HybridVariety", back_populates="trial_summaries")
