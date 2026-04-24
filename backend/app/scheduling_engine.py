from datetime import datetime, timedelta
from typing import Optional
from dataclasses import dataclass, field
import heapq


@dataclass
class InstructionObject:
    step_id: str
    recipe_id: int
    instruction: str
    category: str = "active"
    action_type: Optional[str] = None
    duration_minutes: int = 5
    tools: list[str] = field(default_factory=list)
    heat_source: Optional[str] = None
    temp_celsius: Optional[int] = None
    dependencies: list[str] = field(default_factory=list)
    concurrent_friendly: bool = False

    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None


@dataclass 
class KitchenResource:
    name: str
    resource_type: str
    heat_source: Optional[str] = None


@dataclass
class ScheduleConflict:
    conflict_type: str
    resource_a: str
    resource_b: str
    time_start: datetime
    time_end: datetime
    message: str


class SchedulingEngine:
    def __init__(self, resources: list[KitchenResource] | None = None):
        self.resources = resources or []
        self.conflicts: list[ScheduleConflict] = []

    def schedule(
        self,
        instructions: list[InstructionObject],
        target_time: datetime,
    ) -> tuple[list[InstructionObject], list[ScheduleConflict]]:
        active_steps = [i for i in instructions if i.category == "active"]
        passive_steps = [i for i in instructions if i.category == "passive"]

        heap = []
        for step in active_steps:
            heapq.heappush(heap, (self._latest_start(step, target_time), step))

        scheduled = []

        while heap:
            latest_start, current = heapq.heappop(heap)

            can_schedule = True
            for dep_id in current.dependencies:
                dep_step = next((s for s in instructions if s.step_id == dep_id), None)
                if dep_step and not dep_step.end_time:
                    can_schedule = False
                    break

            if not can_schedule:
                continue

            current.start_time = latest_start - timedelta(minutes=current.duration_minutes)
            current.end_time = latest_start
            scheduled.append(current)

        for step in instructions:
            if step.category == "passive" and not step.start_time:
                window = self._find_window_of_opportunity(scheduled, step.duration_minutes)
                if window:
                    step.start_time = window["start"]
                    step.end_time = window["end"]

        self.conflicts = self._detect_conflicts(scheduled)

        return instructions, self.conflicts

    def _latest_start(self, step: InstructionObject, target_time: datetime) -> datetime:
        for dep_id in step.dependencies:
            dep_step = next((s for s in [step] if s.step_id == dep_id), None)
            if dep_step and dep_step.end_time:
                return min(target_time, dep_step.end_time)
        return target_time

    def _find_window_of_opportunity(
        self,
        scheduled: list[InstructionObject],
        duration_minutes: int,
    ) -> dict | None:
        for i, active in enumerate(scheduled):
            if not active.start_time or not active.end_time:
                continue
            gap = (active.start_time - active.end_time).total_seconds() / 60
            if gap >= duration_minutes + 2:
                return {
                    "start": active.end_time,
                    "end": active.end_time + timedelta(minutes=duration_minutes),
                }
        return None

    def _detect_conflicts(
        self,
        scheduled: list[InstructionObject],
    ) -> list[ScheduleConflict]:
        conflicts = []
        by_heat_source: dict[str, list[tuple[datetime, datetime]]] = {}

        for step in scheduled:
            if not step.start_time or not step.end_time:
                continue
            if step.heat_source:
                if step.heat_source not in by_heat_source:
                    by_heat_source[step.heat_source] = []
                by_heat_source[step.heat_source].append(
                    (step.start_time, step.end_time)
                )

        for heat_source, intervals in by_heat_source.items():
            intervals.sort(key=lambda x: x[0])
            for i in range(len(intervals) - 1):
                if intervals[i][1] > intervals[i + 1][0]:
                    conflicts.append(
                        ScheduleConflict(
                            conflict_type="heat_source_overlap",
                            resource_a=heat_source,
                            resource_b=heat_source,
                            time_start=max(intervals[i][0], intervals[i + 1][0]),
                            time_end=min(intervals[i][1], intervals[i + 1][1]),
                            message=f"Two steps using {heat_source} overlap in time",
                        )
                    )

        return conflicts

    def create_schedule(
        self,
        recipes: list[dict],
        target_time_str: str,
    ) -> dict:
        from datetime import datetime as dt

        try:
            target_time = dt.fromisoformat(target_time_str)
        except ValueError:
            return {"error": "Invalid target time format"}

        instructions: list[InstructionObject] = []
        step_counter = 0

        for recipe in recipes:
            recipe_id = recipe.get("recipe_id", id(recipe))
            for step_data in recipe.get("steps", []):
                step_counter += 1
                step_id = f"s{step_counter}"
                instructions.append(
                    InstructionObject(
                        step_id=step_id,
                        recipe_id=recipe_id,
                        instruction=step_data.get("instruction", ""),
                        category=step_data.get("category", "active"),
                        action_type=step_data.get("action_type"),
                        duration_minutes=step_data.get("duration_minutes", 5),
                        tools=step_data.get("tools", []),
                        heat_source=step_data.get("heat_source"),
                        temp_celsius=step_data.get("temp_celsius"),
                        dependencies=[],
                    )
                )

        scheduled_steps, conflicts = self.schedule(instructions, target_time)

        time_blocks = []
        for step in scheduled_steps:
            if step.start_time and step.end_time:
                time_blocks.append({
                    "recipe_id": step.recipe_id,
                    "step_id": step.step_id,
                    "start_time": step.start_time.isoformat(),
                    "end_time": step.end_time.isoformat(),
                    "category": step.category,
                })

        return {
            "target_finish_time": target_time.isoformat(),
            "time_blocks": time_blocks,
            "conflicts": [
                {
                    "conflict_type": c.conflict_type,
                    "resource_a": c.resource_a,
                    "resource_b": c.resource_b,
                    "message": c.message,
                }
                for c in conflicts
            ],
        }