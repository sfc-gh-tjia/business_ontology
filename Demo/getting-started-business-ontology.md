# Getting Started with Business Ontology

> **Private Preview** — Business Ontology must be enabled on your Snowflake account before use. Contact your Snowflake account team or SE.

---

## What is Business Ontology?

Business Ontology is Snowflake's governed vocabulary layer. It lets you define what business concepts mean — metrics, entities, decoder tables, formulas — and how they relate to each other. Once defined, Cortex Agents use this knowledge to answer questions that require understanding beyond raw table schemas.

**The core problem it solves:** A Semantic View teaches an agent *how to query* (tables, columns, joins). Business Ontology teaches it *what the answer means* (which vendors count as "canonical", how to handle credit memos, what formula to use for COGS).

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

By the end of this guide you will have:

| Object | Count | Purpose |
|---|---|---|
| **Domains** | 3 | Group concepts by business area |
| **Entity nodes** | 11 | Business objects (Supplier, Material, PO, etc.) |
| **Metric nodes** | 11 | Formulas with business rules (COGS, OTD, Risk, etc.) |
| **Decoder terms** | 7 | SAP field code mappings (MATKL, BSCHL, HKONT, etc.) |
| **Relationships** | 8 | Cross-domain connections (Supplier→Material, PO→AP, etc.) |
| **Context SP** | 1 | Delivers ontology to agent at runtime |
| **Cortex Agent** | 1 | Uses ontology context + Semantic View to answer questions |

---

## End-to-End Process

### Phase 1: Create Domains

Domains group related business concepts. One domain per business area.

Open CoCo and type these prompts one at a time. The `$business-ontology` prefix ensures the skill is invoked:

```
$business-ontology Create a domain called SAP Purchasing
```

```
$business-ontology Create a domain called SAP Finance
```

```
$business-ontology Create a domain called SAP Sales
```

> **What happens behind the scenes:** The skill calls `SYSTEM$CREATE_GLOSSARY_DOMAIN('SAP Purchasing')` for each domain. No draft/approve needed for domains — they're created immediately.

---

### Phase 2: Add Entity Nodes

Entities are business objects — things that exist and can be counted or listed. They have descriptions but no formulas. Give the skill the entity name, domain, and a description that includes key field mappings.

**Purchasing domain — 7 entities:**

```
$business-ontology Add an entity called Supplier to SAP Purchasing.
Description: Vendor master (LFA1). 15 vendors with LIFNR vendor number.
KTOKK account group: ZSTR=Strategic, ZSTD=Standard, ZPRB=Probationary.
Exclude ZPRB from canonical counts.
```

```
$business-ontology Add an entity called Material to SAP Purchasing.
Description: Material master (MARA). MATKL material group codes:
043=Electronics, 044=Chemicals, 045=Metals, 046=Packaging, 047=Raw Materials.
STPRS is standard price in USD.
```

```
$business-ontology Add an entity called Purchase Order to SAP Purchasing.
Description: Purchasing document item (EKPO). STATU status codes:
O=Open, C=Closed, R=Received. NETWR=net value USD, MENGE=quantity.
```

```
$business-ontology Add an entity called Shipment to SAP Purchasing.
Description: Delivery/shipment (LIKP). Compare WADAT (actual delivery) vs
LFDAT (expected delivery) for operational OTD. Do NOT use LFA2.OTRAT
which is carrier self-reported and unreliable.
```

```
$business-ontology Add an entity called Carrier to SAP Purchasing.
Description: Forwarding agent (LFA2). VSART shipping type:
01=Ocean, 02=FTL, 03=Air, 04=Intermodal, 05=LTL.
OTRAT is self-reported OTD — unreliable, do not use for real OTD calculation.
```

```
$business-ontology Add an entity called Inspection to SAP Purchasing.
Description: Quality inspection lot (QALS). VCODE result:
A=Accepted, R=Rejected, C=Conditional. QAESSION = defect rate percentage.
```

