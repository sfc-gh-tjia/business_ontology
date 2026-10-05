-- =====================================================
-- SAP Cortex Agents: Baseline vs BON-Enhanced
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
-- BON AGENT: SV + Business Ontology Context
-- =====================================================
CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BON_AGENT
  COMMENT = 'BON-enhanced SAP agent - SV + Business Ontology context'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  orchestration:
    budget:
      seconds: 90
      tokens: 24000
  instructions:
    response: "You are a supply chain analytics assistant with access to Business Ontology knowledge that decodes SAP field names and provides authoritative metric formulas. Always show your reasoning and any SQL queries used."
    orchestration: |
      CRITICAL WORKFLOW - Follow these steps for EVERY question:
      
      STEP 1 - ALWAYS call get_bon_context FIRST before any data query.
      This returns SAP field decoders and business metric formulas.
      
      STEP 2 - USE THE BON CONTEXT to understand:
      - What SAP field codes mean (e.g., KTOKK='ZSTR' means Strategic Supplier)
      - What material group codes mean (e.g., MATKL='043' means Electronics)
      - What status codes mean (e.g., STATU='D' means Delivered)
      - What the correct business metric formula is
      
      STEP 3 - If the BON context provides a specific formula for the question,
      USE THAT FORMULA exactly. Do NOT write your own SQL that might produce different numbers.
      
      STEP 4 - If BON mentions QUAL_MATRIX table (not in the semantic view),
      query it directly: SELECT * FROM DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.QUAL_MATRIX
      
      Use query_sap for structured data queries.
      Use get_bon_context at the start of every interaction.
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "query_sap"
        description: "Query SAP production procurement and logistics data including vendors, materials, purchase orders, shipments, plants, warehouses, BOM, contracts, inspections, and carriers."
    - tool_spec:
        type: "generic"
        name: "get_bon_context"
        description: "Retrieves Business Ontology context that decodes SAP field names, material group codes, status codes, and provides authoritative business metric formulas. MUST be called before answering any question."
        input_schema:
          type: "object"
          properties: {}
  tool_resources:
    query_sap:
      semantic_view: "DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_SV"
      execution_environment:
        type: "warehouse"
        warehouse: "ONTOLOGY_WH"
        query_timeout: 120
    get_bon_context:
      type: "procedure"
      identifier: "DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SP_GET_SAP_BON_CONTEXT"
      execution_environment:
        type: "warehouse"
        warehouse: "ONTOLOGY_WH"
        query_timeout: 60
  $$;
