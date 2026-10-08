# PRD: Industry Standard Ontology Data Products for Snowflake Marketplace

| Field | Value |
|---|---|
| **Author** | Tianxia Jia |
| **Status** | Draft |
| **Last Updated** | 2026-10-08 |
| **Dependency** | Feature 1: OWL Import + BON Reasoning ([PRD](PRD-owl-import-bon-reasoning.md), [Design](DESIGN-owl-import-bon-reasoning.md)) |
| **Delivery** | Snowflake Marketplace listings + Internal Marketplace listings |

---

## 1. Problem Statement

Industry-standard ontologies (FIBO, GS1, SNOMED CT, Gene Ontology, HL7 FHIR) are maintained as OWL files by standards bodies and industry consortia. Every Snowflake customer in a given industry needs the same standard, but today each must independently:

1. Obtain the OWL file from the standards body
2. Parse it (requires rdflib expertise)
3. Map OWL constructs to BON (requires ontology + Snowflake knowledge)
4. Import into their BON (hundreds or thousands of SYSTEM$ API calls)
5. Pre-compute inferences (transitive closure, property chains)
6. Deploy reasoning UDFs for their agent
7. Maintain when the standard releases a new version

This is redundant, error-prone, and impractical for large ontologies (SNOMED CT = 350K concepts, GS1 = 35K categories). Each customer makes different mapping decisions, producing inconsistent interpretations of the same standard.

### What should happen instead

A provider (Snowflake, ISV, or standards body) ingests the industry OWL once using Feature 1's pipeline, packages the result as a Snowflake Marketplace listing, and every customer installs it in minutes. The customer then extends it with their enterprise-specific concepts.

---

## 2. Objective

Publish pre-built industry ontologies as Snowflake Marketplace data products — each containing pre-computed inference tables, traversal UDFs, and agent-ready context SPs — so customers get instant access to canonical industry semantics and compose them with their own custom BON.

---

## 3. User Personas

| Persona | Role | Need |
|---|---|---|
| **Industry Ontology Provider** | Standards body, ISV, Snowflake partner, or Snowflake team | Publish a canonical, maintained version of an industry standard as a Marketplace listing |
| **Enterprise Customer (consumer)** | Data engineer or ontology steward at a company in that industry | Install the industry ontology, extend with enterprise-specific concepts, connect both to their Cortex Agent |
| **Agent User (consumer)** | Business analyst asking questions via Cortex Agent | Get correct answers to questions requiring industry-standard hierarchy expansion and classification |

---

## 4. Relationship to Feature 1

```
Feature 1: OWL Import + BON Reasoning
(generic pipeline — platform capability)
        │
        │ Feature 2 USES Feature 1's pipeline
        │ to produce each listing
        │
        ▼
Feature 2: Industry Ontology Data Products
(curated listings — product/marketplace offering)
```

Feature 2 depends on Feature 1 but is a separate product with different:
- Audience (provider vs customer)
- Motion (publish vs self-serve)
- Cadence (per-industry curation vs on-demand)
- Revenue model (listing vs platform)

---

## 5. Architecture

### Provider Side

```
Industry OWL file        Feature 1 Pipeline           Snowflake Listing
(FIBO, GS1, etc.)        (parse + BON + precompute    (data product)
                          + deploy UDFs)
       │                         │                         │
       ▼                         ▼                         ▼
  Standards body ──▶ parse_ontology_file.py ──▶  Published as:
  releases v2.1      batch_import.py              - Shared database
                     deploy_precompute.py          - Pre-computed tables
                     deploy_udfs.py                - Traversal UDFs
                                                   - Context SP
                                                   - Documentation
                                                   - Sample queries
```

### Consumer Side

```
Install listing          Import custom OWL        Compose in agent
from Marketplace         into own BON
       │                      │                      │
       ▼                      ▼                      ▼
 Read-only shared        Custom BON nodes        Agent tools:
 industry ontology       + relationships         1. Base SV (data)
 ({PREFIX}_GRAPH,        + constraints           2. Industry UDFs (shared)
  {PREFIX}_INFERRED,     + business rules        3. Industry context (shared)
  {PREFIX}_UDFs)                                 4. Custom BON context
                                                 5. Custom reasoning UDFs
```

---

## 6. Data Product Contents

Each industry ontology listing includes:

