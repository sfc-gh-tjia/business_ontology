# PRD: Ontology File Import + Runtime Reasoning for Business Ontology

| Field | Value |
|---|---|
| **Author** | Tianxia Jia |
| **Status** | Draft |
| **Last Updated** | 2026-10-08 |
| **Target** | Business Ontology (BON) + Cortex Agent |
| **Skills** | `$business-ontology` (extended), `$bon-reasoning` (new) |

---

## 1. Problem Statement

Organizations maintain formal ontologies in standard formats (OWL, Turtle, RDF/XML, JSON-LD, SKOS, SHACL) to encode class hierarchies, typed relationships, constraints, and canonical identifiers. Examples include FIBO (financial instruments), GS1 (product taxonomy), SNOMED CT (clinical terminology), and custom enterprise ontologies built in Protege or TopBraid.

Today, there is no way to import these ontologies into Snowflake's Business Ontology (BON). Users must manually re-create each concept as a `$business-ontology` prompt — impractical for ontologies with hundreds or thousands of classes. Furthermore, OWL ontologies carry reasoning semantics (transitivity, property chains, disjointness, cardinality constraints) that BON's current data model cannot express or execute at query time.

### Pain Points

1. **Manual entry is impractical at scale.** An ontology with 500 classes and 200 relationships requires 700+ individual `$business-ontology` prompts.
2. **Reasoning semantics are lost.** OWL encodes that "partOf is transitive" or "Bond is disjoint from Equity." When manually recreated in BON, these semantics are either omitted or buried in free-text descriptions where the agent may or may not notice them.
3. **No round-trip with external tools.** Teams that maintain ontologies in Protege, TopBraid, or other OWL editors cannot push updates to BON without full manual re-entry.
4. **Agent cannot perform structural reasoning.** "Expand all subtypes of Electronic Component" requires recursive hierarchy traversal that the agent's LLM cannot reliably do from text descriptions alone.

---

## 2. Objective

Enable users to import ontology files in all common formats into BON, with OWL reasoning semantics preserved through a combination of:
- **Pre-computed inferences** (transitive closure, inverse edges, property chains) stored alongside BON
- **Runtime UDFs** (hierarchy traversal, ancestor lookup, path finding) available as Cortex Agent tools
- **Structured constraint storage** (cardinality, disjointness, restrictions) surfaced to the agent via an enhanced context SP

The runtime reasoning components are designed as a standalone `$bon-reasoning` skill that will eventually be absorbed by Cortex Sense as managed runtime.

---

## 3. User Personas

| Persona | Role | Need |
|---|---|---|
| **Ontology Steward** | Data governance lead who maintains the enterprise ontology | Import existing OWL/Turtle files into BON without manual re-entry; review and approve imported concepts through the existing draft/approve workflow |
| **Data Engineer** | Builds and maintains Cortex Agents | Deploy reasoning UDFs as agent tools so the agent can traverse ontology hierarchies and use pre-computed inferences at query time |
| **Business Analyst** | Asks questions via the Cortex Agent | Expects correct answers to questions like "total spend on all electronic components" (requires set expansion) or "which wells belong to Field A" (requires chain traversal) |
| **Platform Team** | Manages Cortex Sense contexts | Eventually absorbs the `$bon-reasoning` runtime into Sense's managed infrastructure |

---

## 4. Requirements

### 4.1 Functional Requirements

#### FR-1: Ontology File Parsing

