# Design Doc: Ontology File Import + Runtime Reasoning for Business Ontology

| Field | Value |
|---|---|
| **Author** | Tianxia Jia |
| **Status** | Draft |
| **Last Updated** | 2026-10-08 |
| **PRD Reference** | [PRD-owl-import-bon-reasoning.md](PRD-owl-import-bon-reasoning.md) |
| **Skills** | `$business-ontology` (extended), `$bon-reasoning` (new) |

---

## 1. System Architecture

### 1.1 Three-Piece Design

```
┌──────────────────────────────────────────────────────────────────┐
│  $business-ontology  (import + pre-compute)                      │
│                                                                  │
│  ┌───────────────┐  ┌─────────────────┐  ┌───────────────────┐  │
│  │ Path O: Parse │  │ batch_import.py │  │ deploy_precompute │  │
│  │ OWL/TTL/RDF/  │─▶│ draft + approve │─▶│ .py               │  │
│  │ JSONLD/CSV/   │  │ nodes, rels     │  │ sync + infer +    │  │
│  │ YAML/GraphML  │  │                 │  │ store constraints │  │
│  └───────┬───────┘  └────────┬────────┘  └────────┬──────────┘  │
│          │                   │                     │             │
│  Optional pre-step:          │                     │             │
│  owlready2 + HermiT         │                     │             │
│  (--run-reasoner flag)       │                     │             │
│                              ▼                     ▼             │
│                     ┌──────────────────────────────────┐        │
│                     │  BON Glossary (SYSTEM$ API)       │        │
│                     │  + BON_GRAPH (materialized)       │        │
│                     │  + BON_INFERRED (pre-computed)    │        │
│                     │  + BON_CONSTRAINT                 │        │
│                     │  + BON_RULE                       │        │
│                     └──────────────┬───────────────────┘        │
└────────────────────────────────────│────────────────────────────┘
                                     │ reads from
                                     ▼
┌──────────────────────────────────────────────────────────────────┐
│  $bon-reasoning  (runtime, Sense-ready)                          │
│                                                                  │
│  UDFs:                        SPs:                               │
│  BON_EXPAND_DESCENDANTS()     SP_BON_CONTEXT_REASONING()         │
│  BON_GET_ANCESTORS()          SP_BON_VALIDATE()                  │
│  BON_GET_PATH()                                                  │
│  BON_GET_CHILDREN()           → Registered as agent tools        │
│                               → Future: absorbed by Cortex Sense │
└──────────────────────────────────┬───────────────────────────────┘
                                   │ tools
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│  Cortex Agent                                                    │
│  Tool 1: Base Semantic View (data queries)                       │
│  Tool 2: BON context SP (definitions + inferences + constraints) │
│  Tool 3: bon-reasoning UDFs (runtime traversal + expansion)      │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 Why This Separation

| Concern | Location | Rationale |
|---|---|---|
| Import (parse, map, create BON objects) | `$business-ontology` | Import is a builder workflow with draft/approve, quality gates, steward review. Same lifecycle as existing import paths (SV, dbt, tables) |
| Pre-compute (transitive closure, inverse edges, chains) | `$business-ontology` post-import | Pre-computation is part of the import pipeline. Runs once after BON populated, triggered by import completion |
| Runtime reasoning (traversal, expansion, context) | `$bon-reasoning` (new skill) | Runtime tools are agent-facing, not builder-facing. Different lifecycle. Must be independently deployable and version-manageable. Designed for Cortex Sense absorption |

### 1.3 Data Flow

```
Phase 1: IMPORT TIME
──────────────────────────────────────────────────────────

                  ┌──────────────────────┐
                  │  owlready2 + HermiT  │ (optional --run-reasoner)
                  │  Pre-classifies OWL  │
                  │  DL restrictions     │
OWL/TTL/RDF ────▶└──────────┬───────────┘
   file                     │ inferred triples merged
                            ▼
                  ┌──────────────────────┐
                  │  parse_ontology      │
                  │  _file.py            │
                  │  (rdflib parser)     │
                  └──┬──────┬────────┬───┘
                     │      │        │
                     ▼      ▼        ▼
              candidates  rels    owl_reasoning
              .json       .json   .json
                     │      │        │
                     ▼      ▼        │
                  ┌──────────────┐   │
                  │ batch_import │   │
                  │ .py          │   │
                  │ draft+approve│   │
                  └──────┬───────┘   │
                         │           │
                         ▼           ▼
                  ┌──────────────────────┐
                  │  deploy_precompute   │
                  │  .py                 │
                  │                      │
                  │  1. Create tables    │
                  │  2. Load constraints │
                  │  3. SP_BON_SYNC()    │
                  │  4. SP_BON_PRECOMPUTE│
                  └──────────────────────┘


Phase 2: QUERY TIME
──────────────────────────────────────────────────────────

User question ──▶ Cortex Agent
                      │
          ┌───────────┼───────────────┐
          ▼           ▼               ▼
     Base SV     BON context     bon-reasoning
     (data)      SP (definitions  UDFs (traversal
                  + inferred      + expansion)
                  edges +
                  constraints)
          │           │               │
          └───────────┼───────────────┘
                      ▼
                 Agent generates SQL
```

---

## 2. Component Design

### 2.1 Parser: parse_ontology_file.py

**Location:** `business-ontology/scripts/parse_ontology_file.py`

**Dependencies:** `rdflib>=7.0.0` (for all RDF-family formats), `PyYAML>=6.0` (for YAML), `owlready2>=0.46` (optional, for --run-reasoner)

**CLI Interface:**

```bash
uv run --project <SKILL_DIR>/../.. python <SKILL_DIR>/../../scripts/parse_ontology_file.py \
    --file /path/to/ontology.ttl \
    --output-dir /tmp/ontology_parsed \
    --domain "Upstream" \
    --format turtle \
    --exclude-deprecated \
    --namespace-filter "https://example.com/upstream#" \
    --max-concepts 500 \
    --run-reasoner
