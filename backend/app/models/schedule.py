from sqlalchemy import Column, Integer, String, Text, JSON, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime

from app.database import Base


class KitchenResource(Base):
    __tablename__ = "kitchen_resources"

    id = Column(Integer, primary_key=True)
    name = Column(String(128), nullable=False, unique=True)
    resource_type = Column(String(64))
    heat_source = Column(String(64))


class Schedule(Base):
    __tablename__ = "schedules"

    id = Column(Integer, primary_key=True)
    target_finish_time = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    time_blocks = relationship("TimeBlock", back_populates="schedule", cascade="all, delete-orphan")


class TimeBlock(Base):
    __tablename__ = "time_blocks"

    id = Column(Integer, primary_key=True)
    schedule_id = Column(Integer, ForeignKey("schedules.id"), nullable=False)

    recipe_id = Column(Integer, ForeignKey("recipes.id"))
    step_id = Column(String(64))
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=False)
    category = Column(String(32))

    schedule = relationship("Schedule", back_populates="time_blocks")


class ScheduleConflict(Base):
    __tablename__ = "schedule_conflicts"

    id = Column(Integer, primary_key=True)
    schedule_id = Column(Integer, ForeignKey("schedules.id"), nullable=False)

    conflict_type = Column(String(64), nullable=False)
    resource_a = Column(String(128))
    resource_b = Column(String(128))
    time_start = Column(DateTime)
    time_end = Column(DateTime)
    message = Column(Text)