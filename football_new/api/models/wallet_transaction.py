from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, Numeric, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from datetime import datetime
from .base import Base

class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"
    __table_args__ = {"schema": "football"}
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("football.users.id"), nullable=False)
    amount = Column(Numeric(14, 2), nullable=False)
    type = Column(String(20), nullable=False)  # 'credit' или 'debit'
    reason = Column(Text, nullable=True)  # e.g., "subscription:BASIC"
    created_at = Column(DateTime, default=func.now(), nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="transactions")
    
    def __repr__(self):
        return f"<WalletTransaction(id={self.id}, user_id={self.user_id}, amount={self.amount}, type='{self.type}')>"
