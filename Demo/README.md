# SAP Business Ontology Demo

A side-by-side evaluation of two Cortex Agents on a realistic SAP procurement dataset:

- **Baseline Agent** — Semantic View only (tables, columns, joins, aggregations)
- **BON Agent** — Semantic View + Business Ontology (formulas, decoders, cross-domain relationships)

**Result: Baseline 27% (3/11) vs BON 100% (11/11)**

The 8 questions Baseline fails all require business knowledge that doesn't fit in a semantic view — SAP code decoders, multi-step formulas, sign conventions, and cross-domain reasoning paths.

## Prerequisites

- Snowflake account with ACCOUNTADMIN (or role with CREATE DATABASE, CREATE AGENT, glossary privileges)
- A named connection in `~/.snowflake/config.toml`
- Node.js 18+ and Python 3.10+

## Setup

### 0. Business Ontology CoCo Skill (required)

Install the `business-ontology` skill in Cortex Code before proceeding — it is required to create and manage BON glossary domains, terms, and relationships:

```bash
# From the Cortex Code skills catalog:
# Search for "business-ontology" in the skill marketplace, or install manually:
cp -r <path-to-skill>/business-ontology ~/.snowflake/cortex/skills/business-ontology
```

The skill requires the **Business Ontology Private Preview** feature flag to be enabled on your account. Contact your Snowflake account team for enablement.

Once installed, you can use natural language in CoCo:
- `"create a domain called SAP Finance"`
- `"add a metric called COGS to SAP Finance"`
- `"ARR derives from Contracted ARR"`
- `"import ontology from our semantic views"`

### 1. Snowflake Objects (run SQL scripts in order)

```bash
# In Snowsight or SnowSQL, run each script sequentially:
sql/01_setup_database.sql       # Create database, schema, warehouse
sql/02_create_sap_tables.sql    # 15 SAP tables with data (266 rows)
sql/03_create_semantic_view.sql # SAP_BASELINE_SV (14 tables, 12 relationships)
sql/04_create_bon_context_sp.sql # SP_GET_SAP_BON_CONTEXT stored procedure
sql/05_create_agents.sql        # SAP_BASELINE_AGENT + SAP_BON_AGENT
```

### 2. BON Glossary (for Snowsight visualization)

```bash
sql/06_create_bon_glossary.sql  # 3 domains, 29 terms, 8 relationships
```

This script uses `SYSTEM$DRAFT_GLOSSARY_TERM` and `SYSTEM$APPROVE_GLOSSARY_TERM`. Each DRAFT call returns a `termId` — you must pass it to the corresponding APPROVE call. Run the statements one at a time and note the returned IDs.

**Optional: Bind terms to physical objects (representations).** This links glossary terms to their tables/columns/SV in the Snowflake catalog for lineage and governance. Not required for the agent demo. Use the business-ontology CoCo skill:

```
$business-ontology In the SAP Purchasing domain, associate the entity Supplier with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.LFA1
```

See `getting-started-business-ontology.md` Phase 7 for all 29 representation prompts.

### 3. Web App

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
│                         │     │  /api/context         │
│  Context | Demo | Analysis    └──────────┬───────────┘
└─────────────────────────┘                │
                                           ▼
                              ┌──────────────────────┐
                              │  Snowflake            │
                              │  DATA_AGENT_RUN()     │
                              │                       │
                              │  SAP_BASELINE_AGENT   │
                              │    └─ SAP_BASELINE_SV │
                              │                       │
                              │  SAP_BON_AGENT        │
                              │    ├─ SAP_BASELINE_SV │
                              │    └─ SP_GET_SAP_BON_ │
                              │       CONTEXT()       │
                              └───────────────────────┘
```

## Key Insight

SV teaches the agent *how to query* — tables, columns, joins.
BON teaches the agent *what the answer means* — business formulas, code translations, domain relationships.
Without BON, the agent writes correct SQL that produces wrong answers.