```
$business-ontology Add an entity called BOM Item to SAP Purchasing.
Description: Bill of Materials component (STPO). STLNR=parent assembly,
IDNRK=child component, MENGE=quantity per assembly.
4-level recursive hierarchy enables cost rollup.
```

**Finance domain — 2 entities:**

```
$business-ontology Add an entity called AP Line Item to SAP Finance.
Description: Accounting document line (BSEG). BSCHL posting key:
31=Invoice (positive, add to totals), 34=Credit memo (negative, SUBTRACT).
HKONT=GL account. DMBTR=amount in local currency.
```

```
$business-ontology Add an entity called Cost Posting to SAP Finance.
Description: Cost element posting (COEP). OBJNR cost object codes:
KS-MFG-US=US Manufacturing, KS-MFG-EU=EU Manufacturing,
KS-MFG-AP=APAC Manufacturing, KS-LOG=Logistics, KS-QA=Quality.
KSTAR=cost element, WRTBTR=amount.
```

**Sales domain — 2 entities:**

```
$business-ontology Add an entity called Sales Order to SAP Sales.
Description: Sales document item (VBAP). VKORG sales org:
1000=Americas, 2000=EMEA, 3000=APAC. NETWR=net value, KWMENG=quantity.
KUNNR=customer number.
```

```
$business-ontology Add an entity called Pricing Condition to SAP Sales.
Description: Pricing condition record (KONV). KSCHL condition type:
PR00=Base price, K007=Customer discount (REDUCES revenue, KWERT is negative),
KF00=Freight surcharge (ADDS to revenue, KWERT is positive).
```

> **What happens:** For each prompt, the skill calls `SYSTEM$DRAFT_GLOSSARY_TERM({...})` with `itemKind: "ENTITY"`, shows you the draft, then calls `SYSTEM$APPROVE_GLOSSARY_TERM(termId)` when you confirm.

---

### Phase 3: Add Metric Nodes (with Formulas)

Metrics include a `formula` field — this is where you encode the business logic that a Semantic View cannot express. Give the skill the metric name, domain, formula, and a description that explains the business rule.

**Purchasing domain — 6 metrics:**

```
$business-ontology Add a metric called Canonical Supplier Count to SAP Purchasing.
Formula: COUNT(DISTINCT LIFNR) FROM LFA1 WHERE KTOKK IN ('ZSTR','ZSTD')
Description: Excludes ZPRB probationary vendors per business policy. Answer is 14, not 15.
```

```
$business-ontology Add a metric called Operational OTD Rate to SAP Purchasing.
Formula: COUNT(CASE WHEN WADAT <= LFDAT THEN 1 END) / COUNT(*) FROM LIKP WHERE STATU='D'
Description: Real delivery on-time rate calculated from actual vs expected dates.
WARNING: Do NOT use LFA2.OTRAT — that is carrier self-reported (~90%) and unreliable.
Real OTD is approximately 66.7%.
```

```
$business-ontology Add a metric called Total Procurement Spend to SAP Purchasing.
Formula: SUM(NETWR) FROM EKPO
Description: Use EKPO.NETWR (PO line values) only.
NOT LFB1.JWERT — those are annual contract values which are much larger.
```

```
$business-ontology Add a metric called Weighted Supply Risk Score to SAP Purchasing.
Formula: 0.4 * single_source_flag + 0.3 * defect_rate + 0.3 * delivery_failure_rate
Description: Fixed business policy weights — DO NOT change.
Highest risk material is MAT-006 at 0.70.
```

```
$business-ontology Add a metric called Supplier Disruption Cascade to SAP Purchasing.
Formula: Recursive chain: Supplier -> EKPO(materials) -> STPO(recursive BOM upward) -> affected assemblies
Description: Traces which assemblies are affected when a supplier is disrupted.
Uses recursive CTE on STPO traversing upward from IDNRK to STLNR.
This is a 5-hop cross-domain traversal from supplier to revenue impact.
```