```

**Arguments:**

| Arg | Required | Default | Description |
|---|---|---|---|
| `--file` | Yes | — | Path to ontology file |
| `--output-dir` | Yes | — | Directory for output JSON files |
| `--domain` | Yes | — | Target BON domain name |
| `--format` | No | Auto-detect from extension | Force format: xml, turtle, json-ld, nt, nq, trig, n3, yaml, csv, graphml |
| `--exclude-deprecated` | No | False | Skip owl:deprecated classes |
| `--namespace-filter` | No | None | Only import classes from this namespace prefix |
| `--max-concepts` | No | None | Cap number of imported concepts |
| `--run-reasoner` | No | False | Run owlready2 + HermiT before parsing (for complex OWL DL) |

**Output Files:**

#### candidates.json

Matches `CANDIDATE_CONTRACT.md` shape. One entry per BON node:

```json
[
  {
    "name": "Field",
    "itemKind": "ENTITY",
    "domainName": "Oil Gas Upstream",
    "domainSource": "OWL_IMPORT",
    "description": "A geographical area containing hydrocarbon reservoirs. [OWL: disjoint with Pipeline]",
    "formula": null,
    "synonyms": ["OilField", "ProductionField"],
    "scope": null,
    "sourceUri": "https://example.com/upstream#Field",
    "sourceFormat": "turtle",
    "parentConcept": null
  }
]
```

#### relationships.json

One entry per BON relationship to create after node approval:

```json
[
  {
    "sourceName": "Field",
    "targetName": "Reservoir",
    "type": "HAS_PART",
    "label": "hasReservoir",
    "sourceUri": "https://example.com/upstream#hasReservoir",
    "owlCharacteristics": {
      "isTransitive": true,
      "isSymmetric": false,
      "isFunctional": false,
      "inverseOf": "isReservoirOf"
    }
  }
]
```

#### owl_reasoning.json

Extracted OWL reasoning constructs for the pre-compute and runtime layers:

```json
{
  "transitive_properties": [
    {
      "property": "hasReservoir",
      "owlUri": "https://example.com/upstream#hasReservoir",
      "bonRelType": "HAS_PART"
    }
  ],
  "symmetric_properties": [],
  "inverse_properties": [
    {
      "property": "hasReservoir",
      "inverse": "isReservoirOf",
      "owlUri": "https://example.com/upstream#hasReservoir"
    }
  ],
  "property_chains": [
    {
      "resultProperty": "hasWellTransitive",
      "chain": ["hasReservoir", "hasWell"],
      "owlUri": "https://example.com/upstream#hasWellTransitive"
    }
  ],
  "constraints": [
    {
      "nodeUri": "https://example.com/upstream#Reservoir",
      "nodeName": "Reservoir",
      "kind": "DISJOINT",
      "propertyName": null,
      "expression": "disjoint with Well",
      "owlSource": "ex:Reservoir owl:disjointWith ex:Well"
    },
    {
      "nodeUri": "https://example.com/upstream#Well",
      "nodeName": "Well",
      "kind": "CARDINALITY",
      "propertyName": "hasOperator",
      "expression": "exactly 1",
      "owlSource": "owl:cardinality 1"
    }
  ],
  "rules": [
    {
      "kind": "SWRL",
      "expression": "Field(?f) ^ activeReservoir(?f,?r) -> activeField(?f)",
      "owlSource": "..."
    }
  ],
  "stats": {
    "totalClasses": 3,
    "totalProperties": 5,
    "totalIndividuals": 0,
    "transitiveProperties": 1,
    "symmetricProperties": 0,
    "propertyChains": 1,
    "constraints": 2,
    "rules": 0,
    "droppedAnonymousClasses": 0,
    "droppedBlankNodes": 12
  }
}
```

**Internal Architecture:**

```python
# Pseudocode structure

class OntologyParser:
    """Unified parser — dispatches to format-specific backends."""
    
    def parse(self, file_path, format_hint, options) -> ParseResult:
        if format_hint in RDF_FORMATS:
            return self._parse_rdf(file_path, format_hint, options)
        elif format_hint == 'yaml':
            return self._parse_yaml(file_path, options)
        elif format_hint == 'csv':
            return self._parse_csv(file_path, options)
        elif format_hint == 'graphml':
            return self._parse_graphml(file_path, options)
    
    def _parse_rdf(self, path, fmt, options) -> ParseResult:
        # Optional: run HermiT reasoner first
        if options.run_reasoner:
            path = self._run_hermit(path)
        
        # Parse with rdflib
        g = Graph()
        g.parse(path, format=fmt)
        
        # Extract components
        classes = self._extract_classes(g)           # → ENTITY/DIMENSION_CONCEPT nodes
        obj_props = self._extract_object_properties(g)  # → relationships
        data_props = self._extract_data_properties(g)   # → TERM/decoder nodes
        individuals = self._extract_individuals(g)      # → TERM nodes
        reasoning = self._extract_reasoning(g)          # → owl_reasoning.json
        
        # Apply mapping rules
        candidates = self._map_to_bon_candidates(classes, data_props, individuals, options)
        relationships = self._map_to_bon_relationships(obj_props, options)
        
        return ParseResult(candidates, relationships, reasoning)
    
    def _extract_reasoning(self, g: Graph) -> dict:
        """Extract all OWL reasoning constructs."""
        return {
            "transitive_properties": self._find_transitive(g),
            "symmetric_properties": self._find_symmetric(g),
            "inverse_properties": self._find_inverse(g),
            "property_chains": self._find_chains(g),
            "constraints": self._find_constraints(g),  # cardinality + disjoint + restrictions
            "rules": self._find_swrl_rules(g),
        }
