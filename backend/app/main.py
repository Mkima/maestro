from fastapi import FastAPI
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os

from app.database import Base
from app.models.recipe import Recipe, Step, Ingredient
from app.models.schedule import (
    KitchenResource,
    Schedule,
    TimeBlock,
    ScheduleConflict,
)

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./kitchen.db")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


app = FastAPI(title="Kitchen Mission Control API")


@app.on_event("startup")
async def startup():
    Base.metadata.create_all(bind=engine)


from app.routers import recipes, schedule, parse

app.include_router(recipes.router, prefix="/v1", tags=["recipes"])
app.include_router(schedule.router, prefix="/v1", tags=["schedule"])
app.include_router(parse.router, prefix="/v1", tags=["parse"])


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/v1/health")
def v1_health():
    return {"status": "ok"}