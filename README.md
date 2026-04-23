# Kitchen Mission Control (Working Title)

An iOS-native companion app designed for culinary enthusiasts who manage complex, multi-dish meals. Unlike traditional recipe apps that act as static filing cabinets, **Kitchen Mission Control** serves as a dynamic orchestration engine.

---

## 1. The Vision & Market Moat

### The Problem
Most home cooks struggle with "Kitchen Chaos"—the cognitive load of timing multiple recipes so they finish simultaneously. Existing apps like Paprika or Mela store recipes but do nothing to help the user execute them in parallel.

### The Solution (The Moat)
The core of this project is a **Proprietary Scheduling Engine**. It interleaves the steps of multiple recipes into a single, unified timeline based on user bandwidth (active vs. passive time) and kitchen resource availability (stove/oven/tools).

---

## 2. MVP Roadmap (Investor-Prioritized)

### Phase 1: The "Conductor" (P0)
* **AI-Native Web Scraping:** Seamless extraction from any URL using LLM-based parsing.
* **The Orchestrator:** A backward-scheduling algorithm that calculates "Start Times" for every step based on a "Target Finish Time."
* **Active/Passive Logic:** Detecting "Windows of Opportunity" (e.g., dicing onions for Recipe B while Recipe A is simmering).

### Phase 2: The "Expert" (P1)
* **The "Why" Chat:** An AI assistant that explains culinary science (e.g., "Why are we searing this meat?") to help users level up.
* **Unified Timer Dashboard:** Integrated, stage-specific timers that track multiple concurrent processes.
* **Conflict Detection:** Immediate alerts for tool or temperature collisions.

### Phase 3: The "Seamless" (P2)
* **Social Import:** Advanced scraping for Instagram/TikTok Reels via OCR and caption parsing.
* **Thermal Compromise:** AI-suggested oven temperature adjustments when two recipes conflict.

---

## 3. Technical Architecture

### A. Data Ingestion (Scraping)
To minimize maintenance and maximize site compatibility, the app bypasses brittle CSS selectors in favor of an AI-first approach:
1.  **Jina Reader API:** Converts the recipe URL into clean, LLM-ready Markdown.
2.  **Gemini 1.5 Flash:** Extracts structured data from the Markdown, identifying "Active" vs "Passive" steps and durations.

### B. Core Data Model: The Instruction Object
Each recipe is decomposed into a series of objects that power the scheduling engine:

```json
{
  "step_id": "s1",
  "instruction": "Sear the steak in a hot pan.",
  "category": "active", 
  "action_type": "heat",
  "duration_minutes": 6,
  "requirements": {
    "tools": ["heavy skillet", "tongs"],
    "heat_source": "stovetop",
    "temp_celsius": null
  },
  "dependencies": ["prep_step_id"],
  "concurrent_friendly": false
}