```
$business-ontology Add a metric called BOM Cost Rollup to SAP Purchasing.
Formula: Recursive CTE on STPO downward (STLNR->IDNRK), multiply MENGE at each level, JOIN MARA.STPRS for leaf node costs
Description: True material cost via recursive BOM explosion.
For ASSY-004: $286.60/unit. Do NOT use the assembly STPRS ($520) — that includes overhead markup.
```

**Finance domain — 3 metrics:**

```
$business-ontology Add a metric called COGS Raw Materials to SAP Finance.
Formula: SUM(CASE WHEN BSCHL='31' THEN DMBTR WHEN BSCHL='34' THEN -DMBTR END) FROM BSEG WHERE HKONT='0040100000'
Description: CRITICAL: BSCHL=31 (invoice) is POSITIVE. BSCHL=34 (credit memo) must be SUBTRACTED.
Credit memos represent quality returns and adjustments. Ignoring them overstates COGS.
Correct answer: $1,290,020. Wrong answer without sign logic: $1,353,690 or $1,417,360.
```

```
$business-ontology Add a metric called Product Gross Margin to SAP Finance.
Formula: VBAP.NETWR - (BOM_Cost_Rollup * VBAP.KWMENG)
Description: Cross-domain formula spanning Sales -> Purchasing -> Finance.
Revenue from VBAP minus material COGS from recursive BOM cost rollup times units sold.
No direct FK connects VBAP to BSEG — the chain goes through BOM.
```

```
$business-ontology Add a metric called Cost Center Total to SAP Finance.
Formula: SUM(WRTBTR) FROM COEP WHERE OBJNR = cost_object_code
Description: Total cost allocated to a specific cost center.
OBJNR decoder: KS-MFG-US=US Manufacturing ($419,750), KS-MFG-EU=EU Manufacturing,
KS-MFG-AP=APAC Manufacturing, KS-LOG=Logistics, KS-QA=Quality Assurance.
```

**Sales domain — 2 metrics:**

```
$business-ontology Add a metric called Discount Leakage to SAP Sales.
Formula: SUM(ABS(KWERT)) FROM KONV WHERE KSCHL='K007'
Description: Customer discounts only (K007). KWERT values are NEGATIVE for discounts.
EXCLUDE KF00 (freight surcharges) — those ADD to revenue, not reduce it.
EXCLUDE PR00 (base prices) — those are not discounts.
```

```
$business-ontology Add a metric called Disruption Revenue Impact to SAP Sales.
Formula: Sum of VBAP.NETWR for all assemblies identified by Supplier Disruption Cascade
Description: Revenue at risk from supplier disruption. Uses the Disruption Cascade
output (affected assemblies) then looks up their sales revenue in VBAP.
```

> **What happens:** For each prompt, the skill calls `SYSTEM$DRAFT_GLOSSARY_TERM({...})` with `itemKind: "METRIC"` and the `formula` field populated. The formula is stored as metadata on the term. The skill shows you the draft, then approves when you confirm.

---

### Phase 4: Add Decoder Terms

Decoders map SAP field codes to human-readable business meanings. They use `itemKind: "TERM"` and have no formula.

**Purchasing domain — 2 decoders:**

```
$business-ontology Add a term called MATKL Material Group Decoder to SAP Purchasing.
Description: SAP material group codes: 043=Electronics, 044=Chemicals,
045=Metals, 046=Packaging, 047=Raw Materials, 048=Assembly
```

```
$business-ontology Add a term called KTOKK Account Group Decoder to SAP Purchasing.
Description: SAP vendor account groups: ZSTR=Strategic partner,
ZSTD=Standard vendor, ZPRB=Probationary (exclude from active counts)
```

**Finance domain — 3 decoders:**

```
$business-ontology Add a term called BSCHL Posting Key Decoder to SAP Finance.
Description: SAP posting keys: 31=Vendor invoice (positive, add to totals),
34=Credit memo (negative, SUBTRACT from totals)
```

