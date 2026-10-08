# Getting Started with Business Ontology

> **Private Preview** — Business Ontology must be enabled on your Snowflake account before use. Contact your Snowflake account team or SE.

---

## What is Business Ontology?

Business Ontology is Snowflake's governed vocabulary layer. It lets you define what business concepts mean — metrics, entities, decoder tables, formulas — and how they relate to each other. Once defined, Cortex Agents use this knowledge to answer questions that require understanding beyond raw table schemas.

**The core problem it solves:** A Semantic View teaches an agent *how to query* (tables, columns, joins). Business Ontology teaches it *what the answer means* (which vendors count as "canonical", how to handle credit memos, what formula to use for COGS).

<!-- VISUAL: SV vs BON comparison cards (see getting-started-business-ontology.html, DIAGRAM 1) -->

```
Semantic View alone                 Semantic View + Business Ontology
─────────────────────               ─────────────────────────────────
"How many suppliers?"               "How many suppliers?"
→ COUNT(*) FROM LFA1 = 15           → COUNT(DISTINCT LIFNR) FROM LFA1
  (wrong — includes probationary)     WHERE KTOKK IN ('ZSTR','ZSTD') = 14
                                      (correct — excludes probationary per policy)
```

---

## Prerequisites

| Requirement | Details |
|---|---|
| **Snowflake account** | Business Ontology feature flag enabled (Private Preview) |
| **Cortex Code (CoCo)** | Desktop app with skills support |
| **BON CoCo Skill** | Installed at `~/.snowflake/cortex/skills/business-ontology/` |
| **Role** | ACCOUNTADMIN (or role with glossary API access) |
| **Your data** | Tables already loaded in Snowflake |

### Install the CoCo Skill

**Option 1 — From the Cortex Extension catalog (if available in your account):**

In CoCo, type:
```
/find-skill business-ontology
```
Follow the prompts to install. This is the preferred method when the skill is published to your account's catalog.

**Option 2 — Manual install (Private Preview):**

If the skill is not yet in the catalog, obtain the `business-ontology/` folder from your Snowflake account team or SE, then copy it:
```bash
cp -r /path/to/business-ontology ~/.snowflake/cortex/skills/business-ontology
```

Restart CoCo. The skill auto-loads when you use natural language triggers like "create a domain" or "add a metric".

---

## What You'll Build

<!-- VISUAL: Stat cards grid (see getting-started-business-ontology.html, "What You'll Build" section) -->
<!-- 3 Domains | 11 Entities | 11 Metrics | 7 Decoders | 8 Relationships | 29 Representations -->

By the end of this guide you will have:

| Object | Count | Purpose |
|---|---|---|
| **Domains** | 3 | Group concepts by business area |
| **Entity nodes** | 11 | Business objects (Supplier, Material, PO, etc.) |
| **Metric nodes** | 11 | Formulas with business rules (COGS, OTD, Risk, etc.) |
| **Decoder terms** | 7 | SAP field code mappings (MATKL, BSCHL, HKONT, etc.) |
| **Relationships** | 8 | Cross-domain connections (Supplier→Material, PO→AP, etc.) |
| **Representations** | 29 | Bind terms to physical Snowflake objects (optional for agent, recommended for governance) |
| **Cortex Agent** | 1 | Uses native BON search + Semantic View to answer questions |
| **Cortex Agent** | 1 | Uses ontology context + Semantic View to answer questions |

---

## End-to-End Process

<!-- VISUAL: 7-phase workflow flowchart (see getting-started-business-ontology.html, DIAGRAM 2) -->
<!-- Phase 1 → Phase 2 → Phase 3 (key differentiator) → Phase 4 → Phase 5 → Phase 6 → Phase 7 (optional) -->

### Phase 1: Create Domains

Domains group related business concepts. One domain per business area.

Open CoCo and type this prompt. The `$business-ontology` prefix ensures the skill is invoked:

```
$business-ontology Create three domains: SAP Purchasing, SAP Finance, SAP Sales
```

> **What happens behind the scenes:** The skill calls `SYSTEM$CREATE_GLOSSARY_DOMAIN()` for each domain. No draft/approve needed for domains — they're created immediately.

---

### Phase 2: Add Entity Nodes

Entities are business objects — things that exist and can be counted or listed. They have descriptions but no formulas. Give the skill the entity name, domain, and a description that includes key field mappings.

