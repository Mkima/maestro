import requests
import os
import json
from typing import Optional

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

    def extract_structured_recipe(self, markdown_content: str) -> dict:
        if not self.gemini_api_key:
            return {"error": "GEMINI_API_KEY not set"}

        import google.generativeai as genai
        genai.configure(api_key=self.gemini_api_key)
        model = genai.GenerativeModel("gemini-1.5-flash")

        prompt = f"""Parse this recipe content and extract structured data.
Extract ONLY the actual recipe (ingredients, instructions). Ignore all comments, Q&A, user discussions.

Return JSON with exactly this structure:
{{
  "title": "Recipe name",
  "description": "Brief description",
  "servings": "4 servings",
  "ingredients": [
    {{"name": "ingredient name", "qty": "200", "unit": "g", "optional": false, "notes": ""}}
  ],
  "steps": [
    {{
      "instruction": "Step instruction text",
      "category": "active or passive - is this hands-on cooking or waiting?",
      "duration_minutes": 10,
      "tools": [],
      "heat_source": null or "stovetop" or "oven",
      "temp_celsius": null or 200
    }}
  ]
}}

Recipe content:
{markdown_content[:8000]}
"""

        try:
            response = model.generate_content(prompt)
            text = response.text.strip()
            if text.startswith("```json"):
                text = text[7:]
            if text.endswith("```"):
                text = text[:-3]
            return json.loads(text.strip())
        except Exception as e:
            print(f"Gemini extraction error: {e}")
            return {"error": str(e)}

    async def parse_url(self, url: str) -> dict:
        markdown = self.fetch_recipe_text(url)
        if not markdown:
            return {"error": "Failed to fetch URL"}

        structured = self.extract_structured_recipe(markdown)
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