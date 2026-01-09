from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, Numeric, Index
from sqlalchemy.sql import func
from datetime import datetime
from .base import Base

class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"
    __table_args__ = {"schema": "football"}
    
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), unique=True, index=True, nullable=False)  # BASIC, PRO, ENTERPRISE
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Numeric(14, 2), nullable=False, default=0.00)
    duration_days = Column(Integer, nullable=False, default=30)
    limit_reports_per_month = Column(Integer, nullable=False, default=10)
    limit_alerts_per_day = Column(Integer, nullable=False, default=5)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
    
    def __repr__(self):
        return f"<SubscriptionPlan(id={self.id}, code='{self.code}', name='{self.name}', price={self.price})>"