```
$business-ontology Add the following entities:

SAP Purchasing domain:
1. Supplier — Vendor master (LFA1). 15 vendors with LIFNR vendor number.
   KTOKK account group: ZSTR=Strategic, ZSTD=Standard, ZPRB=Probationary.
   Exclude ZPRB from canonical counts.
2. Material — Material master (MARA). MATKL material group codes:
   043=Electronics, 044=Chemicals, 045=Metals, 046=Packaging, 047=Raw Materials.
   STPRS is standard price in USD.
3. Purchase Order — Purchasing document item (EKPO). STATU status codes:
   O=Open, C=Closed, R=Received. NETWR=net value USD, MENGE=quantity.
4. Shipment — Delivery/shipment (LIKP). Compare WADAT (actual delivery) vs
   LFDAT (expected delivery) for operational OTD. Do NOT use LFA2.OTRAT
   which is carrier self-reported and unreliable.
5. Carrier — Forwarding agent (LFA2). VSART shipping type:
   01=Ocean, 02=FTL, 03=Air, 04=Intermodal, 05=LTL.
   OTRAT is self-reported OTD — unreliable, do not use for real OTD calculation.
6. Inspection — Quality inspection lot (QALS). VCODE result:
   A=Accepted, R=Rejected, C=Conditional. QAESSION = defect rate percentage.
7. BOM Item — Bill of Materials component (STPO). STLNR=parent assembly,
   IDNRK=child component, MENGE=quantity per assembly.
   4-level recursive hierarchy enables cost rollup.

SAP Finance domain:
8. AP Line Item — Accounting document line (BSEG). BSCHL posting key:
   31=Invoice (positive, add to totals), 34=Credit memo (negative, SUBTRACT).
   HKONT=GL account. DMBTR=amount in local currency.
9. Cost Posting — Cost element posting (COEP). OBJNR cost object codes:
   KS-MFG-US=US Manufacturing, KS-MFG-EU=EU Manufacturing,
   KS-MFG-AP=APAC Manufacturing, KS-LOG=Logistics, KS-QA=Quality.
   KSTAR=cost element, WRTBTR=amount.

SAP Sales domain:
10. Sales Order — Sales document item (VBAP). VKORG sales org:
    1000=Americas, 2000=EMEA, 3000=APAC. NETWR=net value, KWMENG=quantity.
    KUNNR=customer number.
11. Pricing Condition — Pricing condition record (KONV). KSCHL condition type:
    PR00=Base price, K007=Customer discount (REDUCES revenue, KWERT is negative),
    KF00=Freight surcharge (ADDS to revenue, KWERT is positive).
```

> **What happens:** For each entity, the skill calls `SYSTEM$DRAFT_GLOSSARY_TERM({...})` with `itemKind: "ENTITY"`, shows you the draft, then calls `SYSTEM$APPROVE_GLOSSARY_TERM(termId)` when you confirm.

---

### Phase 3: Add Metric Nodes (with Formulas)

Metrics include a `formula` field — this is where you encode the business logic that a Semantic View cannot express. Give the skill the metric name, domain, formula, and a description that explains the business rule.