| Object | Type | Description |
|---|---|---|
| `{PREFIX}_GRAPH` | Table (shared) | Materialized ontology graph — all classes, properties, hierarchy |
| `{PREFIX}_INFERRED` | Table (shared) | Pre-computed transitive closure, inverse edges, property chains |
| `{PREFIX}_CONSTRAINT` | Table (shared) | OWL constraints (cardinality, disjoint, restrictions) |
| `{PREFIX}_RULE` | Table (shared) | Inference rule definitions |
| `{PREFIX}_EXPAND_DESCENDANTS()` | UDF (shared) | Hierarchy expansion — returns all descendants of a concept |
| `{PREFIX}_GET_ANCESTORS()` | UDF (shared) | Ancestor lookup — returns all ancestors of a concept |
| `{PREFIX}_GET_PATH()` | UDF (shared) | Path finding — shortest path between two concepts |
| `{PREFIX}_GET_CHILDREN()` | UDF (shared) | Direct children of a concept |
| `{PREFIX}_CONTEXT()` | SP (shared) | Enhanced context SP — definitions + inferred edges + constraints + tool instructions |
| Documentation | Listing metadata | Data dictionary, sample queries, usage guide, OWL source reference |

---

## 7. Target Industry Ontologies

### Phase 1: Pilot listings (small-medium, well-scoped)

| Listing Name | Source | Classes | Domain | Complexity |
|---|---|---|---|---|
| `SCHEMA_ORG_ONTOLOGY` | Schema.org | ~800 | General-purpose | Low — flat hierarchy, many properties |
| `DUBLIN_CORE_METADATA` | Dublin Core | 55 | Metadata | Low — very small, well-defined |
| `PROV_ONTOLOGY` | PROV-O | ~30 | Provenance | Low — small, includes property chains |
| `NAICS_CLASSIFICATION` | NAICS | ~2,000 | Cross-industry | Medium — deep hierarchy |

### Phase 2: Industry-specific (medium, with reasoning)

| Listing Name | Source | Classes | Domain | Complexity |
|---|---|---|---|---|
| `FIBO_INSTRUMENTS` | FIBO (EDM Council) | ~500 | Financial services: instruments | Medium — restrictions, property chains |
| `FIBO_ENTITIES` | FIBO (EDM Council) | ~400 | Financial services: legal entities | Medium |
| `FHIR_RESOURCES` | HL7 FHIR (subset) | ~150 | Healthcare interop | Medium |
| `GS1_ELECTRONICS` | GS1 (subset) | ~2,000 | Retail: electronics | Medium — deep taxonomy |

### Phase 3: Large-scale (requires --run-reasoner)

| Listing Name | Source | Classes | Domain | Complexity |
|---|---|---|---|---|
| `FIBO_COMPLETE` | FIBO (all modules) | ~1,500 | Financial services | High — complex restrictions |
| `SNOMED_CARDIOLOGY` | SNOMED CT (subset) | ~5,000 | Healthcare: cardiology | High — role-based reasoning |
| `SNOMED_PHARMACOLOGY` | SNOMED CT (subset) | ~5,000 | Healthcare: pharmacology | High |
| `GO_MOLECULAR_FUNCTION` | Gene Ontology (branch) | ~4,000 | Life sciences | High — DAG, transitive part_of |
| `GS1_FOOD` | GS1 (subset) | ~3,000 | Retail: food & beverage | Medium — deep taxonomy |
| `UNSPSC_PRODUCT_CODES` | UNSPSC (subset) | ~5,000 | Procurement | Medium — deep taxonomy |

---

## 8. Consumer Composition Model

### Step 1: Install industry ontology from Marketplace

```sql
-- Consumer installs the FIBO instruments listing
CREATE DATABASE FIBO_INSTRUMENTS FROM LISTING 'FIBO_INSTRUMENTS';

-- Immediately available (read-only, zero-copy):
-- FIBO_INSTRUMENTS.PUBLIC.FIBO_GRAPH          (5,000+ rows)
-- FIBO_INSTRUMENTS.PUBLIC.FIBO_INFERRED       (pre-computed transitive edges)
-- FIBO_INSTRUMENTS.PUBLIC.FIBO_CONSTRAINT     (OWL restrictions)
-- FIBO_INSTRUMENTS.PUBLIC.FIBO_EXPAND_DESCENDANTS()
-- FIBO_INSTRUMENTS.PUBLIC.FIBO_GET_ANCESTORS()
-- FIBO_INSTRUMENTS.PUBLIC.FIBO_CONTEXT()
```

### Step 2: Import custom enterprise ontology into own BON

```
$business-ontology import @stage/acme_finance.ttl into ACME Finance domain
```

