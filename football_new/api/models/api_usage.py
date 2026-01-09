# api/models/api_usage.py
from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Index
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from .base import Base

class APIUsage(Base):
    __tablename__ = "api_usage"
    __table_args__ = {"schema": "football"}
    
    id = Column(Integer, primary_key=True, index=True)
    api_client_id = Column(Integer, ForeignKey("football.api_clients.id"), nullable=True)
    endpoint = Column(String(255), nullable=False)
    method = Column(String(10), nullable=False)  # GET, POST, etc.
    ip_address = Column(String(45), nullable=False)  # IPv4 или IPv6
    user_agent = Column(Text, nullable=True)
    response_status = Column(Integer, nullable=False)
    response_time_ms = Column(Integer, nullable=True)  # Время ответа в миллисекундах
    created_at = Column(DateTime, default=func.now(), nullable=False)
    
    # Relationships
    api_client = relationship("APIClient", backref="usage_logs")
    
    # Индексы для быстрого поиска
    __table_args__ = (
        Index('idx_api_usage_client_date', 'api_client_id', 'created_at'),
        Index('idx_api_usage_endpoint_date', 'endpoint', 'created_at'),
        Index('idx_api_usage_ip_date', 'ip_address', 'created_at'),
    )
    
    def __repr__(self):
        return f"<APIUsage(id={self.id}, api_client_id={self.api_client_id}, endpoint='{self.endpoint}', status={self.response_status})>"