```
$business-ontology Add the following metrics with formulas:

SAP Purchasing domain:
1. Canonical Supplier Count
   Formula: COUNT(DISTINCT LIFNR) FROM LFA1 WHERE KTOKK IN ('ZSTR','ZSTD')
   Description: Excludes ZPRB probationary vendors per business policy. Answer is 14, not 15.

2. Operational OTD Rate
   Formula: COUNT(CASE WHEN WADAT <= LFDAT THEN 1 END) / COUNT(*) FROM LIKP WHERE STATU='D'
   Description: Real delivery on-time rate from actual vs expected dates.
   WARNING: Do NOT use LFA2.OTRAT — that is carrier self-reported (~90%) and unreliable.
   Real OTD is approximately 66.7%.

3. Total Procurement Spend
   Formula: SUM(NETWR) FROM EKPO
   Description: Use EKPO.NETWR (PO line values) only.
   NOT LFB1.JWERT — those are annual contract values which are much larger.

4. Weighted Supply Risk Score
   Formula: 0.4 * single_source_flag + 0.3 * defect_rate + 0.3 * delivery_failure_rate
   Description: Fixed business policy weights — DO NOT change.
   Highest risk material is MAT-006 at 0.70.

5. Supplier Disruption Cascade
   Formula: Recursive chain: Supplier -> EKPO(materials) -> STPO(recursive BOM upward) -> affected assemblies
   Description: Traces which assemblies are affected when a supplier is disrupted.
   Uses recursive CTE on STPO traversing upward from IDNRK to STLNR.
   This is a 5-hop cross-domain traversal from supplier to revenue impact.

6. BOM Cost Rollup
   Formula: Recursive CTE on STPO downward (STLNR->IDNRK), multiply MENGE at each level, JOIN MARA.STPRS for leaf node costs
   Description: True material cost via recursive BOM explosion.
   For ASSY-004: $286.60/unit. Do NOT use the assembly STPRS ($520) — that includes overhead markup.

SAP Finance domain:
7. COGS Raw Materials
   Formula: SUM(CASE WHEN BSCHL='31' THEN DMBTR WHEN BSCHL='34' THEN -DMBTR END) FROM BSEG WHERE HKONT='0040100000'
   Description: CRITICAL: BSCHL=31 (invoice) is POSITIVE. BSCHL=34 (credit memo) must be SUBTRACTED.
   Credit memos represent quality returns and adjustments. Ignoring them overstates COGS.
   Correct answer: $1,290,020. Wrong answer without sign logic: $1,353,690 or $1,417,360.

8. Product Gross Margin
   Formula: VBAP.NETWR - (BOM_Cost_Rollup * VBAP.KWMENG)
   Description: Cross-domain formula spanning Sales -> Purchasing -> Finance.
   Revenue from VBAP minus material COGS from recursive BOM cost rollup times units sold.
   No direct FK connects VBAP to BSEG — the chain goes through BOM.

9. Cost Center Total
   Formula: SUM(WRTBTR) FROM COEP WHERE OBJNR = cost_object_code
   Description: Total cost allocated to a specific cost center.
   OBJNR decoder: KS-MFG-US=US Manufacturing ($419,750), KS-MFG-EU=EU Manufacturing,
   KS-MFG-AP=APAC Manufacturing, KS-LOG=Logistics, KS-QA=Quality Assurance.

SAP Sales domain:
10. Discount Leakage
    Formula: SUM(ABS(KWERT)) FROM KONV WHERE KSCHL='K007'
    Description: Customer discounts only (K007). KWERT values are NEGATIVE for discounts.
    EXCLUDE KF00 (freight surcharges) — those ADD to revenue, not reduce it.
    EXCLUDE PR00 (base prices) — those are not discounts.

11. Disruption Revenue Impact
    Formula: Sum of VBAP.NETWR for all assemblies identified by Supplier Disruption Cascade
    Description: Revenue at risk from supplier disruption. Uses the Disruption Cascade
    output (affected assemblies) then looks up their sales revenue in VBAP.
```

> **What happens:** For each metric, the skill calls `SYSTEM$DRAFT_GLOSSARY_TERM({...})` with `itemKind: "METRIC"` and the `formula` field populated. The formula is stored as metadata on the term. The skill shows you the draft, then approves when you confirm.

---

### Phase 4: Add Decoder Terms

Decoders map SAP field codes to human-readable business meanings. They use `itemKind: "TERM"` and have no formula.

```
$business-ontology Add the following decoder terms:

SAP Purchasing domain:
1. MATKL Material Group Decoder — SAP material group codes:
   043=Electronics, 044=Chemicals, 045=Metals, 046=Packaging, 047=Raw Materials, 048=Assembly
2. KTOKK Account Group Decoder — SAP vendor account groups:
   ZSTR=Strategic partner, ZSTD=Standard vendor, ZPRB=Probationary (exclude from active counts)

SAP Finance domain:
3. BSCHL Posting Key Decoder — SAP posting keys:
   31=Vendor invoice (positive, add to totals), 34=Credit memo (negative, SUBTRACT from totals)
4. HKONT GL Account Decoder — SAP GL accounts:
   0040100000=COGS Raw Materials, 0040200000=COGS Freight, 0021100000=Accounts Payable
5. OBJNR Cost Object Decoder — SAP cost objects:
   KS-MFG-US=US Manufacturing, KS-MFG-EU=EU Manufacturing, KS-MFG-AP=APAC Manufacturing,
   KS-LOG=Logistics, KS-QA=Quality Assurance

SAP Sales domain:
6. KSCHL Condition Type Decoder — SAP pricing condition types:
   PR00=Base/list price, K007=Customer discount (include in discount calculations),
   KF00=Freight surcharge (EXCLUDE from discount calculations)
7. VKORG Sales Org Decoder — SAP sales organizations:
   1000=Americas, 2000=EMEA, 3000=APAC
```

---

### Phase 5: Define Relationships

Relationships connect entities across and within domains. Tell the skill the source, target, and relationship type.