```
$business-ontology Add a term called HKONT GL Account Decoder to SAP Finance.
Description: SAP GL accounts: 0040100000=COGS Raw Materials,
0040200000=COGS Freight, 0021100000=Accounts Payable
```

```
$business-ontology Add a term called OBJNR Cost Object Decoder to SAP Finance.
Description: SAP cost objects: KS-MFG-US=US Manufacturing,
KS-MFG-EU=EU Manufacturing, KS-MFG-AP=APAC Manufacturing,
KS-LOG=Logistics, KS-QA=Quality Assurance
```

**Sales domain — 2 decoders:**

```
$business-ontology Add a term called KSCHL Condition Type Decoder to SAP Sales.
Description: SAP pricing condition types: PR00=Base/list price,
K007=Customer discount (include in discount calculations),
KF00=Freight surcharge (EXCLUDE from discount calculations)
```

```
$business-ontology Add a term called VKORG Sales Org Decoder to SAP Sales.
Description: SAP sales organizations: 1000=Americas, 2000=EMEA, 3000=APAC
```

---

### Phase 5: Define Relationships

Relationships connect entities across and within domains. Tell the skill the source, target, and relationship type.

**Within Purchasing:**

```
$business-ontology Define a relationship: Supplier is related to Material
```

```
$business-ontology Define a relationship: Material has part BOM Item
```

```
$business-ontology Define a relationship: Purchase Order is related to Supplier
```

```
$business-ontology Define a relationship: Carrier is related to Shipment
```

```
$business-ontology Define a relationship: Inspection is related to Material
```

**Cross-domain (Purchasing → Finance):**

```
$business-ontology Define a relationship: Purchase Order is related to AP Line Item
```

```
$business-ontology Define a relationship: AP Line Item is related to Cost Posting
```

**Cross-domain (Sales → Purchasing):**

```
$business-ontology Define a relationship: Sales Order is related to Material
```

> **What happens:** For each prompt, the skill calls `SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP(sourceTermId, targetTermId, 'RELATED_TO')` using the termIds it stored from Phase 2. It shows the draft, then calls `SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP(relId)` when you confirm.

> **Note:** The skill tracks termIds internally. You don't need to look up or paste IDs — just use the term names. If the skill can't resolve a name, it will ask you to disambiguate.

---

### Phase 6: Verify Your Ontology

After all terms and relationships are created, verify by querying the glossary:

```
$business-ontology Show me all the terms in the SAP Purchasing domain
```

Or query a specific metric to see its formula:

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

**Entities → Tables:**

```
$business-ontology In the SAP Purchasing domain, associate the entity Supplier with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.LFA1
```

```
$business-ontology In the SAP Purchasing domain, associate the entity Material with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.MARA
```

```
$business-ontology In the SAP Purchasing domain, associate the entity Purchase Order with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.EKPO
```

```
$business-ontology In the SAP Purchasing domain, associate the entity Shipment with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.LIKP
```

```
$business-ontology In the SAP Purchasing domain, associate the entity Carrier with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.LFA2
```

```
$business-ontology In the SAP Purchasing domain, associate the entity Inspection with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.QALS
```

```
$business-ontology In the SAP Purchasing domain, associate the entity BOM Item with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.STPO
```

```
$business-ontology In the SAP Finance domain, associate the entity AP Line Item with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.BSEG
```

```
$business-ontology In the SAP Finance domain, associate the entity Cost Posting with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.COEP
```

```
$business-ontology In the SAP Sales domain, associate the entity Sales Order with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.VBAP
```

```
$business-ontology In the SAP Sales domain, associate the entity Pricing Condition with table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.KONV
```

**Metrics → Semantic View:**