Creates enterprise-specific concepts: "ACME Bond Rating Scale" (company-specific decoder), "ACME Credit Risk Model" (custom metric), "ACME Regulatory Capital" (extends FIBO Capital concept), etc.

### Step 3: Configure agent with both tool sets

```json
{
  "tools": [
    {
      "type": "cortex_analyst_text_to_sql",
      "name": "acme_portfolio_data"
    },
    {
      "type": "function",
      "function": {
        "name": "FIBO_INSTRUMENTS.PUBLIC.FIBO_CONTEXT",
        "description": "FIBO industry-standard definitions for financial instruments, issuers, and markets. Includes pre-computed hierarchy, constraints, and relationship graph."
      }
    },
    {
      "type": "function",
      "function": {
        "name": "FIBO_INSTRUMENTS.PUBLIC.FIBO_EXPAND_DESCENDANTS",
        "description": "Expand a FIBO concept to all its subtypes. Use for questions like 'all fixed-income instruments' or 'all equity derivatives'."
      }
    },
    {
      "type": "function",
      "function": {
        "name": "ACME_ONTOLOGY.PUBLIC.SP_BON_CONTEXT_REASONING",
        "description": "ACME enterprise-specific business definitions, metrics, and relationships."
      }
    },
    {
      "type": "function",
      "function": {
        "name": "ACME_ONTOLOGY.PUBLIC.BON_EXPAND_DESCENDANTS",
        "description": "Expand ACME enterprise-specific concept hierarchy."
      }
    }
  ]
}
```

### Step 4: Agent reasons across both

User: "What is our total exposure to fixed-income instruments?"

1. Agent calls `FIBO_CONTEXT()` — learns Bond, Note, Debenture, Commercial Paper are all subclasses of FixedIncomeInstrument per FIBO standard
2. Agent calls `FIBO_EXPAND_DESCENDANTS('FixedIncomeInstrument')` — gets the full FIBO subtree (20+ instrument types)
3. Agent calls `SP_BON_CONTEXT_REASONING()` — learns ACME-specific mappings: "ACME uses instrument_type_code column where FI01=Bond, FI02=Note, FI03=Debenture..."
4. Agent generates SQL:

```sql
SELECT instrument_type, SUM(notional_value) AS total_exposure
FROM acme_portfolio.positions p
WHERE p.instrument_type_code IN ('FI01', 'FI02', 'FI03', 'FI04', ...)
  -- codes mapped from FIBO hierarchy + ACME decoder
GROUP BY instrument_type;
```

---

## 9. Publishing Workflow

### For the provider

```
1. OBTAIN: Download industry OWL file from standards body
   - FIBO: https://spec.edmcouncil.org/fibo/
   - GS1: https://www.gs1.org/standards
   - SNOMED CT: licensed from SNOMED International
   - Gene Ontology: http://geneontology.org/

2. PARSE: Run Feature 1 pipeline
   $business-ontology import @stage/fibo_instruments.owl \
       into FIBO_Instruments domain \
       --run-reasoner  (for complex OWL DL)

3. PRE-COMPUTE: Materialize inferences
   (automatic post-import step via deploy_precompute.py)

4. DEPLOY UDFs: Create reasoning tools
   $bon-reasoning deploy on FIBO_DB.PUBLIC

5. PACKAGE: Create Snowflake share
   CREATE SHARE fibo_instruments_share;
   GRANT USAGE ON DATABASE FIBO_DB TO SHARE fibo_instruments_share;
   GRANT USAGE ON SCHEMA FIBO_DB.PUBLIC TO SHARE fibo_instruments_share;
   GRANT SELECT ON ALL TABLES IN SCHEMA FIBO_DB.PUBLIC TO SHARE fibo_instruments_share;
   GRANT USAGE ON ALL FUNCTIONS IN SCHEMA FIBO_DB.PUBLIC TO SHARE fibo_instruments_share;

6. PUBLISH: Create Marketplace listing with metadata
   - Title, description, category (Industry: Financial Services)
   - Data dictionary describing each table and UDF
   - Sample SQL queries demonstrating agent integration
   - Usage guide for consumer composition
   - Terms of service (licensing from standards body if applicable)

7. MAINTAIN: When OWL standard releases new version
   - Re-run pipeline steps 2-4
   - Update listing — consumers see changes automatically (zero-copy)
   - Changelog in listing metadata
```

### For the consumer

