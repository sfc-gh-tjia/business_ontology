-- =====================================================
-- SAP Cortex Agents: Baseline vs BON-Enhanced
-- Uses native snowscope_search with businessOntology
-- corpus for BON integration (no custom SP needed).
-- =====================================================
USE DATABASE DB_ONTOLOGY_CONTROL_PLANE;
USE SCHEMA SAP_PRODUCTION;
USE WAREHOUSE ONTOLOGY_WH;

-- =====================================================
-- BASELINE AGENT: SV-only, no business context
-- =====================================================
CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_AGENT
  COMMENT = 'Baseline SAP agent - SV only, no business ontology context'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  orchestration:
    budget:
      seconds: 60
      tokens: 16000
  instructions:
    response: "You are a supply chain analytics assistant working with SAP production data. Answer questions precisely using the data available. Always show your reasoning and any SQL queries used."
    orchestration: "Use the query_sap tool to answer all data questions."
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "query_sap"
        description: "Query SAP production procurement and logistics data including vendors, materials, purchase orders, shipments, plants, warehouses, BOM, contracts, inspections, and carriers."
  tool_resources:
    query_sap:
      semantic_view: "DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV"
      execution_environment:
        type: "warehouse"
        warehouse: "ONTOLOGY_WH"
  $$;

-- =====================================================
-- BON AGENT: Native BON search + SV data queries
-- Uses snowscope_search with businessOntology corpus.
-- No custom stored procedure needed — Snowflake's
-- built-in search index finds relevant BON terms
-- per question automatically.
--
-- Prerequisite: BON glossary must be populated with
-- approved terms (run 05_create_bon_glossary.sql first).
-- =====================================================
CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.BON_SV_NATIVE_AGENT
  COMMENT = 'BON-enhanced SAP agent using native snowscope_search with businessOntology corpus'
  PROFILE = '{"display_name": "SAP BON + Data Assistant"}'
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
      You are an enterprise analytics assistant for SAP supply chain data.
      You have two capabilities:
      1. Business Ontology search — governed definitions, formulas, decoders,
         and cross-domain relationships for SAP terms and metrics.
      2. Semantic View queries — actual data queries against SAP tables
         (Purchasing, Finance, Sales).

      When answering:
      - Show the governed formula from BON, then the query result from data.
      - If BON provides a formula, USE IT to guide your SQL generation.
      - Pay attention to sign logic (BSCHL 31=positive, 34=subtract),
        code decoders (KTOKK, MATKL, HKONT, KSCHL, OBJNR),
        and cross-domain chains (Purchasing->Finance->Sales).
      - Never invent a formula. If BON returns no formula, say so.
      - Always show your reasoning.
    orchestration: |
      CRITICAL WORKFLOW for every question:

      STEP 1: Call business_ontology FIRST to get governed definitions,
      formulas, and decoders relevant to the question.

      STEP 2: Use the BON context to understand:
      - SAP field codes and their meanings
      - Which formula applies
      - Cross-domain relationship chains

      STEP 3: Call query_sap to run the actual data query, using the
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
          Search Business Ontology for governed SAP business terms, metrics,
          entities, and decoders. Returns definitions, formulas, synonyms,
          and domain context. Call this FIRST before any data query.
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: query_sap
        description: |
          Query SAP enterprise data covering procurement (vendors, materials,
          POs, shipments, BOM, contracts, inspections, carriers), finance
          (accounting postings, cost allocations), and sales (sales orders,
          pricing conditions).

  tool_resources:
    business_ontology:
      corpus: businessOntology
    query_sap:
      semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV
      execution_environment:
        type: warehouse
        warehouse: ONTOLOGY_WH
        query_timeout: 120
  $$;

-- =====================================================
-- Verify both agents
-- =====================================================
DESCRIBE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_AGENT;
DESCRIBE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.BON_SV_NATIVE_AGENT;