```

**Relationship Type Heuristic:**

```python
RELATIONSHIP_HEURISTIC = {
    # OWL property name patterns → BON relationship type
    r"(?i)(part|component|contains|comprises|composed)": "HAS_PART",
    r"(?i)(variant|version|edition|flavor)": "HAS_VARIANT",
    r"(?i)(derives|computed|calculated|based.on)": "DERIVES",
    r"(?i)(measures|quantifies|counts|tracks)": "MEASURES",
    r"(?i)(identifies|references|coded|keyed)": "IDENTIFIED_BY",
    r"(?i)(classifies|categorizes|groups|types)": "CLASSIFIES",
    r"(?i)(applies|governs|constrains|regulates)": "APPLIES_TO",
    r"(?i)(scopes|bounds|limits|within)": "SCOPES",
    r"(?i)(same|equivalent|equal|identical)": "EQUIVALENT_TO",
}
# No match → CUSTOM with OWL property name as label
```

**Description Annotation Format:**

```python
def _build_description(self, business_desc: str, owl_annotations: list[str]) -> str:
    """Build BON description with [OWL:] markers. Respects 270-char limit."""
    DESC_LIMIT = 270
    
    # Business prose first, never truncated
    result = business_desc.strip()
    
    # Append OWL annotations
    for ann in owl_annotations:
        marker = f" [OWL: {ann}]"
        if len(result) + len(marker) <= DESC_LIMIT:
            result += marker
        else:
            # Truncate annotations, not business prose
            remaining = DESC_LIMIT - len(result) - len(" [OWL: +N more]")
            if remaining > 0:
                result += f" [OWL: +{len(owl_annotations) - owl_annotations.index(ann)} more]"
            break
    
    return result
```

---

### 2.2 Pre-compute: deploy_precompute.py

**Location:** `business-ontology/scripts/deploy_precompute.py`

**Purpose:** Creates reasoning tables and SPs in the target schema, loads OWL reasoning constructs, runs initial inference.

**CLI Interface:**

```bash
uv run --project <SKILL_DIR>/../.. python <SKILL_DIR>/../../scripts/deploy_precompute.py \
    --connection <connection> \
    --database DB_ONTOLOGY \
    --schema SAP_PRODUCTION \
    --reasoning-json /tmp/ontology_parsed/owl_reasoning.json