```
1. DISCOVER: Browse Snowflake Marketplace → Industry Ontologies category
2. INSTALL: CREATE DATABASE ... FROM LISTING (one command)
3. VERIFY: Query FIBO_GRAPH to see what's available
4. EXTEND: Import custom enterprise ontology into own BON
5. CONFIGURE: Add industry + custom tools to Cortex Agent
6. USE: Agent reasons across both ontologies
```

---

## 10. Version Management

| Scenario | How handled |
|---|---|
| Standards body releases new version (e.g., FIBO 2025Q4) | Provider re-runs pipeline, updates listing. Consumer sees updated data automatically (zero-copy shared data) |
| Breaking change (class renamed, removed, restructured) | Provider publishes new listing version (e.g., FIBO_INSTRUMENTS_V2). Old version remains available. Consumer migrates on their own timeline |
| Consumer's custom ontology references an industry concept that was removed | Consumer's agent still works (custom BON is independent). Industry UDF returns empty for removed concept. Consumer updates custom mapping |
| Bug in provider's mapping (wrong BON type for an OWL property) | Provider fixes and re-publishes. Consumer gets fix automatically |

---

## 11. Business Model

| Model | Description | Best for |
|---|---|---|
| **Free listing** | Open-source ontologies (Schema.org, Dublin Core, PROV-O, Gene Ontology) | Community adoption, platform stickiness |
| **Free with attribution** | Standards body provides OWL; Snowflake (or partner) curates the listing | NAICS, FIBO (open-source portions) |
| **Paid listing** | Licensed ontology; provider charges per consumer or per month | SNOMED CT (licensed), proprietary industry taxonomies |
| **ISV partner** | Third-party curates and publishes domain-specific ontology | Niche verticals (oil & gas, manufacturing, agriculture) |

---

## 12. Advantages Over DIY Import

| Aspect | DIY (each customer) | Pre-built data product |
|---|---|---|
| Time to value | Hours to days | Minutes |
| Compute cost | Customer pays for parsing + inference | Zero for consumer (zero-copy) |
| Mapping quality | Varies — each customer interprets OWL differently | Canonical — one authoritative interpretation |
| Updates | Manual re-import per customer | Automatic via listing refresh |
| Scale | Impractical for large ontologies | Provider handles full-scale with HermiT |
| Consistency | Different mappings across customers in same industry | Industry-wide standard mapping |
| Agent tools | Each customer deploys UDFs | Pre-deployed, ready to register |

---

## 13. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Licensing restrictions on some ontologies (SNOMED CT requires license) | High | Medium — can't publish as free listing | Paid listing model; verify licensing before publishing |
| Standards body releases incompatible version | Medium | Medium — consumer's custom overlay may break | Versioned listings; migration guide; keep old version available |
| Consumer over-relies on industry ontology and doesn't add enterprise context | Medium | Low — agent works but gives generic answers | Documentation + getting-started guide emphasizing composition |
| Cross-region listing replication latency | Low | Low — ontology data is small (MB not TB) | Standard Snowflake cross-region auto-fulfillment |
| Consumer needs concepts not in the industry standard | Expected | None — this is the composition model | Custom BON import handles enterprise-specific extensions |

---

## 14. Success Metrics

| Metric | Target | How measured |
|---|---|---|
| Listings published (Phase 1) | 4 pilot listings live | Marketplace listing count |
| Consumer installs (6 months) | 50+ installs across all listings | Listing access history |
| Agent integration rate | 30% of consumers register at least one industry UDF as agent tool | Agent config analysis |
| Time to value | Consumer from install to working agent query < 30 minutes | Guided tutorial completion |
| Industry coverage | 3+ verticals (financial, healthcare, retail) | Listing portfolio |

---

## 15. Open Questions

| # | Question | Status |
|---|---|---|
| 1 | Who is the initial provider? Snowflake team? ISV partner? Community contribution? | Open |
| 2 | Should listings include the BON glossary terms (via SYSTEM$ API state) or only the reasoning tables? Glossary terms are account-specific; reasoning tables are shareable | Open — likely reasoning tables only for cross-account sharing; consumer creates their own BON terms referencing the shared hierarchy |
| 3 | How does FIBO licensing work for a Marketplace listing? EDM Council publishes under MIT license — likely OK for free listing | Needs legal review |
| 4 | Should we build a CoCo skill (`$industry-ontology`) that automates the consumer-side composition (install + configure agent)? | Open |
| 5 | Can Snowflake Native Apps be used instead of bare shares to include setup scripts, agent configuration helpers, and documentation? | Open — would provide better consumer experience |
