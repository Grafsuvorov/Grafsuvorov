# api/models/api_client.py
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, Numeric
from sqlalchemy.sql import func
from .base import Base

class APIClient(Base):
    __tablename__ = "api_clients"
    __table_args__ = {"schema": "football"}
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)  # Название клиента/компании
    email = Column(String(255), nullable=False)  # Email для связи
    api_key = Column(String(255), unique=True, index=True, nullable=False)
    role = Column(String(20), nullable=False, default='user')  # user, premium, business, admin
    quota_monthly = Column(Integer, nullable=False, default=1000)  # Лимит запросов в месяц
    used_current_month = Column(Integer, nullable=False, default=0)  # Использовано в текущем месяце
    quota_reset_date = Column(DateTime, nullable=True)  # Дата сброса квоты
    business_credits = Column(Numeric(14, 2), nullable=False, default=0.00)  # Кредиты для бизнес-данных
    ip_whitelist = Column(Text, nullable=True)  # JSON список разрешенных IP
    is_active = Column(Boolean, default=True, nullable=False)
    last_used = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
    
    def __repr__(self):
        return f"<APIClient(id={self.id}, name='{self.name}', email='{self.email}', role='{self.role}')>"