> **Relationship type guidance (per skill best practices):**
> - `RELATED_TO` is the general-purpose type — use when no other type fits precisely
> - `HAS_PART` — target is a structural component of source (Material has part BOM Item)
> - `MEASURES` — source is a metric that quantifies target (Inspection measures Material)
> - Prefer specific types over `RELATED_TO` when the semantics are clear. The skill's quality gate (`R-00`) validates that only supported types are used.

You can define all 8 relationships in a single prompt:

```
$business-ontology Define the following relationships:
- Supplier is related to Material
- Material has part BOM Item
- Purchase Order is related to Supplier
- Carrier is related to Shipment
- Inspection is related to Material
- Purchase Order is related to AP Line Item (cross-domain: Purchasing → Finance)
- AP Line Item is related to Cost Posting (cross-domain: Finance)
- Sales Order is related to Material (cross-domain: Sales → Purchasing)
```

<!-- VISUAL: Entity relationship graph with 3 domain subgraphs (see getting-started-business-ontology.html, DIAGRAM 3) -->
<!-- Shows: SAP Purchasing (7 entities), SAP Finance (2 entities), SAP Sales (2 entities) with 8 cross-domain edges -->

> **What happens:** For each prompt, the skill calls `SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP(sourceTermId, targetTermId, 'RELATED_TO')` using the termIds it stored from Phase 2. It shows the draft, then calls `SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP(relId)` when you confirm.

> **Note:** The skill tracks termIds internally. You don't need to look up or paste IDs — just use the term names. If the skill can't resolve a name, it will ask you to disambiguate.

---

### Phase 6: Verify Your Ontology

After all terms and relationships are created, verify by querying the glossary:

```
$business-ontology Show me all the terms in the SAP Purchasing domain
```

**Validation (recommended per skill best practices):**

Verify the full graph landed correctly — drafted relationships are invisible until approved, so always confirm via the graph:

```sql
-- Verify the complete ontology graph
SELECT SYSTEM$GET_GLOSSARY_GRAPH();
```

Check the counts match expectations (29 terms, 8 relationships). If the relationship count is lower than expected, some may still be in DRAFT state — approve them with:

```sql
SELECT SYSTEM$APPROVE_ALL_GLOSSARY_RELATIONSHIPS();
```

Spot-check a specific metric term to verify its formula:

```sql
SELECT
  PARSE_JSON(SYSTEM$GET_GLOSSARY_TERM('<termId>')):"name"::STRING as name,
  PARSE_JSON(SYSTEM$GET_GLOSSARY_TERM('<termId>')):"itemKind"::STRING as kind,
  PARSE_JSON(SYSTEM$GET_GLOSSARY_TERM('<termId>')):"formula"::STRING as formula,
  PARSE_JSON(SYSTEM$GET_GLOSSARY_TERM('<termId>')):"description"::STRING as description;
```

Expected result for a metric term:

| name | kind | formula | description |
|---|---|---|---|
| COGS Raw Materials | METRIC | SUM(CASE WHEN BSCHL='31' THEN DMBTR...) | Credit memos subtract... |

---

### Phase 7: Bind Terms to Physical Objects (Representations)

Representations link glossary terms to the Snowflake objects they describe. This is **optional for agent behavior** (the agent reads formulas from the SP, not from catalog metadata) but **required for production governance** — catalog discoverability, lineage tracing, impact analysis, and coverage tracking.

> **Terminology:** The product calls these "representations." The underlying API uses `ASSOCIATION` / `ASSET`. Never say "binding."

**Entities → Tables** (1 prompt for all 11):

```
$business-ontology Associate all entities with their source tables:
- SAP Purchasing: Supplier → LFA1, Material → MARA, Purchase Order → EKPO,
  Shipment → LIKP, Carrier → LFA2, Inspection → QALS, BOM Item → STPO
- SAP Finance: AP Line Item → BSEG, Cost Posting → COEP
- SAP Sales: Sales Order → VBAP, Pricing Condition → KONV
All tables are in DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION
```

**Metrics → Semantic View** (1 prompt for all 11):

```
$business-ontology Associate all metrics with semantic view
DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV:
- SAP Purchasing: Canonical Supplier Count, Operational OTD Rate,
  Total Procurement Spend, Weighted Supply Risk Score,
  Supplier Disruption Cascade, BOM Cost Rollup
- SAP Finance: COGS Raw Materials, Product Gross Margin, Cost Center Total
- SAP Sales: Discount Leakage, Disruption Revenue Impact
```

**Decoders → Columns** (1 prompt for all 7):