| ID | Requirement | Priority |
|---|---|---|
| FR-1.1 | Parse OWL ontology files (.owl, RDF/XML serialization) | P0 |
| FR-1.2 | Parse Turtle files (.ttl) | P0 |
| FR-1.3 | Parse RDF/XML files (.rdf) | P0 |
| FR-1.4 | Parse JSON-LD files (.jsonld) | P0 |
| FR-1.5 | Parse N-Triples files (.nt) | P1 |
| FR-1.6 | Parse N-Quads files (.nq) | P2 |
| FR-1.7 | Parse TriG files (.trig) | P2 |
| FR-1.8 | Parse Notation3 files (.n3) | P2 |
| FR-1.9 | Parse YAML ontology files (.yaml, .yml) with a defined concept/relationship schema | P1 |
| FR-1.10 | Parse CSV ontology files (.csv) with columns: name, type, domain, description, formula, related_to | P1 |
| FR-1.11 | Parse GraphML files (.graphml) with nodes as concepts and edges as relationships | P2 |
| FR-1.12 | Parse JSON files (.json) — auto-detect JSON-LD (route to rdflib) vs flat concept list | P1 |
| FR-1.13 | Auto-detect format from file extension with `--format` override | P0 |
| FR-1.14 | Support `--namespace-filter` to import only concepts from a specific namespace prefix | P0 |
| FR-1.15 | Support `--max-concepts` to cap the number of imported concepts | P0 |
| FR-1.16 | Support `--exclude-deprecated` to skip owl:deprecated classes | P1 |

#### FR-2: OWL-to-BON Concept Mapping

| ID | Requirement | Priority |
|---|---|---|
| FR-2.1 | Map owl:Class to BON ENTITY nodes | P0 |
| FR-2.2 | Map skos:Concept to BON DIMENSION_CONCEPT nodes | P1 |
| FR-2.3 | Map owl:NamedIndividual to BON TERM nodes | P1 |
| FR-2.4 | Map owl:ObjectProperty (with domain/range) to BON relationships using the 10 standard types + CUSTOM | P0 |
| FR-2.5 | Map owl:DatatypeProperty to BON TERM nodes (decoders) | P1 |
| FR-2.6 | Map owl:equivalentClass to EQUIVALENT_TO relationship | P0 |
| FR-2.7 | Map rdfs:subClassOf to HAS_PART or CUSTOM relationship | P0 |
| FR-2.8 | Map skos:broader/narrower to CLASSIFIES or HAS_VARIANT relationship | P1 |
| FR-2.9 | Map skos:prefLabel to node name, skos:altLabel to synonyms | P1 |
| FR-2.10 | Map skos:ConceptScheme to BON domain | P1 |
| FR-2.11 | Map owl:inverseOf by creating both forward and reverse relationships | P0 |
| FR-2.12 | Map relationship type using name-based heuristic (contains "part" → HAS_PART, "derives" → DERIVES, etc.) with CUSTOM fallback | P0 |

#### FR-3: OWL Reasoning Extraction

| ID | Requirement | Priority |
|---|---|---|
| FR-3.1 | Extract owl:TransitiveProperty declarations | P0 |
| FR-3.2 | Extract owl:SymmetricProperty declarations | P0 |
| FR-3.3 | Extract owl:FunctionalProperty declarations | P1 |
| FR-3.4 | Extract owl:inverseOf declarations | P0 |
| FR-3.5 | Extract owl:propertyChainAxiom declarations | P0 |
| FR-3.6 | Extract owl:disjointWith constraints | P1 |
| FR-3.7 | Extract cardinality constraints (owl:cardinality, owl:minCardinality, owl:maxCardinality) | P1 |
| FR-3.8 | Extract owl:Restriction (someValuesFrom, allValuesFrom) as constraints | P1 |
| FR-3.9 | Extract SHACL shapes (sh:property, sh:minCount, sh:maxCount, sh:in) as constraints | P2 |
| FR-3.10 | Extract SWRL rules as inference rule definitions | P2 |
| FR-3.11 | Output all extracted reasoning constructs as `owl_reasoning.json` | P0 |

#### FR-4: Pre-computed Inference

| ID | Requirement | Priority |
|---|---|---|
| FR-4.1 | Materialize transitive closure for all transitive properties into BON_INFERRED table | P0 |
| FR-4.2 | Materialize inverse edges for all symmetric/inverse properties into BON_INFERRED | P0 |
| FR-4.3 | Materialize property chain compositions into BON_INFERRED | P0 |
| FR-4.4 | Store OWL constraints in BON_CONSTRAINT table | P0 |
| FR-4.5 | Store inference rule definitions in BON_RULE table | P0 |
| FR-4.6 | Provide SP_BON_SYNC to materialize BON glossary graph into queryable BON_GRAPH table | P0 |
| FR-4.7 | Provide SP_BON_PRECOMPUTE to execute all enabled inference rules | P0 |
| FR-4.8 | Optional `--run-reasoner` flag to invoke owlready2 + HermiT for complex OWL DL restriction reasoning before import | P2 |

