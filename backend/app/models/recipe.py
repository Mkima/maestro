from sqlalchemy import Column, Integer, String, Text, JSON, DateTime, Boolean, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime

from app.database import Base


class Recipe(Base):
    __tablename__ = "recipes"

    id = Column(Integer, primary_key=True)
    slug = Column(String(256), unique=True, index=True)
    title = Column(String(512), nullable=False)
    description = Column(Text, default="")
    servings = Column(String(64))
    source_url = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    steps = relationship("Step", back_populates="recipe", cascade="all, delete-orphan")
    ingredients = relationship("Ingredient", back_populates="recipe", cascade="all, delete-orphan")


class Step(Base):
    __tablename__ = "steps"

    id = Column(Integer, primary_key=True)
    recipe_id = Column(Integer, ForeignKey("recipes.id"), nullable=False)

    step_order = Column(Integer, nullable=False)
    instruction = Column(Text, nullable=False)
    category = Column(String(32), default="active")
    action_type = Column(String(64))
    duration_minutes = Column(Integer)
    tools = Column(JSON, default=list)
    heat_source = Column(String(64))
    temp_celsius = Column(Integer)
    dependencies = Column(JSON, default=list)
    concurrent_friendly = Column(Boolean, default=False)

    recipe = relationship("Recipe", back_populates="steps")


class Ingredient(Base):
    __tablename__ = "ingredients"

    id = Column(Integer, primary_key=True)
    recipe_id = Column(Integer, ForeignKey("recipes.id"), nullable=False)

    name = Column(String(256), nullable=False)
    qty = Column(String(64))
    unit = Column(String(32))
    optional = Column(Boolean, default=False)
    notes = Column(Text)

    recipe = relationship("Recipe", back_populates="ingredients")