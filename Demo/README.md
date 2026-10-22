# SAP Business Ontology Demo

A side-by-side evaluation of two Cortex Agents on a realistic SAP procurement dataset:

- **Baseline Agent** — Semantic View only (tables, columns, joins, aggregations)
- **BON Agent** — Semantic View + Business Ontology via native `snowscope_search` (formulas, code meanings, cross-domain relationships)

**V1 result: Baseline 27% (3/11) vs BON 100% (11/11)**

> **Read this V1 number with care.** V1 compares BON against a *bare* semantic view (tables and joins, no metrics, synonyms or instructions). That overstates the uplift, because much of it comes from context a well-built semantic view would also carry. **V2 (below) is the fair test:** it measures BON against strong, enriched semantic views, so any uplift left is what BON adds on top of good semantic view practice.

The 8 questions Baseline fails all require business knowledge that doesn't fit in a semantic view — SAP code meanings, multi-step formulas, sign conventions, and cross-domain reasoning paths.

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
- **Business Ontology**: 29 glossary terms — 11 entity relationships, 7 SAP code-mapping terms, 11 authoritative formulas
- **Representations**: All 29 terms bound to physical objects (entities→tables, metrics→semantic view, code-mapping terms→columns)

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
2. **Searches BON index** — the `business_ontology` tool searches the glossary for relevant terms (COGS formula, material group code meanings, sign convention)
3. **Applies business context** — uses the returned formulas and code meanings to construct the correct SQL
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

---

## V2: How we measure BON uplift

V2 rebuilds the demo in schema `SAP_BON_V2` so the comparison is fair. Two principles:

- **Sense proposes, Ontology governs, SVs execute.** BON defines what a metric *means* and which implementation is canonical. Semantic views compute it.
- **BON is not a replacement for a good SV.** Each team gets a well-built semantic view. The question is what BON adds on top.

### Three arms, one variable

| Arm | Agent | Context |
|---|---|---|
| A | `BARE_AGENT` | 3 bare domain SVs (tables, joins, label comments) |
| B | `ENRICHED_AGENT` | 3 enriched domain SVs (metrics, synonyms, code values, instructions, verified queries) |
| C | `BON_AGENT` | the same 3 enriched SVs **+ native Business Ontology search** |

**BON uplift = C − B.** Same model, budget, response instructions and tool descriptions. The only difference is the `business_ontology` tool and a two-step instruction: look up the governed definition, then query.

Each team's SV is correct on its own terms, and the teams deliberately disagree, as real teams do:

| Question | Purchasing SV | Finance / Sales SV | Governed answer (BON) |
|---|---|---|---|
| Supplier count | `vendor_record_count` = 15 | `active_supplier_count` = 14 | **Supplier Count = 14** (ZPRB excluded by policy) |
| Revenue | — | `gross_bookings` = 746,000 (synonym "revenue") | **Revenue = net_revenue = 711,915** |
| On-time delivery | `carrier_otd_rate` = 90% | — | **On-Time Delivery Rate = 66.7%** |
| Cost of an assembly | `avg_standard_price` (STPRS 520) | — | **BOM Cost Rollup = 286.60** |

### What is in the ontology

- **3 domains:** Procurement, Finance & Controlling, Sales & Distribution.
- **39 nodes:** 13 ENTITY, 16 METRIC, 7 code-mapping TERM, 3 POLICY_CONCEPT.
  - Canonical metrics and their scoped variants: Supplier Count → Vendor Record Count; Revenue → Gross Bookings; On-Time Delivery Rate → Carrier Reported On-Time Rate.
  - Cross-domain metrics: Product Gross Margin, Customer Profit, Break-even Discount, Revenue at Risk.
  - One TERM per code field, each pointing at its reference table (T077K, T023T), never one node per code value.
- **49 typed relationships:** HAS_VARIANT, DERIVES, MEASURES, CLASSIFIES, APPLIES_TO, HAS_PART, RELATED_TO.
- **43 representations:**
  - IMPLEMENTS: canonical metric → the exact SV metric (field-level, including derived `net_revenue`).
  - RELATED_SEMANTIC_VIEW: cross-SV metric → every contributing SV.
  - REPRESENTS: entity → table.
  - DESCRIBES: code term → column.
  - REFERENCE_DATA: code term → code table.

### 18 questions, 4 tiers, mapped to value pillars

| Tier | Questions | Value pillar | Expected BON uplift |
|---|---|---|---|
| 1 Business rules in one SV | Q01–Q05 | baseline fairness | ~0: enriched SVs already handle these |
| 2 Conflicting definitions | Q06–Q09 | V1 canonical choice | which of two valid SV metrics is official |
| 3 Cross-SV reasoning | Q10–Q14 | V2 cross-domain | margin, profit, break-even, revenue at risk, safe spend cuts |
| 4 Governed meaning | Q15–Q18 | V3 governed meaning | definition, policy, and where it is implemented |

The scorecard also reports:
- **V4 consistency:** the Finance and Sales team agents answer the same question; do they agree?
- **V6 stability:** the same answer across 3 runs.
- **V7 cost:** latency and tool calls.
- **V8 traceability:** the answer names the governed term and its implementing SV metric.
- **Hedging:** two answers offered without committing to either. This is graded wrong.

Tier 1 is included on purpose: if BON showed large gains there, the baseline would be too weak.

### Run it

```bash
# Build (in order): sql/v2/01_schema_data.sql ... 07_agents.sql
# 05 and 06 are the ontology; approve the 39 drafted terms with their termIds (scoped form).

# Wait for the BON search index. Ontology edits can take up to 6 hours to become searchable.
SNOWFLAKE_CONNECTION_NAME=<conn> python benchmark/run_benchmark.py --check-index

# Full run: 18 questions x 3 arms x 3 runs + consistency pairs
SNOWFLAKE_CONNECTION_NAME=<conn> python benchmark/run_benchmark.py
```

The harness refuses to run until the index serves the new V2 nodes and has dropped the retired V1 nodes; otherwise it would measure stale content. Results go to `SAP_BON_V2.BENCHMARK_RESULTS` and `benchmark/scorecard_<run_id>.json`.

### Live scenarios (change management)

`sql/v2/08_live_scenarios.sql` covers what a one-off benchmark cannot:

- **S1 Change once:** a steward edits the Supplier Count definition. Every BON agent follows, with no SV or prompt edit.
- **S2 Drafts are never served:** an unapproved definition is invisible to agents until approved.
- **S3 SV rebuild:** a renamed SV metric breaks one IMPLEMENTS binding, which is detectable and fixable in one place.

### Known limits (Private Preview)

- Native BON search returns definitions, formulas and synonyms, **not representations**. The implementing SV metric reaches the agent only because each definition names it. A Cortex Sense context does ingest representations.
- Search reflects ontology edits and grants after an index refresh, which can take up to 6 hours.
- Search is account-wide across readable domains. Other projects' terms can appear, so the agent is told which domains to prefer.
- Owners and stewards cannot be set through the API; stewardship is recorded in the domain descriptions.
