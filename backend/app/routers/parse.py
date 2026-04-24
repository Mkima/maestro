from fastapi import APIRouter

router = APIRouter()


@router.post("/parse/url")
async def parse_url(url: str):
    return {"status": "not_implemented", "message": "Use /v1/scrape to parse a recipe URL"}


@router.post("/scrape")
async def scrape_recipe(url: str):
    from app.recipe_parser import RecipeParser

    parser = RecipeParser()
    result = await parser.parse_url(url)
    return result