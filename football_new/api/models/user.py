from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, Numeric
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from datetime import datetime
from .base import Base

class User(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "football"}
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    verification_token = Column(String(255), unique=True, nullable=True)
    verification_token_expires = Column(DateTime, nullable=True)
    reset_password_token = Column(String(255), unique=True, nullable=True)
    # Имя колонки синхронизировано с DWH: reset_password_expires
    reset_password_expires = Column(DateTime, nullable=True)
    
    # Новые поля для подписок
    balance = Column(Numeric(14, 2), nullable=False, default=0.00)
    subscription_status = Column(String(20), nullable=False, default='free')
    subscription_until = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relationships
    subscriptions = relationship("UserSubscription", back_populates="user")
    transactions = relationship("WalletTransaction", back_populates="user")
    
    def __repr__(self):
        return f"<User(id={self.id}, email='{self.email}', username='{self.username}', is_verified={self.is_verified})>"