#### FR-5: Runtime Reasoning (bon-reasoning skill)

| ID | Requirement | Priority |
|---|---|---|
| FR-5.1 | BON_EXPAND_DESCENDANTS(concept) UDF — recursive downward traversal returning all descendants with depth and path | P0 |
| FR-5.2 | BON_GET_ANCESTORS(concept) UDF — recursive upward traversal returning all ancestors with depth | P0 |
| FR-5.3 | BON_GET_PATH(start, end) UDF — shortest path between two concepts | P1 |
| FR-5.4 | BON_GET_CHILDREN(parent) UDF — direct single-hop children | P0 |
| FR-5.5 | SP_BON_CONTEXT_REASONING — enhanced dynamic SP returning governed definitions + inferred edges + constraints + tool instructions | P0 |
| FR-5.6 | SP_BON_VALIDATE — constraint validation SP checking cardinality, disjointness, referential integrity | P1 |
| FR-5.7 | All UDFs and SPs registerable as Cortex Agent tools | P0 |
| FR-5.8 | UDFs read from BON_GRAPH + BON_INFERRED (not directly from SYSTEM$ functions, which cannot be called inside UDFs) | P0 |

#### FR-6: Integration with Existing Workflows

| ID | Requirement | Priority |
|---|---|---|
| FR-6.1 | OWL import uses the existing draft/approve workflow — steward reviews extracted concepts before activation | P0 |
| FR-6.2 | OWL import runs the existing quality gate (N-01 through N-13, R-00, etc.) on imported candidates | P0 |
| FR-6.3 | OWL import triggers pre-compute step after batch_import completes | P0 |
| FR-6.4 | OWL-specific review step shows extraction summary (entities, relationships, reasoning constructs, dropped items) before steward approval | P0 |
| FR-6.5 | Domain assignment follows existing import/SKILL.md Step 0b — user declares or selects target domain | P0 |

### 4.2 Non-Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| NFR-1 | Parser should handle ontologies up to 5,000 classes within 60 seconds on a standard warehouse | P0 |
| NFR-2 | Pre-compute (transitive closure) should complete within 120 seconds for graphs up to 10,000 edges | P0 |
| NFR-3 | Runtime UDFs should return results within 5 seconds for hierarchies up to 15 levels deep | P0 |
| NFR-4 | SP_BON_CONTEXT_REASONING should return within 10 seconds including inferred edges | P0 |
| NFR-5 | bon-reasoning skill should be deployable and removable independently of business-ontology skill | P1 |
| NFR-6 | All reasoning tables (BON_GRAPH, BON_INFERRED, etc.) should be creatable in any user-specified schema | P0 |
| NFR-7 | No external services or network calls required at runtime — all reasoning is SQL-native | P0 |

---

## 5. Scope

### In Scope

- Parsing all common ontology file formats (OWL, Turtle, RDF/XML, JSON-LD, N-Triples, N-Quads, TriG, N3, YAML, CSV, GraphML, JSON)
- Mapping OWL constructs to BON glossary objects (nodes, relationships, associations)
- Extracting OWL reasoning constructs and storing them in reasoning tables
- Pre-computing inferences (transitive closure, inverse, property chains)
- Runtime traversal UDFs as Cortex Agent tools
- Enhanced context SP with reasoning awareness
- Constraint storage and validation
- Integration with existing business-ontology import workflow

### Out of Scope

- Full-scale import of ontologies exceeding ~5,000 concepts (reference data, not governance)
- Runtime OWL DL reasoning (on-the-fly classification at query time)
- SHACL validation as SQL CHECK constraints (stored as metadata only)
- Automatic Cortex Sense integration (skill is designed for absorption, but integration is future work)
- Ontology editing/authoring in OWL format (export from BON to OWL)
- Visual ontology graph explorer UI

---

## 6. Success Metrics

