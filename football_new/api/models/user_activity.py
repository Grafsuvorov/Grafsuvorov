from sqlalchemy import Column, Integer, String, DateTime, Text, Index
from sqlalchemy.sql import func

from .base import Base


class UserActivityLog(Base):
    __tablename__ = "user_activity_logs"
    __table_args__ = (
        Index("idx_user_activity_logs_user_created", "user_id", "created_at"),
        Index("idx_user_activity_logs_event_created", "event_type", "created_at"),
        Index("idx_user_activity_logs_path_created", "path", "created_at"),
        {"schema": "football"},
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True)
    user_email = Column(String(255), nullable=True)
    username = Column(String(100), nullable=True)
    event_type = Column(String(32), nullable=False, default="api_request")
    method = Column(String(10), nullable=True)
    path = Column(String(512), nullable=False)
    query_string = Column(Text, nullable=True)
    ip_address = Column(String(64), nullable=True)
    user_agent = Column(Text, nullable=True)
    referer = Column(Text, nullable=True)
    response_status = Column(Integer, nullable=True)
    response_time_ms = Column(Integer, nullable=True)
    metadata_json = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    def __repr__(self):
        return (
            f"<UserActivityLog(id={self.id}, user_id={self.user_id}, "
            f"event_type='{self.event_type}', path='{self.path}')>"
        )