```
$business-ontology Associate all decoder terms with their source columns:
- SAP Purchasing: KTOKK Account Group Decoder → column KTOKK in LFA1,
  MATKL Material Group Decoder → column MATKL in MARA
- SAP Finance: BSCHL Posting Key Decoder → column BSCHL in BSEG,
  HKONT GL Account Decoder → column HKONT in BSEG,
  OBJNR Cost Object Decoder → column OBJNR in COEP
- SAP Sales: KSCHL Condition Type Decoder → column KSCHL in KONV,
  VKORG Sales Org Decoder → column VKORG in VBAP
All tables are in DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION
```

<!-- VISUAL: Representations binding flowchart (see getting-started-business-ontology.html, DIAGRAM 4) -->
<!-- Shows: 11 Entities → TABLE, 11 Metrics → SEMANTIC_VIEW, 7 Decoders → COLUMN -->

> **What happens:** The skill calls `SYSTEM$CREATE_GLOSSARY_ASSOCIATION()` for each term, linking it to the physical object. Entities bind with `RELATED_TABLE` role, metrics with `RELATED_SEMANTIC_VIEW`, decoders with `RELATED_TABLE` (column refType).

> **With vs without representations:**
> | Capability | Without | With |
> |---|---|---|
> | Agent answers questions | Works | Same — no change |
> | Catalog shows term → table link | No | Yes |
> | Lineage traces concept → object | No | Yes |
> | "Which tables are governed?" | Can't answer | 11/15 tables linked |
> | "If I drop LFA1, what concepts break?" | Can't answer | Supplier, Carrier, KTOKK Decoder |

---

## Surfacing Ontology Through a Cortex Agent

The glossary is the single source of truth. Snowflake's native `snowscope_search` tool searches the glossary index directly — no custom stored procedure needed. Update a term in the glossary and the agent finds the new definition on the next question.

### How It Works

<!-- VISUAL: Agent inference flow diagram (see getting-started-business-ontology.html, DIAGRAM 5) -->

```
User Question
      ↓
Cortex Agent
      ↓  searches business_ontology tool (native glossary search)
      ↓
Snowflake's built-in search index over all approved BON terms
  → finds relevant definitions, formulas, decoders, relationships
      ↓
Agent reads formulas, writes SQL accordingly
      ↓  calls query_data tool
      ↓
Semantic View translates to SQL, executes
      ↓
Correct Answer (grounded in live glossary terms)
```

### Step A: Confirm Your Ontology Is Searchable

Before creating the agent, verify that your approved terms are indexed. In a CoCo terminal:

```bash
cortex search object "supplier count metric" --types=business-ontology
```

Check that the results include your domain-qualified names, kinds, definitions, and formulas. If no results appear, check that your terms are approved (not draft), your role has domain access, and the search index is current.

### Step B: Create the Semantic View

The Semantic View defines the queryable surface — tables, columns, joins:

```sql
CREATE OR REPLACE SEMANTIC VIEW MY_BASELINE_SV
  COMMENT = 'Baseline — tables, columns, joins only'
AS (
  TABLES (LFA1, MARA, EKPO, LIKP, BSEG, COEP, VBAP, KONV, ...)
  RELATIONSHIPS (
    EKPO (LIFNR) REFERENCES LFA1 (LIFNR),
    EKPO (MATNR) REFERENCES MARA (MATNR),
    BSEG (EBELN) REFERENCES EKPO (EBELN),
    VBAP (MATNR) REFERENCES MARA (MATNR),
    ...
  )
);
```

### Step C: Create the BON Agent

The agent has **two tools**: a native BON search tool for business definitions and a Semantic View for data queries. The `experimental.EnableSnowscopeBusinessOntologySearch` flag enables the BON search corpus.

```sql
CREATE OR REPLACE AGENT MY_BON_AGENT
  COMMENT = 'Agent with native Business Ontology search + Semantic View data queries'
  PROFILE = '{"display_name": "BON Assistant"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  experimental:
    EnableSnowscopeBusinessOntologySearch: true

  orchestration:
    budget:
      seconds: 90
      tokens: 24000

  instructions:
    response: |
      You are an enterprise analytics assistant with access to governed
      business definitions from Business Ontology. When answering:
      - Show the governed formula from BON, then the query result from data.
      - If BON provides a formula, USE IT to guide your SQL generation.
      - Pay attention to sign logic, code decoders, and cross-domain chains.
      - Never invent a formula. If BON returns no formula, say so.
      - Always show your reasoning.
    orchestration: |
      CRITICAL WORKFLOW for every question:

      STEP 1: Call business_ontology FIRST to get governed definitions,
      formulas, and decoders relevant to the question.

      STEP 2: Use the BON context to understand what field codes mean
      and which formula applies.

      STEP 3: Call query_data to run the actual data query, using the
      formula and decoder knowledge from BON.

      If the question is purely about definitions (what does X mean?),
      answer from BON alone without querying data.

      If a lookup returns nothing, retry once with a likely synonym,
      then report the miss rather than guessing.

  tools:
    - tool_spec:
        type: snowscope_search
        name: business_ontology
        description: |
          Search Business Ontology for governed business terms, metrics,
          entities, and decoders. Returns definitions, formulas, synonyms,
          and domain context. Call this FIRST before any data query.
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: query_data
        description: "Query production data."

  tool_resources:
    business_ontology:
      corpus: businessOntology
    query_data:
      semantic_view: "MY_DATABASE.MY_SCHEMA.MY_BASELINE_SV"
      execution_environment:
        type: "warehouse"
        warehouse: "MY_WAREHOUSE"
  $$;
```

