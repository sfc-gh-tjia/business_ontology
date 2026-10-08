# SAP Business Ontology Demo

A side-by-side evaluation of two Cortex Agents on a realistic SAP procurement dataset:

- **Baseline Agent** — Semantic View only (tables, columns, joins, aggregations)
- **BON Agent** — Semantic View + Business Ontology via native `snowscope_search` (formulas, decoders, cross-domain relationships)

**Result: Baseline 27% (3/11) vs BON 100% (11/11)**

The 8 questions Baseline fails all require business knowledge that doesn't fit in a semantic view — SAP code decoders, multi-step formulas, sign conventions, and cross-domain reasoning paths.

## Prerequisites

- Snowflake account with ACCOUNTADMIN (or role with CREATE DATABASE, CREATE AGENT, glossary privileges)
- Business Ontology Private Preview feature flag enabled on your account
- Node.js 18+ and Python 3.10+ (for the web app)

## Setup

### 0. Business Ontology CoCo Skill (optional, for authoring)

The `business-ontology` CoCo skill provides natural-language commands to create and manage BON glossary domains, terms, and relationships. You can also create them directly in Snowsight or via SYSTEM$ SQL calls.

If using CoCo:
```bash
# Search for "business-ontology" in the CoCo skill marketplace, or install manually:
cp -r <path-to-skill>/business-ontology ~/.snowflake/cortex/skills/business-ontology
```

Once installed, you can use natural language in CoCo:
- `"create a domain called SAP Finance"`
- `"add a metric called COGS to SAP Finance"`
- `"ARR derives from Contracted ARR"`
- `"import ontology from our semantic views"`

### 1. Snowflake Objects (run SQL scripts in order)

```bash
# In Snowsight or SnowSQL, run each script sequentially:
sql/01_setup_database.sql        # Create database, schema, warehouse
sql/02_create_sap_tables.sql     # 15 SAP tables with data (266 rows)
sql/03_create_semantic_view.sql  # SAP_BASELINE_SV (14 tables, 12 relationships)
sql/04_create_agents.sql         # SAP_BASELINE_AGENT + BON_SV_NATIVE_AGENT
sql/05_create_bon_glossary.sql   # 3 domains, 29 terms, 8 relationships
```

> **Note:** The BON agent (`BON_SV_NATIVE_AGENT`) uses Snowflake's native `snowscope_search` with the `businessOntology` corpus — no custom stored procedure needed. The glossary terms (script 05) must be created and approved before the agent can search them.

### 2. Web App

```bash
cd Demo/web

# Backend (Flask API)
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Set your connection name (must match ~/.snowflake/config.toml)
export SNOWFLAKE_CONNECTION_NAME=default
python api_server.py             # Starts on http://localhost:5001

# Frontend (Next.js) — in a separate terminal
npm install
npm run dev                      # Starts on http://localhost:3000
```

Open http://localhost:3000 in your browser.

## Demo Walkthrough

### Context Tab
- **Source Tables**: 15 SAP tables, 266 rows across purchasing, finance, and sales
- **Semantic View**: SAP_BASELINE_SV connecting 14 tables with 12 FK relationships
- **Business Ontology**: 29 glossary terms — 11 entity relationships, 7 SAP code decoders, 11 authoritative formulas
- **Representations**: All 29 terms bound to physical objects (entities→tables, metrics→semantic view, decoders→columns)

### Comparison Tab
Select a question from the dropdown, click Ask, and compare both agents side by side. Recommended demo questions:

| Question | Tier | Why BON wins |
|----------|------|-------------|
| Q1: How many suppliers? | A | Business rule: exclude ZPRB probationary (14 not 15) |
| Q4: COGS for raw materials? | B | Sign convention: credit memos subtract ($1.29M not $1.35M) |
| Q9: Cut procurement 15%? | C | Constrained optimization: protect BOM inputs of highest-revenue product |

### Analysis Tab
Full scorecard with detailed breakdown of why baseline fails and BON succeeds for each question.

## Architecture

```
┌─────────────────────────┐     ┌──────────────────────┐
│   Next.js Frontend      │────▶│  Flask API (:5001)   │
│   localhost:3000        │     │  /api/agent           │
│                         │     └──────────┬───────────┘
│  Context | Demo | Analysis               │
└─────────────────────────┘                ▼
                              ┌──────────────────────┐
                              │  Snowflake            │
                              │  DATA_AGENT_RUN()     │
                              │                       │
                              │  SAP_BASELINE_AGENT   │
                              │    └─ SAP_BASELINE_SV │
                              │                       │
                              │  BON_SV_NATIVE_AGENT  │
                              │    ├─ SAP_BASELINE_SV │
                              │    └─ snowscope_search│
                              │       (businessOntology│
                              │        corpus)         │
                              └───────────────────────┘
```

## How the Native BON Agent Works

Instead of a custom stored procedure that bulk-dumps all glossary terms, the native approach uses Snowflake's built-in `snowscope_search` tool with the `businessOntology` corpus:

1. **Agent receives a question** — e.g., "What is COGS for raw materials?"
2. **Searches BON index** — the `business_ontology` tool searches the glossary for relevant terms (COGS formula, material group decoder, sign convention)
3. **Applies business context** — uses the returned formulas and decoders to construct the correct SQL
4. **Queries data** — calls `query_sap` (Cortex Analyst) with business-informed SQL
5. **Returns answer** — with both the governed formula and the data result

This is more efficient than the SP approach because:
- **Search-based**: Retrieves only relevant terms per question, not all 29
- **No custom code**: No Python SP to maintain — BON glossary is the single source of truth
- **Auto-indexed**: Glossary changes are reflected automatically

## Key Insight

SV teaches the agent *how to query* — tables, columns, joins.
BON teaches the agent *what the answer means* — business formulas, code translations, domain relationships.
Without BON, the agent writes correct SQL that produces wrong answers.