```
$business-ontology In the SAP Purchasing domain, associate the metric Canonical Supplier Count with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Purchasing domain, associate the metric Operational On-Time Delivery with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Purchasing domain, associate the metric Total Procurement Spend with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Purchasing domain, associate the metric Weighted Supply Risk Score with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Purchasing domain, associate the metric Supplier Disruption Cascade with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Purchasing domain, associate the metric BOM Cost Rollup with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Finance domain, associate the metric COGS Raw Materials with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Finance domain, associate the metric Product Gross Margin with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Finance domain, associate the metric Cost Center Total with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Sales domain, associate the metric Discount Leakage with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

```
$business-ontology In the SAP Sales domain, associate the metric Disruption Revenue Impact with semantic view DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
```

**Decoders → Columns:**

```
$business-ontology In the SAP Purchasing domain, associate the term KTOKK Account Group Decoder with column KTOKK in table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.LFA1
```

```
$business-ontology In the SAP Purchasing domain, associate the term MATKL Material Group Decoder with column MATKL in table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.MARA
```

```
$business-ontology In the SAP Finance domain, associate the term BSCHL Posting Key Decoder with column BSCHL in table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.BSEG
```

```
$business-ontology In the SAP Finance domain, associate the term HKONT GL Account Decoder with column HKONT in table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.BSEG
```

```
$business-ontology In the SAP Finance domain, associate the term OBJNR Cost Object Decoder with column OBJNR in table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.COEP
```

```
$business-ontology In the SAP Sales domain, associate the term KSCHL Condition Type Decoder with column KSCHL in table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.KONV
```

```
$business-ontology In the SAP Sales domain, associate the term VKORG Sales Org Decoder with column VKORG in table DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.VBAP
```

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

The glossary is the single source of truth. The SP reads from it dynamically via `SYSTEM$GET_GLOSSARY_TERM()` — no hardcoded business logic, no dual maintenance. Update a term in the glossary and the agent uses the new definition on the next question.

### How It Works

```
User Question
      ↓
Cortex Agent
      ↓  calls get_bon_context tool FIRST
      ↓
Stored Procedure dynamically calls SYSTEM$GET_GLOSSARY_TERM()
  → reads all 29 terms from the glossary at runtime
  → assembles: entities, decoders, formulas, relationships
      ↓
Agent reads formulas, writes SQL accordingly
      ↓  calls query_data tool
      ↓
Semantic View translates to SQL, executes
      ↓
