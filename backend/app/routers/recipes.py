from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional

from app.main import get_db
from app.models.recipe import Recipe as RecipeModel, Step as StepModel, Ingredient as IngredientModel


router = APIRouter()


class RecipeCreate(BaseModel):
    title: str
    description: Optional[str] = ""
    servings: Optional[str] = None
    source_url: Optional[str] = None
    steps: list[dict]
    ingredients: list[dict]


class RecipeResponse(BaseModel):
    id: int
    title: str
    description: str
    servings: Optional[str]

    class Config:
        from_attributes = True


@router.post("/recipes/")
def create_recipe(recipe: RecipeCreate, db: Session = Depends(get_db)):
    db_recipe = RecipeModel(
        title=recipe.title,
        description=recipe.description,
        servings=recipe.servings,
        source_url=recipe.source_url,
    )
    db.add(db_recipe)
    db.flush()

    for i, step_data in enumerate(recipe.steps):
        step = StepModel(
            recipe_id=db_recipe.id,
            step_order=i + 1,
            instruction=step_data.get("instruction", ""),
            category=step_data.get("category", "active"),
            action_type=step_data.get("action_type"),
            duration_minutes=step_data.get("duration_minutes"),
            tools=step_data.get("tools", []),
            heat_source=step_data.get("heat_source"),
            temp_celsius=step_data.get("temp_celsius"),
            dependencies=step_data.get("dependencies", []),
            concurrent_friendly=step_data.get("concurrent_friendly", False),
        )
        db.add(step)

    for ing_data in recipe.ingredients:
        ingredient = IngredientModel(
            recipe_id=db_recipe.id,
            name=ing_data.get("name", ""),
            qty=str(ing_data.get("qty")) if ing_data.get("qty") else None,
            unit=ing_data.get("unit"),
            optional=ing_data.get("optional", False),
            notes=ing_data.get("notes"),
        )
        db.add(ingredient)

    db.commit()
    db.refresh(db_recipe)
    return {"id": db_recipe.id, "title": db_recipe.title}


@router.get("/recipes/")
def list_recipes(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    recipes = db.query(RecipeModel).offset(skip).limit(limit).all()
    return [
        {
            "id": r.id,
            "title": r.title,
            "description": r.description,
            "servings": r.servings,
            "source_url": r.source_url,
        }
        for r in recipes
    ]


@router.get("/recipes/{recipe_id}")
def get_recipe(recipe_id: int, db: Session = Depends(get_db)):
    recipe = db.query(RecipeModel).filter(RecipeModel.id == recipe_id).first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    steps = (
        db.query(StepModel)
        .filter(StepModel.recipe_id == recipe_id)
        .order_by(StepModel.step_order)
        .all()
    )
    ingredients = db.query(IngredientModel).filter(IngredientModel.recipe_id == recipe_id).all()

    return {
        "id": recipe.id,
        "title": recipe.title,
        "description": recipe.description,
        "servings": recipe.servings,
        "source_url": recipe.source_url,
        "steps": [
            {
                "step_order": s.step_order,
                "instruction": s.instruction,
                "category": s.category,
                "action_type": s.action_type,
                "duration_minutes": s.duration_minutes,
                "tools": s.tools or [],
                "heat_source": s.heat_source,
                "temp_celsius": s.temp_celsius,
                "dependencies": s.dependencies or [],
                "concurrent_friendly": s.concurrent_friendly,
            }
            for s in steps
        ],
        "ingredients": [
            {
                "name": i.name,
                "qty": i.qty,
                "unit": i.unit,
                "optional": i.optional,
                "notes": i.notes,
            }
            for i in ingredients
        ],
    }