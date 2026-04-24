# Kitchen Mission Control — Architecture Plan

## Overview

An iOS-native companion app for culinary enthusiasts managing complex, multi-dish meals. The core moat is a **Proprietary Scheduling Engine** that interleaves recipe steps into a unified timeline based on active vs passive time and kitchen resource availability.

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend Framework | FastAPI + Python 3.11 |
| Database | PostgreSQL 16 (Docker embedded) |
| Reverse Proxy | Traefik v3 + Let's Encrypt SSL |
| AI Parsing | Jina Reader API → Gemini 1.5 Flash |
| Container Orchestration | Docker Compose |

---

## Infrastructure Topology

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│      Home Server (Dev)          │     │       Oracle Cloud (Prod)        │
│  ┌───────────────────────────┐  │     │  ┌───────────────────────────┐  │
│  │  Docker + Traefik + SSL   │  │ ──▶ │  │  Docker + Traefik + SSL   │  │
│  │  FastAPI Backend          │  │     │  │  FastAPI Backend          │  │
│  │  PostgreSQL (local)       │  │     │  │  PostgreSQL               │  │
│  └───────────────────────────┘  │     │  └───────────────────────────┘  │
└─────────────────────────────────┘     └─────────────────────────────────┘
```

---

## Project Structure

```
kitchen-mission-control/
├── backend/
│   ├── Dockerfile
│   ├── docker-compose.yml        # traefik + backend + postgres
│   ├── traefik.yml               # HTTP→HTTPS, auto SSL
│   └── app/
│       ├── main.py               # FastAPI entry point
│       ├── scheduling_engine.py  # ⭐ Core moat: backward-scheduler + conflict detection
│       ├── recipe_parser.py      # ⭐ Jina → Gemini extraction
│       ├── step_classifier.py    # Active/Passive step classification
│       │
│       ├── routers/
│       │   ├── recipes.py        # GET/POST /v1/recipes/*
│       │   ├── schedule.py       # POST /v1/schedule/create, GET /v1/schedule/{id}
│       │   └── parse.py          # POST /v1/parse/url
│       │
│       └── models/
│           ├── recipe.py         # Recipe, Step, Ingredient (SQLAlchemy)
│           └── schedule.py       # Schedule, TimeBlock, KitchenResource
```

---

## Data Model: Instruction Object

Each recipe is decomposed into steps that power the scheduling engine:

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
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/parse/url` | Scrape URL → Jina → Gemini → Structured Recipe |
| POST | `/v1/schedule/create` | Create unified timeline for N recipes + target time |
| GET | `/v1/schedule/{id}` | Get computed schedule with start times per step |
| POST | `/v1/recipes/` | Save recipe to DB |
| GET | `/v1/recipes/` | List user's recipes |

---

## Scheduling Algorithm

### Backward-Scheduling Logic
1. Given: N recipes, target finish time, kitchen resources (stove/oven/tools)
2. Flatten all steps with (active/passive classification, duration, tools, heat_source)
3. Sort by latest_start_time (backward from target)
4. Insert passive-steps into "Windows of Opportunity" where user is doing active work on another recipe
5. Detect conflicts: same tool + same time slot → alert
6. Return unified timeline with start_times per step

### Conflict Detection Rules
- No two steps can use the same `heat_source` at overlapping times
- Tool exclusivity: e.g., only one recipe can use stand mixer at a time
- Temperature collisions for oven-based recipes

---

## Implementation Phases

### Phase 1: Backend Core ✅
- [x] Create backend/ directory structure + Dockerfile + docker-compose.yml
- [x] Implement SQLAlchemy models (Recipe, Step)
- [x] Wire up FastAPI with health endpoint
- [x] Configure Traefik with auto SSL

### Phase 2: AI Parsing ⏳ IN PROGRESS
- [ ] Build recipe_parser.py — Jina Reader → Markdown → Gemini extraction
- [ ] Implement step_classifier.py — Active vs Passive step detection
- [ ] Add /v1/parse/url endpoint

### Phase 3: Scheduling Engine ⭐ CORE MOAT
- [ ] Design InstructionObject model matching README spec
- [ ] Build scheduling_engine.py:
  - Backward-scheduling algorithm (target time → start times)
  - Insert passive steps into "Windows of Opportunity"
  - Conflict detection (tool/heat_source collisions)
- [ ] Add /v1/schedule/create endpoint

### Phase 4: iOS Fork ⏳ PENDING
- Pending Figma designs from user

---

## Deployment Flow

```bash
# Dev (Home Server) or Prod (Oracle VM) — same commands
cd backend && docker compose up -d
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `GEMINI_API_KEY` | Google AI Studio API key |
| `JINA_API_KEY` | Jina Reader API key |

---

## Prerequisites for Deployment

- [ ] Gemini API key from Google AI Studio
- [ ] Jina API key from jina.ai/reader
- [ ] Docker + Docker Compose installed on server
- [ ] (Optional) Domain with DNS pointed to server