| Metric | Target | How measured |
|---|---|---|
| Format coverage | 12+ file types parseable | Unit tests per format |
| Import speed | < 60s for 1,000-class ontology | Timed test with Schema.org (800 classes) |
| Reasoning correctness | 100% on test suite | Pre-defined test ontologies with expected inference results |
| Agent query accuracy | Agent correctly uses UDFs for hierarchy/chain questions | Manual evaluation with 20 test questions requiring traversal |
| Steward satisfaction | Imported concepts pass quality gate without manual rework | Measure gate pass rate on first import attempt |

---

## 7. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Large ontology overwhelms BON governance workflow | Medium | High — 35K terms in draft queue is unusable | `--namespace-filter` and `--max-concepts` flags; documentation that BON is for governed concepts, not reference data |
| OWL restriction reasoning produces incorrect classifications | Low | Medium — wrong concept types in BON | `--run-reasoner` is optional and requires explicit opt-in; pre-compute results are reviewed by steward before approval |
| BON_GRAPH table becomes stale after glossary changes | Medium | Medium — UDFs return stale results | SP_BON_SYNC re-run instruction in import workflow; optional Snowflake TASK for scheduled sync |
| Relationship type heuristic maps OWL property to wrong BON type | Medium | Low — steward corrects during review | Heuristic is a suggestion, not final; import review step presents mapping for confirmation |
| bon-reasoning UDFs create circular traversal on cyclic graphs | Low | High — infinite recursion in UDF | Depth limit (15 levels) in all recursive CTEs; cycle detection via path tracking |

---

## 8. Timeline and Phases

### Phase 1: Core Import (Steps 1-5)
- parse_ontology_file.py with RDF-family support
- deploy_precompute.py with transitive + inverse inference
- Path O integration in import/SKILL.md
- OWL_MAPPING_RULES.md documentation

### Phase 2: Runtime Reasoning (Steps 3, 5)
- bon-reasoning skill with 4 UDFs + 2 SPs
- Agent tool registration
- SP_BON_CONTEXT_REASONING

### Phase 3: Advanced Features (Steps 1, 2)
- --run-reasoner (owlready2 + HermiT)
- Property chain pre-computation
- SWRL rule evaluation
- Non-RDF format parsers (YAML, CSV, GraphML)

### Phase 4: Documentation and Testing (Steps 6-7)
- End-to-end tests (Field/Reservoir/Well, FIBO Bond, GS1 branch)
- Getting-started guide updates
- Industry ontology support matrix

### Phase 5: Industry Ontology Data Products (separate feature)
- See [PRD-industry-ontology-data-products.md](PRD-industry-ontology-data-products.md) — uses this pipeline to publish pre-built industry ontologies on Snowflake Marketplace

---

## 9. Related Feature: Industry Ontology Data Products

The OWL import + reasoning pipeline (this feature) is the foundation for a second feature: **pre-built industry ontology Marketplace listings**. That feature uses this pipeline to ingest industry-standard OWL files (FIBO, GS1, SNOMED subsets, etc.), package the results as Snowflake data products, and publish them so customers can install and extend with custom enterprise ontologies.

See the separate PRD: [PRD-industry-ontology-data-products.md](PRD-industry-ontology-data-products.md)

The dependency is one-way: Feature 2 requires Feature 1, but Feature 1 is fully useful on its own.

---

## 10. Open Questions

| # | Question | Status |
|---|---|---|
| 1 | Should BON_GRAPH be a dynamic table (auto-refreshes) or a static table (manual SP_BON_SYNC)? | Open — dynamic table adds complexity but removes staleness risk |
| 2 | Should the bon-reasoning skill auto-detect and deploy when ontology files are imported, or require explicit `$bon-reasoning deploy`? | Open — auto-deploy is convenient; explicit deploy gives control |
| 3 | Should large reference taxonomies (GS1 full, SNOMED full) be loadable into a separate reference table that UDFs can traverse alongside BON_GRAPH? | Open — would solve the scale gap but adds complexity |
| 4 | What is the maximum BON_INFERRED table size before query performance degrades? | Needs benchmarking |
