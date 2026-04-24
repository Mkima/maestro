from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional

from app.main import get_db
from app.models.schedule import Schedule as ScheduleModel, TimeBlock as TimeBlockModel


router = APIRouter()


class TimeBlockCreate(BaseModel):
    recipe_id: int
    step_id: str
    start_time: str
    end_time: str
    category: str


class ScheduleCreate(BaseModel):
    target_finish_time: str
    recipes: list[dict]


@router.post("/schedule/create")
def create_schedule(schedule_data: ScheduleCreate, db: Session = Depends(get_db)):
    from datetime import datetime
    from app.scheduling_engine import SchedulingEngine

    try:
        target_time = datetime.fromisoformat(schedule_data.target_finish_time)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid datetime format. Use ISO 8601.")

    engine = SchedulingEngine()
    result = engine.create_schedule(schedule_data.recipes, schedule_data.target_finish_time)

    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])

    db_schedule = ScheduleModel(target_finish_time=target_time)
    db.add(db_schedule)
    db.flush()

    for tb in result.get("time_blocks", []):
        try:
            start = datetime.fromisoformat(tb["start_time"])
            end = datetime.fromisoformat(tb["end_time"])
        except ValueError:
            continue

        time_block = TimeBlockModel(
            schedule_id=db_schedule.id,
            recipe_id=tb["recipe_id"],
            step_id=tb["step_id"],
            start_time=start,
            end_time=end,
            category=tb.get("category", "active"),
        )
        db.add(time_block)

    db.commit()
    db.refresh(db_schedule)
    return {
        "id": db_schedule.id,
        "target_finish_time": target_time.isoformat(),
        "time_blocks": result["time_blocks"],
        "conflicts": result.get("conflicts", []),
    }


@router.post("/schedule/compute")
def compute_schedule(schedule_data: ScheduleCreate):
    from app.scheduling_engine import SchedulingEngine

    engine = SchedulingEngine()
    result = engine.create_schedule(schedule_data.recipes, schedule_data.target_finish_time)
    return result


@router.get("/schedule/{schedule_id}")
def get_schedule(schedule_id: int, db: Session = Depends(get_db)):
    schedule = db.query(ScheduleModel).filter(ScheduleModel.id == schedule_id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")

    time_blocks = (
        db.query(TimeBlockModel)
        .filter(TimeBlockModel.schedule_id == schedule_id)
        .order_by(TimeBlockModel.start_time)
        .all()
    )

    return {
        "id": schedule.id,
        "target_finish_time": schedule.target_finish_time.isoformat(),
        "time_blocks": [
            {
                "recipe_id": tb.recipe_id,
                "step_id": tb.step_id,
                "start_time": tb.start_time.isoformat(),
                "end_time": tb.end_time.isoformat(),
                "category": tb.category,
            }
            for tb in time_blocks
        ],
    }