Correct Answer (grounded in live glossary terms)
```

### Step A: Create the Context Stored Procedure

The SP dynamically reads all ontology terms from the glossary at runtime using `SYSTEM$GET_GLOSSARY_TERM()`. This means **you never hardcode business logic** — when you add, update, or remove a glossary term, the agent picks it up automatically on the next call.

```sql
CREATE OR REPLACE PROCEDURE SP_GET_BON_CONTEXT()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS CALLER
AS $$
def run(session):
    import json

    # Step 1: Retrieve ALL glossary terms dynamically via SYSTEM$ API
    # Known term IDs — each is fetched LIVE from the glossary at runtime.
    # After creating new terms via the skill, add their IDs here.
    TERM_IDS = [
        # Paste your term IDs here after creating them.
        # Example from the SAP demo (29 terms):
        # '32015320777', '32015320837', '32015320841', ...
    ]

    all_terms = []
    term_by_id = {}
    for tid in TERM_IDS:
        try:
            row = session.sql(f"SELECT SYSTEM$GET_GLOSSARY_TERM('{tid}')").collect()
            term = json.loads(row[0][0])
            if not term.get('error', True):
                all_terms.append(term)
                term_by_id[term['termId']] = term
        except:
            pass

    # Step 2: Organize by kind
    entities = [t for t in all_terms if t['itemKind'] == 'ENTITY']
    metrics  = [t for t in all_terms if t['itemKind'] == 'METRIC']
    decoders = [t for t in all_terms if t['itemKind'] == 'TERM']

    # Collect relationships (deduplicated)
    seen_edges = set()
    relationships = []
    for t in all_terms:
        for edge in t.get('relationships', {}).get('edges', []):
            edge_key = (edge['sourceTermId'], edge['targetTermId'], edge['relationshipType'])
            if edge_key not in seen_edges:
                seen_edges.add(edge_key)
                src = term_by_id.get(edge['sourceTermId'], {}).get('name', '?')
                tgt = term_by_id.get(edge['targetTermId'], {}).get('name', '?')
                relationships.append({'source': src, 'target': tgt, 'type': edge['relationshipType']})

    # Step 3: Build context string in 3 categories for agent inference
    lines = []
    lines.append("=== BUSINESS ONTOLOGY CONTEXT ===")
    lines.append(f"Dynamically retrieved: {len(all_terms)} terms, "
                 f"{len(entities)} entities, {len(metrics)} formulas, "
                 f"{len(decoders)} decoders, {len(relationships)} relationships")

    # CATEGORY 1: CODE DECODERS — interpret coded field values
    lines.append("\n" + "=" * 50)
    lines.append(f"CATEGORY 1: SAP CODE DECODERS ({len(decoders)} decoders)")
    lines.append("=" * 50)
    lines.append("Use these to interpret coded field values in SAP tables.")
    for d in sorted(decoders, key=lambda x: x['name']):
        field = d['name'].split()[0]
        lines.append(f"\n{field}: {d['description']}")

    # CATEGORY 2: FORMULAS — authoritative business metric calculations
    lines.append("\n" + "=" * 50)
    lines.append(f"CATEGORY 2: AUTHORITATIVE BUSINESS FORMULAS ({len(metrics)} formulas)")
    lines.append("=" * 50)
    lines.append("If a formula exists for the question, USE IT EXACTLY.")
    for i, m in enumerate(sorted(metrics, key=lambda x: x['name']), 1):
        lines.append(f"\nFORMULA {i} - {m['name']}:")
        if m.get('formula'):
            lines.append(f"  SQL/LOGIC: {m['formula']}")
        lines.append(f"  RULE: {m['description']}")

    # CATEGORY 3: ENTITY RELATIONSHIPS — cross-domain connections
    lines.append("\n" + "=" * 50)
    lines.append(f"CATEGORY 3: ENTITY RELATIONSHIPS ({len(relationships)} relationships)")
    lines.append("=" * 50)
    lines.append("Cross-domain connections for multi-hop reasoning.")
    lines.append("\nENTITIES:")
    for e in sorted(entities, key=lambda x: x['domain']['name'] + x['name']):
        lines.append(f"  [{e['domain']['name']}] {e['name']}: {e['description']}")
    lines.append("\nRELATIONSHIP MAP:")
    for r in relationships:
        lines.append(f"  {r['source']} --[{r['type']}]--> {r['target']}")

    lines.append("\n=== END BUSINESS ONTOLOGY CONTEXT ===")
    return "\n".join(lines)
