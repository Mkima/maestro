import requests
import os
import json
import logging
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

try:
    from readability import Document
    import lxml.html
    READABILITY_AVAILABLE = True
except ImportError:
    READABILITY_AVAILABLE = False


class RecipeParser:
    JINA_READER_URL = "https://r.jina.ai/{url}"

    def __init__(self):
        self.gemini_api_key = os.getenv("GEMINI_API_KEY")
        self.jina_api_key = os.getenv("JINA_API_KEY")

    def fetch_recipe_text(self, url: str) -> Optional[str]:
        if not READABILITY_AVAILABLE:
            return self._fetch_with_jina(url)

        try:
            response = requests.get(url, timeout=15)
            response.encoding = "utf-8"
            doc = Document(response.text)
            clean_html = doc.summary()
            text = lxml.html.fromstring(clean_html).text_content()
            return self._remove_comment_phrases(text)
        except Exception as e:
            print(f"Readability fetch error: {e}, trying Jina...")
            return self._fetch_with_jina(url)

    def _fetch_with_jina(self, url: str) -> Optional[str]:
        headers = {
            "X-Return-Format": "markdown",
            "X-Target-Selector": "article, .recipe-content, main, [itemtype*=Recipe]",
            "X-Remove-Selector": ".comments-area, .comment-list, #comments, .sidebar, .footer, "
                                ".nav-menu, .social-share, .related-posts, .ad, .advertisement",
        }
        if self.jina_api_key:
            headers["Authorization"] = f"Bearer {self.jina_api_key}"

        jina_url = self.JINA_READER_URL.format(url=url)
        try:
            response = requests.get(jina_url, headers=headers, timeout=30.0)
            response.raise_for_status()
            return self._clean_jina_content(response.text)
        except Exception as e:
            print(f"Jina fetch error: {e}")
            return None

    def _remove_comment_phrases(self, text: str) -> str:
        import re
        patterns_to_remove = [
            r"\[הגב\]\([^)]+\)",
            r"\d{4}-\d{2}-\d{2}",
            r"[א-ת]+\s+(פברואר|מרץ|אוגוסט|ספטמבר|אוקטובר|נובמבר|דצמבר|ינואר|מאי|יוני|יולי)\s+\d{4}",
            r"נטלי.*?[0-9]{1,2}:[0-9]{2}\s*(am|pm)",
            r"\d+\s*(תגובות|comments)",
        ]
        for pattern in patterns_to_remove:
            text = re.sub(pattern, "", text)
        return text

    def _clean_jina_content(self, markdown: str) -> str:
        lines = markdown.split("\n")
        cleaned = []
        in_comments_section = False
        comment_indicators = ["comment", "הגב", "reply", "responses", "פרסום"]

        for line in lines:
            lower_line = line.lower()
            if any(indicator in lower_line for indicator in comment_indicators):
                in_comments_section = True
            if not in_comments_section:
                cleaned.append(line)

        result = "\n".join(cleaned)
        return self._remove_comment_phrases(result)

    def extract_structured_recipe(self, markdown_content: str, verbose: bool = False) -> dict:
        system_instruction = """You are a Culinary Data Architect. Your goal is to convert the provided recipe text (which may be in Hebrew) into a clean, machine-readable JSON object following a strict schema.

STRICT RULES:
1. LANGUAGE: Extract instructions in the original language, but keep JSON keys in English.
2. TIMING: If a step doesn't mention a duration (e.g., "Sauté until golden"), use your culinary knowledge to provide a 'best guess' in minutes.
3. CATEGORIZATION:
   - "active": The cook is physically busy (chopping, whisking, searing).
   - "passive": The cook is waiting (baking, simmering, resting).
4. CONCURRENCY: Mark 'concurrent_friendly' as true if the step does not require constant attention or a specific limited heat source (like a burner).
5. TOOLS: Identify all necessary tools mentioned or implied (e.g., "Sauté" implies a pan).

JSON SCHEMA TO FOLLOW:
{
  "recipe_name": "string",
  "servings": "number",
  "ingredients": [{"item": "string", "amount": "string"}],
  "steps": [
    {
      "step_id": "s1",
      "instruction": "string",
      "category": "active|passive",
      "duration_minutes": integer,
      "requirements": {
        "tools": ["string"],
        "heat_source": "oven|stovetop|none",
        "temp_celsius": integer or null
      },
      "concurrent_friendly": boolean,
      "dependencies": ["step_id"]
    }
  ]
}

CRITICAL: Your output must include ALL ingredients and STEPS from the source recipe text. Do NOT omit any ingredients, even if they seem minor (like salt or pepper). Ensure every cooking step is captured with full detail.

INSTRUCTIONS:
1. First read through entire recipe to identify all ingredients, their quantities, and units
2. Then go through each instruction step by step in order of appearance 
3. Extract the complete list of steps exactly as described in the original text
4. Each ingredient must have both item name AND amount/quantity specified
5. Use the exact wording from the recipe for instructions to maintain authenticity"""

        if verbose:
            logger.info(f"Full page content for extraction ({len(markdown_content)} chars):\n{markdown_content}")

        prompt = f"""{system_instruction}

TEXT TO PARSE:
{markdown_content[:8000]}
"""

        local_url = os.getenv("LOCAL_LLM_URL")
        if not local_url:
            return {"error": "LOCAL_LLM_URL not configured"}

        try:
            import httpx
            logger.info(f"Attempting local LLM at {local_url}")
            # Prepare request in format expected by LM Studio 
            model_name = os.getenv("LOCAL_LLM_MODEL", "llama3.2:latest")
            
            payload = {
                "model": model_name,
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "temperature": 0.3,
                "max_tokens": -1,
                "stream": False
            }
            
            # Try sending with proper headers for LM Studio compatibility 
            response = httpx.post(
                local_url,
                json=payload,
                timeout=180.0,
                headers={"Content-Type": "application/json"}
            )
            logger.info(f"Local LLM response status: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                logger.info(f"Full LM response structure: {json.dumps(result, indent=2)[:1000]}")
                
                # Handle different response formats
                content = ""
                if "choices" in result and len(result["choices"]) > 0:
                    choice = result["choices"][0]
                    if "message" in choice:
                        message = choice["message"]
                        if "content" in message:
                            content = message["content"]
                        elif "text" in message:
                            content = message["text"]
                else:
                    # Try alternative formats
                    if isinstance(result, dict):
                        for key in ["response", "text"]:
                            if key in result:
                                content = str(result[key])
                                break
                
                logger.info(f"Local LLM extracted content (first 500 chars): {content[:500] if content else 'EMPTY'}")
                
                # Try to parse as JSON first
                try:
                    result = json.loads(content.strip())
                    
                    # Add validation for completeness
                    if verbose and "recipe" in result:
                        recipe_data = result["recipe"]
                        if "ingredients" in recipe_data and "steps" in recipe_data:
                            logger.info(f"Recipe completeness check:")
                            logger.info(f"  - Ingredients found: {len(recipe_data['ingredients'])}")
                            logger.info(f"  - Steps found: {len(recipe_data['steps'])}")
                            
                    return result
                except json.JSONDecodeError as e:
                    # If not valid JSON, log the raw content for debugging and return it
                    logger.error(f"Failed to parse LLM output as JSON: {e}")
                    logger.info(f"LLM Raw Content (first 1000 chars): {content[:1000]}")
                    return {"raw_content": content, "error": f"JSON parsing failed: {str(e)}"}
            else:
                error_text = response.text if response.text else f"HTTP {response.status_code}"
                return {"error": f"Local LLM returned status code: {response.status_code}, message: {error_text}"}
        except Exception as e:
            print(f"Local LLM error: {e}")
            logger.error(f"Failed to process with local LLM: {e}")
            return {"error": str(e)}

    async def parse_url(self, url: str, verbose: bool = False) -> dict:
        markdown = self.fetch_recipe_text(url)
        if not markdown:
            return {"error": "Failed to fetch URL"}

        structured = self.extract_structured_recipe(markdown, verbose=verbose)
        if "error" in structured:
            return structured

        from app.step_classifier import StepClassifier

        classifier = StepClassifier()
        for step in structured.get("steps", []):
            classification = await classifier.classify_step(step["instruction"])
            step["category"] = classification.get("category", "active")
            if not step.get("duration_minutes"):
                step["duration_minutes"] = classification.get("estimated_duration", 5)

        return {"recipe": structured, "source_url": url}