```

**What It Creates:**

#### Tables

```sql
-- Materialized BON glossary graph
-- Why: SYSTEM$ functions cannot be called inside SQL UDFs.
-- This table makes the glossary queryable by recursive CTEs.
CREATE TABLE IF NOT EXISTS BON_GRAPH (
    NODE_ID         STRING NOT NULL,
    NODE_NAME       STRING NOT NULL,
    NODE_KIND       STRING NOT NULL,     -- ENTITY, METRIC, TERM, DIMENSION_CONCEPT
    DOMAIN_NAME     STRING,
    DESCRIPTION     STRING,
    FORMULA         STRING,
    SYNCED_AT       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS BON_GRAPH_EDGES (
    SOURCE_ID       STRING NOT NULL,
    TARGET_ID       STRING NOT NULL,
    SOURCE_NAME     STRING,
    TARGET_NAME     STRING,
    REL_TYPE        STRING NOT NULL,     -- HAS_PART, DERIVES, EQUIVALENT_TO, etc.
    REL_LABEL       STRING,
    SYNCED_AT       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Pre-computed inference results
CREATE TABLE IF NOT EXISTS BON_INFERRED (
    REL_NAME        STRING NOT NULL,
    SOURCE_ID       STRING NOT NULL,
    TARGET_ID       STRING NOT NULL,
    SOURCE_NAME     STRING,
    TARGET_NAME     STRING,
    INFERENCE_KIND  STRING NOT NULL,     -- TRANSITIVE, INVERSE, PROPERTY_CHAIN, SWRL, REASONER
    RULE_ID         STRING,
    DEPTH           NUMBER DEFAULT 1,
    CONFIDENCE      FLOAT DEFAULT 1.0,   -- 1.0/depth for transitive
    INFERRED_AT     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- OWL constraints
CREATE TABLE IF NOT EXISTS BON_CONSTRAINT (
    CONSTRAINT_ID   STRING NOT NULL DEFAULT UUID_STRING(),
    NODE_ID         STRING NOT NULL,
    NODE_NAME       STRING,
    CONSTRAINT_KIND STRING NOT NULL,     -- CARDINALITY, DISJOINT, RESTRICTION, FUNCTIONAL
    PROPERTY_NAME   STRING,
    CONSTRAINT_EXPR STRING,
    OWL_SOURCE      STRING,
    CREATED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Inference rule definitions
CREATE TABLE IF NOT EXISTS BON_RULE (
    RULE_ID         STRING NOT NULL DEFAULT UUID_STRING(),
    RULE_KIND       STRING NOT NULL,     -- TRANSITIVE, INVERSE, PROPERTY_CHAIN, SWRL
    TARGET_REL      STRING,
    RULE_EXPR       STRING,
    IS_ENABLED      BOOLEAN DEFAULT TRUE,
    OWL_SOURCE      STRING,
    CREATED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

#### SP_BON_SYNC

```sql
CREATE OR REPLACE PROCEDURE SP_BON_SYNC()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'sync_bon_graph'
AS
$$
def sync_bon_graph(session):
    """Read BON glossary via SYSTEM$GET_GLOSSARY_GRAPH() and materialize into BON_GRAPH tables."""
    import json
    
    # 1. Fetch the full glossary graph
    result = session.sql("SELECT SYSTEM$GET_GLOSSARY_GRAPH()").collect()
    graph = json.loads(result[0][0])
    
    # 2. Truncate existing materialized tables
    session.sql("TRUNCATE TABLE IF EXISTS BON_GRAPH").collect()
    session.sql("TRUNCATE TABLE IF EXISTS BON_GRAPH_EDGES").collect()
    
    # 3. Load nodes from all domains
    node_count = 0
    edge_count = 0
    
    for domain in graph.get('domains', []):
        domain_name = domain.get('name', '')
        for term in domain.get('terms', []):
            term_id = str(term.get('termId', ''))
            session.sql(f"""
                INSERT INTO BON_GRAPH (NODE_ID, NODE_NAME, NODE_KIND, DOMAIN_NAME, DESCRIPTION, FORMULA)
                VALUES ('{term_id}', $${term.get('name','')}$$, 
                        '{term.get('itemKind','')}', $${domain_name}$$,
                        $${term.get('description','')}$$, 
                        $${term.get('formula','') or ''}$$)
            """).collect()
            node_count += 1
            
            # Load relationships from this term
            for rel in term.get('relationships', []):
                target_id = str(rel.get('targetTermId', ''))
                session.sql(f"""
                    INSERT INTO BON_GRAPH_EDGES 
                    (SOURCE_ID, TARGET_ID, SOURCE_NAME, TARGET_NAME, REL_TYPE, REL_LABEL)
                    VALUES ('{term_id}', '{target_id}', 
                            $${term.get('name','')}$$, $${rel.get('targetTermName','')}$$,
                            '{rel.get('type','')}', $${rel.get('label','') or ''}$$)
                """).collect()
                edge_count += 1
    
    return f"Synced {node_count} nodes, {edge_count} edges from {len(graph.get('domains',[]))} domains"
$$;
```

#### SP_BON_PRECOMPUTE

Adapted from ontology-stack-builder's `SP_INFER_TRANSITIVE` and `SP_INFER_INVERSE`, but reading from BON_GRAPH/BON_GRAPH_EDGES:

```sql
CREATE OR REPLACE PROCEDURE SP_BON_PRECOMPUTE()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'precompute'
AS
$$
def precompute(session):
    """Execute all enabled inference rules from BON_RULE."""
    import json
    
    # Clear previous inferences
    session.sql("TRUNCATE TABLE IF EXISTS BON_INFERRED").collect()
    
    # Read enabled rules
    rules = session.sql("""
        SELECT RULE_ID, RULE_KIND, TARGET_REL, RULE_EXPR
        FROM BON_RULE WHERE IS_ENABLED = TRUE
        ORDER BY CASE RULE_KIND
            WHEN 'INVERSE' THEN 1
            WHEN 'TRANSITIVE' THEN 2
            WHEN 'PROPERTY_CHAIN' THEN 3
            WHEN 'SWRL' THEN 4
        END
    """).collect()
    
    results = []
    for rule in rules:
        rule_id = rule['RULE_ID']
        kind = rule['RULE_KIND']
        
        if kind == 'TRANSITIVE':
            # Recursive CTE for transitive closure
            target_rel = rule['TARGET_REL']
            session.sql(f"""
                INSERT INTO BON_INFERRED 
                (REL_NAME, SOURCE_ID, TARGET_ID, SOURCE_NAME, TARGET_NAME,
                 INFERENCE_KIND, RULE_ID, DEPTH, CONFIDENCE)
                WITH RECURSIVE transitive(src_id, src_name, dst_id, dst_name, depth) AS (
                    SELECT SOURCE_ID, SOURCE_NAME, TARGET_ID, TARGET_NAME, 1
                    FROM BON_GRAPH_EDGES
                    WHERE REL_TYPE = '{target_rel}'
                    UNION ALL
                    SELECT t.src_id, t.src_name, e.TARGET_ID, e.TARGET_NAME, t.depth + 1
                    FROM transitive t
                    JOIN BON_GRAPH_EDGES e ON t.dst_id = e.SOURCE_ID 
                        AND e.REL_TYPE = '{target_rel}'
                    WHERE t.depth < 15 AND t.src_id != e.TARGET_ID
                )
                SELECT DISTINCT
                    '{target_rel}', src_id, dst_id, src_name, dst_name,
                    'TRANSITIVE', '{rule_id}', depth, 1.0 / depth
                FROM transitive
                WHERE (src_id, dst_id) NOT IN (
                    SELECT SOURCE_ID, TARGET_ID FROM BON_GRAPH_EDGES 
                    WHERE REL_TYPE = '{target_rel}'
                )
            """).collect()
            
        elif kind == 'INVERSE':
            # Flip direction for inverse/symmetric properties
            target_rel = rule['TARGET_REL']
            inverse_name = rule['RULE_EXPR']  # stores the inverse relationship name
            session.sql(f"""
                INSERT INTO BON_INFERRED
                (REL_NAME, SOURCE_ID, TARGET_ID, SOURCE_NAME, TARGET_NAME,
                 INFERENCE_KIND, RULE_ID, DEPTH, CONFIDENCE)
                SELECT
                    '{inverse_name}', TARGET_ID, SOURCE_ID, TARGET_NAME, SOURCE_NAME,
                    'INVERSE', '{rule_id}', 1, 1.0
                FROM BON_GRAPH_EDGES
                WHERE REL_TYPE = '{target_rel}'
            """).collect()
            
        elif kind == 'PROPERTY_CHAIN':
            # Compose: rel1 o rel2 → result_rel
            # RULE_EXPR format: "rel1|rel2|result_rel"
            parts = rule['RULE_EXPR'].split('|')
            if len(parts) == 3:
                rel1, rel2, result_rel = parts
                session.sql(f"""
                    INSERT INTO BON_INFERRED
                    (REL_NAME, SOURCE_ID, TARGET_ID, SOURCE_NAME, TARGET_NAME,
                     INFERENCE_KIND, RULE_ID, DEPTH, CONFIDENCE)
                    SELECT DISTINCT
                        '{result_rel}', e1.SOURCE_ID, e2.TARGET_ID,
                        e1.SOURCE_NAME, e2.TARGET_NAME,
                        'PROPERTY_CHAIN', '{rule_id}', 2, 0.5
                    FROM BON_GRAPH_EDGES e1
                    JOIN BON_GRAPH_EDGES e2 ON e1.TARGET_ID = e2.SOURCE_ID
                    WHERE e1.REL_TYPE = '{rel1}' AND e2.REL_TYPE = '{rel2}'
                    AND (e1.SOURCE_ID, e2.TARGET_ID) NOT IN (
                        SELECT SOURCE_ID, TARGET_ID FROM BON_GRAPH_EDGES
                        WHERE REL_TYPE = '{result_rel}'
                    )
                """).collect()
        
        count = session.sql(f"""
            SELECT COUNT(*) AS cnt FROM BON_INFERRED WHERE RULE_ID = '{rule_id}'
        """).collect()[0]['CNT']
        results.append(f"{kind} ({rule_id}): {count} inferred edges")
    
    total = session.sql("SELECT COUNT(*) AS cnt FROM BON_INFERRED").collect()[0]['CNT']
    return f"Pre-computed {total} inferred edges from {len(rules)} rules. " + "; ".join(results)
$$;
```

---

### 2.3 Runtime Reasoning: $bon-reasoning Skill

**Location:** New skill directory `bon-reasoning/`

**Structure:**

```
bon-reasoning/
├── SKILL.md                          # Skill definition, triggers, deployment workflow
├── scripts/
│   └── deploy_udfs.py                # Creates UDFs + SPs in target schema
├── reference/
│   └── REASONING_ARCHITECTURE.md     # How pieces fit, Sense migration path
├── pyproject.toml
└── README.md
```

**SKILL.md Triggers:**

```
$bon-reasoning deploy on <DB.SCHEMA>     — create UDFs and SPs
$bon-reasoning test                      — verify reasoning against current BON
$bon-reasoning expand <concept>          — quick test: expand descendants
$bon-reasoning ancestors <concept>       — quick test: find ancestors
$bon-reasoning path <start> to <end>     — quick test: find path
$bon-reasoning validate                  — run constraint validation
$bon-reasoning sync                      — re-sync BON_GRAPH from glossary
```

**deploy_udfs.py Creates:**

#### BON_EXPAND_DESCENDANTS UDF

```sql
CREATE OR REPLACE FUNCTION BON_EXPAND_DESCENDANTS(ROOT_CONCEPT VARCHAR)
RETURNS TABLE (NODE_ID VARCHAR, NODE_NAME VARCHAR, DEPTH NUMBER, PATH VARCHAR)
LANGUAGE SQL
AS
$$
WITH RECURSIVE
root_node AS (
    SELECT NODE_ID, NODE_NAME
    FROM BON_GRAPH
    WHERE LOWER(NODE_NAME) = LOWER(ROOT_CONCEPT)
    LIMIT 1
),
-- Walk explicit edges
explicit_descendants AS (
    SELECT
        e.TARGET_ID AS NODE_ID, g.NODE_NAME,
        1 AS DEPTH,
        r.NODE_NAME || ' -> ' || g.NODE_NAME AS PATH
    FROM BON_GRAPH_EDGES e
    JOIN root_node r ON e.SOURCE_ID = r.NODE_ID
    JOIN BON_GRAPH g ON e.TARGET_ID = g.NODE_ID
    WHERE e.REL_TYPE IN ('HAS_PART', 'HAS_VARIANT', 'CLASSIFIES')
    
    UNION ALL
    
    SELECT
        e.TARGET_ID, g.NODE_NAME,
        d.DEPTH + 1,
        d.PATH || ' -> ' || g.NODE_NAME
    FROM explicit_descendants d
    JOIN BON_GRAPH_EDGES e ON d.NODE_ID = e.SOURCE_ID
    JOIN BON_GRAPH g ON e.TARGET_ID = g.NODE_ID
    WHERE e.REL_TYPE IN ('HAS_PART', 'HAS_VARIANT', 'CLASSIFIES')
    AND d.DEPTH < 15
),
-- Include pre-computed transitive/chain inferences
inferred_descendants AS (
    SELECT
        i.TARGET_ID AS NODE_ID, i.TARGET_NAME AS NODE_NAME,
        i.DEPTH,
        r.NODE_NAME || ' -[inferred]-> ' || i.TARGET_NAME AS PATH
    FROM BON_INFERRED i
    JOIN root_node r ON i.SOURCE_ID = r.NODE_ID
    WHERE i.INFERENCE_KIND IN ('TRANSITIVE', 'PROPERTY_CHAIN')
)
-- Root
SELECT NODE_ID, NODE_NAME, 0 AS DEPTH, NODE_NAME AS PATH FROM root_node
UNION ALL
-- Explicit descendants
SELECT NODE_ID, NODE_NAME, DEPTH, PATH FROM explicit_descendants
UNION ALL
-- Inferred descendants (not already in explicit set)
SELECT NODE_ID, NODE_NAME, DEPTH, PATH FROM inferred_descendants
WHERE NODE_ID NOT IN (SELECT NODE_ID FROM explicit_descendants)
ORDER BY DEPTH, NODE_NAME
$$;
```

#### BON_GET_ANCESTORS UDF

```sql
CREATE OR REPLACE FUNCTION BON_GET_ANCESTORS(CONCEPT VARCHAR)
RETURNS TABLE (ANCESTOR_ID VARCHAR, ANCESTOR_NAME VARCHAR, DEPTH NUMBER)
LANGUAGE SQL
AS
$$
WITH RECURSIVE
start_node AS (
    SELECT NODE_ID, NODE_NAME FROM BON_GRAPH
    WHERE LOWER(NODE_NAME) = LOWER(CONCEPT) LIMIT 1
),
ancestors AS (
    SELECT e.SOURCE_ID AS ANCESTOR_ID, g.NODE_NAME AS ANCESTOR_NAME, 1 AS DEPTH
    FROM start_node s
    JOIN BON_GRAPH_EDGES e ON s.NODE_ID = e.TARGET_ID
    JOIN BON_GRAPH g ON e.SOURCE_ID = g.NODE_ID
    WHERE e.REL_TYPE IN ('HAS_PART', 'HAS_VARIANT', 'CLASSIFIES')
    
    UNION ALL
    
    SELECT e.SOURCE_ID, g.NODE_NAME, a.DEPTH + 1
    FROM ancestors a
    JOIN BON_GRAPH_EDGES e ON a.ANCESTOR_ID = e.TARGET_ID
    JOIN BON_GRAPH g ON e.SOURCE_ID = g.NODE_ID
    WHERE e.REL_TYPE IN ('HAS_PART', 'HAS_VARIANT', 'CLASSIFIES')
    AND a.DEPTH < 20
)
SELECT DISTINCT ANCESTOR_ID, ANCESTOR_NAME, MIN(DEPTH) AS DEPTH
FROM ancestors
GROUP BY ANCESTOR_ID, ANCESTOR_NAME
ORDER BY DEPTH, ANCESTOR_NAME
$$;
```

#### BON_GET_PATH UDF

```sql
CREATE OR REPLACE FUNCTION BON_GET_PATH(START_CONCEPT VARCHAR, END_CONCEPT VARCHAR)
RETURNS TABLE (STEP NUMBER, NODE_ID VARCHAR, NODE_NAME VARCHAR, RELATIONSHIP VARCHAR)
LANGUAGE SQL
AS
$$
WITH RECURSIVE
start_node AS (
    SELECT NODE_ID, NODE_NAME FROM BON_GRAPH
    WHERE LOWER(NODE_NAME) = LOWER(START_CONCEPT) LIMIT 1
),
end_node AS (
    SELECT NODE_ID, NODE_NAME FROM BON_GRAPH
    WHERE LOWER(NODE_NAME) = LOWER(END_CONCEPT) LIMIT 1
),
paths AS (
    -- Start from the start node, walk outward through any edge
    SELECT
        s.NODE_ID, s.NODE_NAME,
        'START' AS RELATIONSHIP,
        0 AS STEP,
        s.NODE_ID AS PATH_IDS
    FROM start_node s
    
    UNION ALL
    
    SELECT
        COALESCE(e1.TARGET_ID, e2.SOURCE_ID),
        COALESCE(g1.NODE_NAME, g2.NODE_NAME),
        COALESCE(e1.REL_TYPE, e2.REL_TYPE),
        p.STEP + 1,
        p.PATH_IDS || ',' || COALESCE(e1.TARGET_ID, e2.SOURCE_ID)
    FROM paths p
    LEFT JOIN BON_GRAPH_EDGES e1 ON p.NODE_ID = e1.SOURCE_ID
    LEFT JOIN BON_GRAPH g1 ON e1.TARGET_ID = g1.NODE_ID
    LEFT JOIN BON_GRAPH_EDGES e2 ON p.NODE_ID = e2.TARGET_ID
    LEFT JOIN BON_GRAPH g2 ON e2.SOURCE_ID = g2.NODE_ID
    WHERE p.STEP < 10
    AND COALESCE(e1.TARGET_ID, e2.SOURCE_ID) IS NOT NULL
    AND NOT CONTAINS(p.PATH_IDS, COALESCE(e1.TARGET_ID, e2.SOURCE_ID))
)
SELECT STEP, NODE_ID, NODE_NAME, RELATIONSHIP
FROM paths
WHERE NODE_ID = (SELECT NODE_ID FROM end_node)
ORDER BY STEP
LIMIT 1  -- shortest path
$$;
```

#### BON_GET_CHILDREN UDF

```sql
CREATE OR REPLACE FUNCTION BON_GET_CHILDREN(PARENT_CONCEPT VARCHAR)
RETURNS TABLE (CHILD_ID VARCHAR, CHILD_NAME VARCHAR, REL_TYPE VARCHAR)
LANGUAGE SQL
AS
$$
SELECT
    e.TARGET_ID AS CHILD_ID,
    g.NODE_NAME AS CHILD_NAME,
    e.REL_TYPE
FROM BON_GRAPH_EDGES e
JOIN BON_GRAPH g ON e.TARGET_ID = g.NODE_ID
WHERE e.SOURCE_ID = (
    SELECT NODE_ID FROM BON_GRAPH
    WHERE LOWER(NODE_NAME) = LOWER(PARENT_CONCEPT) LIMIT 1
)
ORDER BY g.NODE_NAME
$$;
```

#### SP_BON_CONTEXT_REASONING

```sql
CREATE OR REPLACE PROCEDURE SP_BON_CONTEXT_REASONING(DOMAIN_FILTER VARCHAR DEFAULT NULL)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'get_context'
AS
$$
def get_context(session, domain_filter=None):
    """Enhanced dynamic SP returning governed definitions + inferences + constraints + tool instructions."""
    import json
    
    # 1. Get governed nodes and relationships from BON glossary
    graph_json = session.sql("SELECT SYSTEM$GET_GLOSSARY_GRAPH()").collect()[0][0]
    graph = json.loads(graph_json)
    
    # 2. Get pre-computed inferred edges
    inferred_filter = ""
    if domain_filter:
        inferred_filter = f"WHERE SOURCE_NAME IN (SELECT NODE_NAME FROM BON_GRAPH WHERE DOMAIN_NAME = '{domain_filter}')"
    inferred = session.sql(f"""
        SELECT REL_NAME, SOURCE_NAME, TARGET_NAME, INFERENCE_KIND, DEPTH
        FROM BON_INFERRED {inferred_filter}
        ORDER BY INFERENCE_KIND, SOURCE_NAME
    """).collect()
    
    # 3. Get active constraints
    constraint_filter = ""
    if domain_filter:
        constraint_filter = f"WHERE NODE_NAME IN (SELECT NODE_NAME FROM BON_GRAPH WHERE DOMAIN_NAME = '{domain_filter}')"
    constraints = session.sql(f"""
        SELECT NODE_NAME, CONSTRAINT_KIND, PROPERTY_NAME, CONSTRAINT_EXPR
        FROM BON_CONSTRAINT {constraint_filter}
        ORDER BY NODE_NAME
    """).collect()
    
    # 4. Build context string
    context = {
        "governed_graph": graph,
        "inferred_edges": [
            {
                "source": r['SOURCE_NAME'], "target": r['TARGET_NAME'],
                "relationship": r['REL_NAME'], "kind": r['INFERENCE_KIND'],
                "hops": r['DEPTH']
            }
            for r in inferred
        ],
        "constraints": [
            {
                "node": r['NODE_NAME'], "kind": r['CONSTRAINT_KIND'],
                "property": r['PROPERTY_NAME'], "expression": r['CONSTRAINT_EXPR']
            }
            for r in constraints
        ],
        "reasoning_tools": {
            "BON_EXPAND_DESCENDANTS": "SELECT * FROM TABLE(BON_EXPAND_DESCENDANTS('concept_name')) — returns all descendants with depth and path",
            "BON_GET_ANCESTORS": "SELECT * FROM TABLE(BON_GET_ANCESTORS('concept_name')) — returns all ancestors with depth",
            "BON_GET_PATH": "SELECT * FROM TABLE(BON_GET_PATH('start', 'end')) — returns shortest path between two concepts",
            "BON_GET_CHILDREN": "SELECT * FROM TABLE(BON_GET_CHILDREN('parent')) — returns direct children"
        },
        "reasoning_instructions": [
            "When a question requires expanding a concept to all its subtypes, use BON_EXPAND_DESCENDANTS.",
            "When a question asks 'what is X a type of' or 'what category does X belong to', use BON_GET_ANCESTORS.",
            "Inferred edges show pre-computed transitive and chain relationships — use them for multi-hop queries.",
            "Constraints document OWL restrictions — respect disjointness (never mix disjoint concepts) and cardinality (expected counts)."
        ]
    }
    
    return json.dumps(context)
$$;
```

#### SP_BON_VALIDATE

```sql
CREATE OR REPLACE PROCEDURE SP_BON_VALIDATE(DOMAIN_FILTER VARCHAR DEFAULT NULL)
RETURNS TABLE (NODE_NAME VARCHAR, CONSTRAINT_KIND VARCHAR, VIOLATION_DETAIL VARCHAR)
LANGUAGE SQL
AS
$$
-- Check cardinality constraints
SELECT 
    c.NODE_NAME,
    c.CONSTRAINT_KIND,
    'Cardinality violation: ' || c.PROPERTY_NAME || ' expected ' || c.CONSTRAINT_EXPR ||
    ' but found ' || CAST(actual.cnt AS VARCHAR) || ' edges' AS VIOLATION_DETAIL
FROM BON_CONSTRAINT c
JOIN (
    SELECT SOURCE_NAME, REL_LABEL, COUNT(*) AS cnt
    FROM BON_GRAPH_EDGES
    GROUP BY SOURCE_NAME, REL_LABEL
) actual ON c.NODE_NAME = actual.SOURCE_NAME AND c.PROPERTY_NAME = actual.REL_LABEL
WHERE c.CONSTRAINT_KIND = 'CARDINALITY'
AND (
    (c.CONSTRAINT_EXPR LIKE 'exactly%' AND actual.cnt != CAST(REGEXP_SUBSTR(c.CONSTRAINT_EXPR, '\\d+') AS NUMBER))
    OR (c.CONSTRAINT_EXPR LIKE 'min%' AND actual.cnt < CAST(REGEXP_SUBSTR(c.CONSTRAINT_EXPR, '\\d+') AS NUMBER))
    OR (c.CONSTRAINT_EXPR LIKE 'max%' AND actual.cnt > CAST(REGEXP_SUBSTR(c.CONSTRAINT_EXPR, '\\d+') AS NUMBER))
)

UNION ALL

-- Check disjointness constraints
SELECT
    c.NODE_NAME,
    c.CONSTRAINT_KIND,
    'Disjoint violation: ' || c.NODE_NAME || ' shares instances with ' || 
    REGEXP_SUBSTR(c.CONSTRAINT_EXPR, 'disjoint with (.+)', 1, 1, 'e', 1) AS VIOLATION_DETAIL
FROM BON_CONSTRAINT c
WHERE c.CONSTRAINT_KIND = 'DISJOINT'
AND EXISTS (
    SELECT 1 FROM BON_GRAPH_EDGES e1
    JOIN BON_GRAPH_EDGES e2 ON e1.TARGET_ID = e2.TARGET_ID
    WHERE e1.SOURCE_NAME = c.NODE_NAME
    AND e2.SOURCE_NAME = REGEXP_SUBSTR(c.CONSTRAINT_EXPR, 'disjoint with (.+)', 1, 1, 'e', 1)
    AND e1.REL_TYPE IN ('HAS_PART', 'HAS_VARIANT', 'CLASSIFIES')
    AND e2.REL_TYPE IN ('HAS_PART', 'HAS_VARIANT', 'CLASSIFIES')
)
$$;
```

---

## 3. OWL-to-BON Mapping Rules

### 3.1 Tier 1: Clean Structural Mappings

| OWL Construct | BON Target | Mapping Logic |
|---|---|---|
| `owl:Class` | ENTITY node | `rdfs:label` or URI fragment → name; `rdfs:comment` → description |
| `skos:Concept` | DIMENSION_CONCEPT node | SKOS concepts are categorical by nature |
| `owl:NamedIndividual` | TERM node | Instance; class membership noted in description |
| `owl:ObjectProperty` (domain/range) | Relationship edge | Heuristic maps property name to BON type; CUSTOM fallback |
| `owl:DatatypeProperty` | TERM node (decoder) | Property name + range datatype in description |
| `owl:equivalentClass` | EQUIVALENT_TO relationship | Direct match |
| `rdfs:subClassOf` | HAS_PART or CUSTOM("subclass of") | Structural component vs taxonomic subtype |
| `skos:broader`/`narrower` | CLASSIFIES or HAS_VARIANT | Hierarchy direction mapping |
| `skos:prefLabel`/`altLabel` | name / synonyms | Direct match |
| `skos:ConceptScheme` | Domain | Each scheme = one BON domain |
| `owl:inverseOf` | Two relationships (both directions) | Create forward + reverse |

### 3.2 Tier 2: Annotations + Reasoning Tables

| OWL Construct | Description Annotation | Reasoning Table | Pre-compute or Runtime |
|---|---|---|---|
| `owl:TransitiveProperty` | `[OWL: transitive]` | BON_RULE → BON_INFERRED | Pre-compute |
| `owl:SymmetricProperty` | `[OWL: symmetric]` | BON_RULE → BON_INFERRED | Pre-compute |
| `owl:FunctionalProperty` | `[OWL: functional — max 1]` | BON_CONSTRAINT | Runtime (validate) |
| `owl:disjointWith` | `[OWL: disjoint with X]` | BON_CONSTRAINT | Runtime (validate + agent hint) |
| Cardinality (min/max/exact) | `[OWL: cardinality — exactly N]` | BON_CONSTRAINT | Runtime (validate) |
| Restrictions (someValues) | `[OWL: restriction — P someValuesFrom C]` | BON_CONSTRAINT; if --run-reasoner: BON_INFERRED | Pre-compute (with reasoner) |
| Property chains | `[OWL: chain — R1 o R2 → R3]` | BON_RULE → BON_INFERRED | Pre-compute |
| SHACL shapes | `[OWL: validation — requires X]` | BON_CONSTRAINT | Runtime (validate) |
| SWRL rules | `[OWL: rule — IF...THEN...]` | BON_RULE → BON_INFERRED | Pre-compute |

### 3.3 Tier 3: Dropped (with warnings)

| OWL Construct | Reason | Mitigation |
|---|---|---|
| Anonymous classes (unionOf, intersectionOf) | Set algebra; no SQL equivalent | Warning; --run-reasoner resolves them before import |
| Blank nodes | RDF implementation artifacts | Silent skip |
| OWL Full meta-modeling | BON type system is flat | Warning if detected |
| `owl:imports` | Resolved by rdflib before parsing | Noted in stats |
| RDF reification / named graphs | Metadata about metadata | Silent skip |

---

## 4. Industry Ontology Support Matrix

| Ontology | Scale | Import | Pre-compute | Runtime Reasoning | Limitations |
|---|---|---|---|---|---|
| Enterprise ontology (< 1K) | Small | Full | Full | Full | None |
| Schema.org (800 classes) | Small | Full | Minimal needed | Full | None |
| FIBO subset (~500 classes) | Medium | Full | Property chains + transitive | Full | Complex nested restrictions approximate without --run-reasoner |
| FIBO complete (1,500 classes) | Medium | Full | Full | Full | Some restriction reasoning needs --run-reasoner |
| GS1 branch (~2K categories) | Medium | With --namespace-filter | Transitive closure | UDF expansion | Full 35K needs reference table approach |
| GO branch (~4K terms) | Medium | With --namespace-filter | Transitive part_of | Full (DAG-aware) | Full 45K needs subsetting |
| SNOMED subdomain (~5K) | Medium | With --namespace-filter | Transitive is-a | Within subset | Role-based reasoning partial; full 350K out of scope |

---

## 5. Cortex Sense Migration Path

The `$bon-reasoning` skill creates standard Snowflake objects:
- SQL UDFs (`CREATE FUNCTION ... LANGUAGE SQL`)
- Python SPs (`CREATE PROCEDURE ... LANGUAGE PYTHON`)
- Standard tables (`CREATE TABLE`)

When Cortex Sense adds managed ontology runtime:
1. Sense registers the same UDF signatures as managed tools
2. Sense manages BON_GRAPH sync (replacing manual SP_BON_SYNC)
3. Sense manages BON_INFERRED lifecycle (replacing manual SP_BON_PRECOMPUTE)
4. The agent's tool interface remains unchanged — same function names, same signatures
5. `$bon-reasoning deploy` becomes unnecessary — Sense handles it automatically

No proprietary runtime, no external dependencies, no migration barrier.

---

## 6. Security Considerations

- All tables inherit the schema's RBAC — no additional privilege model
- SP_BON_SYNC reads from SYSTEM$GET_GLOSSARY_GRAPH() which requires BON read access
- UDFs read only from BON_GRAPH/BON_INFERRED/BON_CONSTRAINT — no direct glossary mutation
- SP_BON_PRECOMPUTE writes only to BON_INFERRED — never to the glossary
- --run-reasoner executes owlready2 locally (in the CoCo session) — no server-side execution of external reasoners

---

## 7. Testing Strategy

| Test Category | Test | Expected Result |
|---|---|---|
| **Parser** | Parse upstream.ttl (3 classes, 2 properties, 1 chain, 1 disjoint) | 3 ENTITY candidates, 2 HAS_PART relationships, owl_reasoning.json with 1 chain + 1 disjoint |
| **Parser** | Parse FIBO fragment (Bond + Security + Issuer, restrictions) | 3 entities, cardinality constraint, restriction constraint |
| **Parser** | Parse each supported format (.owl, .ttl, .rdf, .jsonld, .nt, .csv, .yaml, .graphml) | Valid candidates.json for each |
| **Parser** | Parse with --namespace-filter on Gene Ontology subset | Only classes from filtered namespace |
| **Pre-compute** | SP_BON_PRECOMPUTE on Field/Reservoir/Well with transitive hasReservoir | BON_INFERRED contains Field→Well edge |
| **Pre-compute** | SP_BON_PRECOMPUTE with property chain hasReservoir o hasWell | BON_INFERRED contains composed edge |
| **Pre-compute** | SP_BON_PRECOMPUTE with inverse rule | BON_INFERRED contains reverse edges |
| **Runtime** | BON_EXPAND_DESCENDANTS('Field') | Returns Field, Reservoir, Well with depths 0, 1, 2 |
| **Runtime** | BON_GET_ANCESTORS('Well') | Returns Reservoir (depth 1), Field (depth 2) |
| **Runtime** | BON_GET_PATH('Well', 'Field') | Returns Well → Reservoir → Field |
| **Runtime** | SP_BON_VALIDATE with cardinality violation | Reports violation detail |
| **Integration** | Full pipeline: parse upstream.ttl → batch_import → deploy_precompute → deploy UDFs → agent query | Agent correctly answers "Which wells belong to Field_A?" |
| **Scale** | Parse Schema.org (800 classes) end-to-end | Completes in < 60s, all UDFs return correct results |
| **Data Product** | Publish FIBO as listing, install in consumer account, agent queries across industry + custom | Agent correctly uses shared FIBO UDFs alongside custom BON context |

---

## 8. Related Feature: Industry Ontology Data Products

The OWL import + reasoning pipeline designed in this document is the foundation for a second feature: **pre-built industry ontology Marketplace listings**. That feature uses this pipeline to ingest industry-standard OWL files (FIBO, GS1, SNOMED subsets, etc.), package the results as Snowflake data products, and publish them so customers can install and extend with custom enterprise ontologies.

See the separate PRD: [PRD-industry-ontology-data-products.md](PRD-industry-ontology-data-products.md)

The key architectural insight: the same `parse_ontology_file.py` + `deploy_precompute.py` + `deploy_udfs.py` pipeline that a customer runs for their own OWL file is what a provider runs to produce a Marketplace listing. The listing is just the output of this pipeline packaged as a Snowflake share.

See the separate PRD: [PRD-industry-ontology-data-products.md](PRD-industry-ontology-data-products.md)
