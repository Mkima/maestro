import os
import json


class StepClassifier:
    PASSIVE_KEYWORDS = [
        "let sit",
        "rest",
        "cool",
        "chill",
        "refrigerate",
        "marinate",
        "soak",
        "ferment",
        "rise",
        "proof",
        "set aside",
        "wait",
        "overnight",
    ]

    ACTIVE_KEYWORDS = [
        "chop",
        "dice",
        "slice",
        "mince",
        "heat",
        "stir",
        "mix",
        "fold",
        "knead",
        "roll",
        "cut",
        "cook",
        "sear",
        "sauté",
        "fry",
        "boil",
        "simmer",
        "bake",
        "roast",
        "grill",
        "flip",
        "pour",
        "add",
        "combine",
        "whisk",
        "beat",
    ]

    def classify_step(self, instruction: str) -> dict:
        instruction_lower = instruction.lower()

        is_passive = any(kw in instruction_lower for kw in self.PASSIVE_KEYWORDS)
        category = "passive" if is_passive else "active"

        estimated_duration = 5
        for kw in ["minute", "hour"]:
            if kw in instruction_lower:
                import re
                match = re.search(rf"(\d+)\s*{kw}", instruction_lower)
                if match:
                    duration = int(match.group(1))
                    estimated_duration = duration * (60 if kw == "hour" else 1)
                    break

        return {
            "category": category,
            "estimated_duration": min(estimated_duration, 120),
        }

    async def classify_steps(self, steps: list[dict]) -> list[dict]:
        results = []
        for step in steps:
            classification = self.classify_step(step.get("instruction", ""))
            results.append({**step, **classification})
        return results