Three settings are required and not validated at create time — a misspelling is accepted silently:
- `experimental.EnableSnowscopeBusinessOntologySearch: true`
- `tools[].tool_spec.type: snowscope_search`
- `tool_resources.business_ontology.corpus: businessOntology`

After creation, run `DESCRIBE AGENT MY_BON_AGENT` and check the `agent_spec` JSON for these values.

### Key Agent Design Decisions

| Setting | Baseline Agent | BON Agent | Why |
|---|---|---|---|
| Tools | 1 (text-to-sql) | 2 (snowscope_search + text-to-sql) | BON needs the ontology search tool |
| BON search | No | `snowscope_search` with `businessOntology` corpus | Native integration — no custom SP needed |
| Token budget | 16,000 | 24,000 | BON search results add context tokens |
| Time budget | 60s | 90s | Two tool calls instead of one |
| Instructions | Generic | "search BON first, then query" | Must enforce "context first" pattern |

---

## Updating and Enriching Your Ontology

### Add New Terms

```
$business-ontology Add a metric called Net Revenue to SAP Sales.
Formula: SUM(KWERT) FROM KONV WHERE KSCHL IN ('PR00','KF00') + SUM(KWERT) FROM KONV WHERE KSCHL='K007'
Description: Base price + surcharges + discounts (discounts are negative).
```

### Modify Existing Terms

To update a term's description or formula, draft a new version:

```
$business-ontology Update the Canonical Supplier Count metric — change the description to:
Excludes ZPRB probationary and ZTMP temporary vendors. Answer: 12.
```

### Add More Relationships

```
$business-ontology Define a relationship: Canonical Supplier Count measures Supplier
```

```
$business-ontology Define a relationship: COGS Raw Materials derives from BOM Cost Rollup
```

### Discover Missing Relationships

```
$business-ontology Find more relationships in the SAP Finance domain
```

The skill analyzes existing nodes and suggests edges you might have missed (e.g., "Cost Center Total MEASURES Cost Posting").

### Import from Existing Semantic Views

If you already have Semantic Views, the skill can bootstrap your ontology from them:

```
$business-ontology Bootstrap ontology from our semantic views
```

The skill scans your SV estate, extracts business concepts from table/column names and comments, proposes nodes, and lets you review before committing.

### Import from dbt

```
$business-ontology Extract ontology from our dbt manifest at @my_stage/manifest.json
```

### Bulk Import from CSV

```
$business-ontology Import ontology terms from @my_stage/terms.csv
```

---

## Formulas: SV Metrics vs BON Formulas

| Aspect | SV Metric | BON Formula |
|---|---|---|
| **Scope** | Single-column aggregation | Multi-table, conditional, recursive |
| **Logic** | `SUM(NETWR)`, `AVG(STPRS)` | `CASE WHEN BSCHL='31' THEN DMBTR ELSE -DMBTR END` |
| **Cross-domain** | No (within one SV) | Yes (Sales → Purchasing → Finance) |
| **Business rules** | None | Exclusions, sign logic, policy weights |
| **Composability** | No | Yes — Gross Margin references BOM Cost Rollup |
| **Where stored** | Semantic View YAML | Glossary (SYSTEM$ API) — searched by native `snowscope_search` |
| **Who reads it** | Cortex Analyst (text-to-sql) | The LLM agent (as guidance for writing SQL) |

### How Formulas Flow

<!-- VISUAL: Formula flow diagram (see getting-started-business-ontology.html, DIAGRAM 6) -->