$$;
```

**What the agent receives at inference time — 3 categories:**

| Category | Count | Purpose at inference time |
|---|---|---|
| **Code Decoders** | 7 | Interpret SAP field codes (KTOKK, BSCHL, HKONT, etc.) — agent knows what `ZPRB` means |
| **Formulas** | 11 | Authoritative SQL/logic for each metric — agent uses these instead of guessing |
| **Relationships** | 8 | Cross-domain entity connections — agent traces multi-hop chains (Supplier → BOM → Sales) |

**Key benefit:** The SP calls `SYSTEM$GET_GLOSSARY_TERM()` for every term at runtime. Update a formula in the glossary via the skill → the agent uses the new formula on the next question. No SP redeployment. The glossary is the single source of truth.

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

The agent has **two tools**: the Semantic View for querying and the SP for business context. The instructions enforce a "context first, then query" pattern:

```sql
CREATE OR REPLACE AGENT MY_BON_AGENT
  COMMENT = 'Agent with Business Ontology context'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  orchestration:
    budget:
      seconds: 90
      tokens: 24000
  instructions:
    response: "You are a business analyst with access to Business Ontology knowledge
      that decodes field codes and provides authoritative metric formulas.
      Always show your reasoning and SQL queries used."
    orchestration: |
      CRITICAL WORKFLOW - Follow these steps for EVERY question:

      STEP 1 - ALWAYS call get_bon_context FIRST before any data query.
      This returns field decoders and business metric formulas.

      STEP 2 - USE THE CONTEXT to understand what field codes mean
      (e.g., KTOKK='ZSTR' means Strategic Supplier).

      STEP 3 - If the context provides a specific formula for the question,
      USE THAT FORMULA exactly. Do NOT write your own SQL.

      STEP 4 - Call query_data with SQL that follows the formula logic.
      NEVER guess field meanings — always check the context first.
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "query_data"
        description: "Query production data."
    - tool_spec:
        type: "generic"
        name: "get_bon_context"
        description: "Retrieves Business Ontology context with field decoders
          and authoritative business metric formulas. MUST be called first."
        input_schema:
          type: "object"
          properties: {}
  tool_resources:
    query_data:
      semantic_view: "MY_DATABASE.MY_SCHEMA.MY_BASELINE_SV"
      execution_environment:
        type: "warehouse"
        warehouse: "MY_WAREHOUSE"
    get_bon_context:
      type: "procedure"
      identifier: "MY_DATABASE.MY_SCHEMA.SP_GET_BON_CONTEXT"
      execution_environment:
        type: "warehouse"
        warehouse: "MY_WAREHOUSE"
        query_timeout: 60
  $$;
```

### Key Agent Design Decisions

| Setting | Baseline Agent | BON Agent | Why |
|---|---|---|---|
| Tools | 1 (text-to-sql) | 2 (text-to-sql + context SP) | BON needs the context tool |
| Token budget | 16,000 | 24,000 | BON context string adds ~2K tokens |
| Time budget | 60s | 90s | Two tool calls instead of one |
| Instructions | Generic | 4-step orchestration | Must enforce "context first" pattern |

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
| **Where stored** | Semantic View YAML | Glossary (SYSTEM$ API) + Context SP |
| **Who reads it** | Cortex Analyst (text-to-sql) | The LLM agent (as guidance for writing SQL) |

### How Formulas Flow

```
Glossary (SYSTEM$ API)              Stored Procedure              Agent
────────────────────                ──────────────                ─────
METRIC term with                    SP calls SYSTEM$GET_           Agent reads formula text
"formula": "COUNT(DISTINCT     →    GLOSSARY_TERM() for        →   and writes:
LIFNR) FROM LFA1 WHERE             every term at runtime.          SELECT COUNT(DISTINCT LIFNR)
KTOKK IN ('ZSTR','ZSTD')"          Assembles into structured       FROM LFA1
                                    context string.                 WHERE KTOKK IN ('ZSTR','ZSTD')
Single source of truth.
Updated via skill or SQL.           Reads dynamically.              Executed via Semantic View.
                                    No hardcoded logic.
```

The formula is **guidance for the LLM**, not executable code. The glossary stores it, the SP delivers it, and the agent uses it to write the correct SQL.

---

## Architecture Summary

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
│  SP_GET_BON_CONTEXT() → structured text string containing: │
│    • Table decoders (LFA1=Vendor Master, etc.)             │
│    • Field decoders (KTOKK: ZSTR=Strategic, etc.)          │
│    • 11 numbered formulas with SQL + warnings              │
│    • Cross-domain relationship map                         │
├─────────────────────────────────────────────────────────────┤
│                   CORTEX AGENT                              │
│                                                             │
│  Tool 1: get_bon_context → reads SP (ALWAYS first)         │
│  Tool 2: query_data → text-to-SQL via Semantic View        │
│                                                             │
│  Agent flow: read context → understand formulas → write SQL │
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
