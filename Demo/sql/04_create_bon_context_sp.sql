-- =====================================================
-- Business Ontology Context Stored Procedure
-- Dynamically retrieves all ontology terms from the
-- glossary via SYSTEM$GET_GLOSSARY_TERM() at runtime.
-- =====================================================
USE DATABASE DB_ONTOLOGY_CONTROL_PLANE;
USE SCHEMA SAP_PRODUCTION;
USE WAREHOUSE ONTOLOGY_WH;

CREATE OR REPLACE PROCEDURE "SP_GET_SAP_BON_CONTEXT"()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS CALLER
AS $$
def run(session):
    import json

    # ---------------------------------------------------------------
    # Known term IDs (discovered from glossary)
    # The SP retrieves each term LIVE from the glossary at runtime.
    # To add new terms: create them via the business-ontology skill,
    # then add their IDs to this list.
    # ---------------------------------------------------------------
    TERM_IDS = [
        '32015320777', '32015320837', '32015320841', '32015320845',
        '32015320901', '32015320965', '32015320969', '32015321029',
        '32015321093', '32015321097', '32015321101', '32015321157',
        '32015321161', '32015321165', '32015321221', '32015321285',
        '32015321289', '32015321349', '32015321353', '32015321413',
        '32015321417', '32015321477', '32015321481', '32015321541',
        '32015321545', '32015321549', '32015321553', '32015321605',
        '32015321669'
    ]

    # Step 1: Retrieve each term from the glossary via SYSTEM$ API
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

    # Step 3: Build context in 3 categories for agent inference
    lines = []
    lines.append("=== BUSINESS ONTOLOGY CONTEXT ===")
    lines.append(f"Retrieved from glossary: {len(all_terms)} terms across 3 domains")
    lines.append(f"{len(entities)} entities | {len(metrics)} formulas | {len(decoders)} decoders | {len(relationships)} relationships")

    # CATEGORY 1: CODE DECODERS
    lines.append("")
    lines.append("=" * 50)
    lines.append(f"CATEGORY 1: SAP CODE DECODERS ({len(decoders)})")
    lines.append("=" * 50)
    lines.append("Use these to interpret coded field values in SAP tables.")
    for d in sorted(decoders, key=lambda x: x['name']):
        field = d['name'].split()[0]
        lines.append(f"\n{field}: {d['description']}")

    # CATEGORY 2: AUTHORITATIVE FORMULAS
    lines.append("")
    lines.append("=" * 50)
    lines.append(f"CATEGORY 2: AUTHORITATIVE BUSINESS FORMULAS ({len(metrics)})")
    lines.append("=" * 50)
    lines.append("If a formula exists for the question, USE IT EXACTLY. Do NOT invent your own SQL.")
    for i, m in enumerate(sorted(metrics, key=lambda x: x['name']), 1):
        lines.append(f"\nFORMULA {i} - {m['name']}:")
        if m.get('formula'):
            lines.append(f"  SQL/LOGIC: {m['formula']}")
        lines.append(f"  RULE: {m['description']}")

    # CATEGORY 3: ENTITY RELATIONSHIPS
    lines.append("")
    lines.append("=" * 50)
    lines.append(f"CATEGORY 3: ENTITY RELATIONSHIPS ({len(relationships)})")
    lines.append("=" * 50)
    lines.append("Cross-domain connections. Use to trace multi-hop chains.")
    lines.append("\nENTITIES:")
    for e in sorted(entities, key=lambda x: x['domain']['name'] + x['name']):
        lines.append(f"  [{e['domain']['name']}] {e['name']}: {e['description']}")
    lines.append("\nRELATIONSHIP MAP:")
    for r in relationships:
        lines.append(f"  {r['source']} --[{r['type']}]--> {r['target']}")

    lines.append("\n=== END BUSINESS ONTOLOGY CONTEXT ===")
    return "\n".join(lines)
$$;