```
Glossary (SYSTEM$ API)              Native Search Index           Agent
────────────────────                ───────────────────           ─────
METRIC term with                    Snowflake indexes all          Agent's snowscope_search
"formula": "COUNT(DISTINCT     →    approved BON terms         →   finds relevant terms and
LIFNR) FROM LFA1 WHERE             automatically.                  reads formula text,
KTOKK IN ('ZSTR','ZSTD')"          No custom SP needed.            then writes:
                                                                    SELECT COUNT(DISTINCT LIFNR)
Single source of truth.             Search-based retrieval.         FROM LFA1
Updated via skill or SQL.           Always current with             WHERE KTOKK IN ('ZSTR','ZSTD')
                                    approved terms.
```

The formula is **guidance for the LLM**, not executable code. The glossary stores it, the native search index delivers it, and the agent uses it to write the correct SQL.

---

## Architecture Summary

<!-- VISUAL: Architecture summary diagram (see getting-started-business-ontology.html, DIAGRAM 7) -->

```
┌─────────────────────────────────────────────────────────────┐
│                     BUSINESS ONTOLOGY                       │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │Purchasing│  │ Finance  │  │  Sales   │  ← 3 Domains    │
│  │ 15 terms │  │ 8 terms  │  │ 6 terms  │                 │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                 │
│       │              │              │                       │
│       └──── 8 cross-domain relationships ───┘              │
│                                                             │
│  11 ENTITY nodes (no formula)                              │
│  11 METRIC nodes (with formula — the key differentiator)   │
│   7 TERM decoders (field code mappings)                    │
├─────────────────────────────────────────────────────────────┤
│                DELIVERY MECHANISM                           │
│                                                             │
│  Native snowscope_search with businessOntology corpus:     │
│    • Agent searches glossary index per question             │
│    • Returns relevant definitions, formulas, decoders       │
│    • No custom SP needed — Snowflake manages the index     │
│    • Always current with approved terms                     │
├─────────────────────────────────────────────────────────────┤
│                   CORTEX AGENT                              │
│                                                             │
│  Tool 1: business_ontology → snowscope_search (BON first)  │
│  Tool 2: query_data → text-to-SQL via Semantic View        │
│                                                             │
│  Agent flow: search BON → understand formulas → write SQL  │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Reference: CoCo Skill Prompts

| Task | Exact Prompt |
|---|---|
| Create domain | `$business-ontology Create a domain called <name>` |
| Add entity | `$business-ontology Add an entity called <name> to <domain>. Description: <text>` |
| Add metric | `$business-ontology Add a metric called <name> to <domain>. Formula: <sql>. Description: <text>` |
| Add decoder | `$business-ontology Add a term called <name> to <domain>. Description: <code mappings>` |
| Add relationship | `$business-ontology Define a relationship: <source> is related to <target>` |
| Add HAS_PART | `$business-ontology Define a relationship: <parent> has part <child>` |
| Add DERIVES | `$business-ontology Define a relationship: <derived> derives from <source>` |
| Add MEASURES | `$business-ontology Define a relationship: <metric> measures <entity>` |
| Import from SVs | `$business-ontology Bootstrap ontology from our semantic views` |
| Import from dbt | `$business-ontology Extract ontology from our dbt manifest at <path>` |
| Import from CSV | `$business-ontology Import ontology terms from <stage_path>` |
| Find relationships | `$business-ontology Find more relationships in the <domain> domain` |
| Delete domain | `$business-ontology Delete the <domain> domain` |
| Associate entity→table | `$business-ontology In the <domain> domain, associate the entity <name> with table <FQN>` |
| Associate metric→SV | `$business-ontology In the <domain> domain, associate the metric <name> with semantic view <FQN>` |
| Associate decoder→column | `$business-ontology In the <domain> domain, associate the term <name> with column <col> in table <FQN>` |

---

## API Reference

| Operation | SYSTEM$ Call |
|---|---|
| Create domain | `SYSTEM$CREATE_GLOSSARY_DOMAIN('domain_name')` |
| Draft term | `SYSTEM$DRAFT_GLOSSARY_TERM('{"domainName":"...", "name":"...", "itemKind":"ENTITY|METRIC|TERM", "description":"...", "formula":"..."}')` |
| Approve term | `SYSTEM$APPROVE_GLOSSARY_TERM('<termId>')` |
| Draft relationship | `SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP('<sourceTermId>', '<targetTermId>', '<relType>')` |
| Approve relationship | `SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP('<relId>')` |
| Get term | `SYSTEM$GET_GLOSSARY_TERM('<termId>')` |

**Gotchas:**
- `itemKind` not `termType` — field name matters
- Only `METRIC` terms support the `formula` field
- Relationships use **positional args**, not JSON: `('sourceId', 'targetId', 'RELATED_TO')`
- Single quotes in JSON must be escaped as `''` in SQL

---

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| `Unknown function SYSTEM$CREATE_GLOSSARY_DOMAIN` | Feature flag not enabled | Contact your Snowflake account team |
| `Invalid identifier` in formula | Single quotes not escaped | Use `''` inside SQL strings within JSON |
| Relationship draft fails | Wrong API format | Use positional args, not JSON object |
| Agent ignores formulas | Instructions don't enforce context-first | Add STEP 1/2/3/4 orchestration instructions |
| Formula returns wrong number | Credit memo / exclusion logic missing | Check BON formula — it encodes sign logic |
| Agent uses OTRAT instead of computing OTD | No warning about unreliable self-reported data | Add WARNING in formula description |
| Skill can't find a term by name | Ambiguous name across domains | Use full name or specify domain |

---

## Bootstrap from Existing Knowledge

<!-- VISUAL: Bootstrap entry points flowchart (see getting-started-business-ontology.html, DIAGRAM 8) -->

You don't have to start from scratch. The skill supports three entry points depending on what you already have:

### 1. Existing Documents or Business Glossary

If your organization already has definitions in a spreadsheet, markdown file, wiki, or data dictionary — import them directly. The skill extracts concepts, synonyms, and proposed relationships from your source material.

```
$business-ontology Import ontology terms from @my_stage/business_glossary.csv
```

```
$business-ontology Extract glossary terms from this document: @my_stage/data_dictionary.md
```

**What it does:**
- Reads definitions from your file (CSV, markdown, or staged document)
- Proposes entities, metrics, and terms with descriptions
- Suggests relationships based on co-occurrence and naming patterns
- Presents everything for review — you approve or edit before committing

**Best for:** Organizations that already maintain a data dictionary, business glossary spreadsheet, or domain knowledge wiki.

### 2. Existing Semantic Views

If you already have Semantic Views in Snowflake, the skill can reverse-engineer business concepts from them — table names, column comments, join patterns, and VQR descriptions all become candidate ontology nodes.

```
$business-ontology Bootstrap ontology from our semantic views
```

**What it does:**
- Scans your SV estate (all semantic views in the account)
- Extracts business concepts from table/column names, comments, and join relationships
- Deduplicates across multiple SVs (the same concept in two SVs becomes one node)
- Reconciles shared concepts and proposes business relationships
- Detects drift between existing glossary terms and SV definitions
- Presents candidates for review — you approve, edit, or skip

```
$business-ontology Find drift between ontology and semantic views
```

**Best for:** Teams that have already invested in Semantic Views and want to layer governed business meaning on top without re-entering definitions.

### 3. Business Expertise (Conversational)

If your knowledge lives in people's heads rather than documents, describe the domain and let the skill draft terms with AI assistance. Domain experts review and approve — they don't need to write JSON or SQL.

```
$business-ontology I need to build an ontology for our supply chain procurement domain.
We track vendors, purchase orders, materials, and shipments.
Key metrics are supplier count (excluding probationary), on-time delivery rate,
and total procurement spend. We use SAP with coded fields like KTOKK and MATKL.
```

**What it does:**
- AI extracts entities, metrics, and decoders from your description
- Proposes formulas based on the business rules you describe
- Suggests relationships between concepts
- Drafts everything — domain experts review and approve

```
$business-ontology Add more context: our COGS calculation must subtract credit memos
(BSCHL=34) from invoices (BSCHL=31). Ignoring credit memos overstates COGS by ~10%.
```

**Best for:** Greenfield projects, domain-specific knowledge that isn't documented, or teams where the business expert and the data engineer are different people.

### Choosing Your Entry Point

| You have... | Start with | Prompt |
|---|---|---|
| CSV/spreadsheet of definitions | Path 1: Import | `$business-ontology Import ontology terms from @stage/file.csv` |
| Semantic Views in Snowflake | Path 2: Bootstrap from SVs | `$business-ontology Bootstrap ontology from our semantic views` |
| dbt project with descriptions | Path 2 variant: Import from dbt | `$business-ontology Extract ontology from our dbt manifest at @stage/manifest.json` |
| Domain knowledge (not documented) | Path 3: Conversational | `$business-ontology I need to build an ontology for <your domain>...` |
| Cortex Sense context already built | Promote to glossary | `$business-ontology Promote our <context_name> context to the ontology` |
| Nothing yet | Phase 1–5 above | Follow the step-by-step prompts in this guide |

All paths converge to the same result: governed glossary terms with formulas, connected by relationships, ready to surface through a Cortex Agent.
