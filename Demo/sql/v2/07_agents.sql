-- =====================================================================
-- BON Demo V2 — 07: Agent matrix
-- Every agent: same model (auto), same budget (150 s / 40k tokens), same
-- response text, same domain tool descriptions. The ONLY difference between
-- an arm and its "+ BON" twin is the business_ontology tool and its 2-step instruction.
--
--   Arm A  BARE_AGENT        3 BARE SVs
--   Arm B  ENRICHED_AGENT    3 ENRICHED SVs
--   Arm C  BON_AGENT         3 ENRICHED SVs + Business Ontology      (BON uplift = C - B)
--   Consistency pairs (V4: do two teams get the same answer?)
--          FINANCE_AGENT / FINANCE_BON_AGENT   Finance + Purchasing ENRICHED SVs
--          SALES_AGENT   / SALES_BON_AGENT     Sales + Purchasing ENRICHED SVs
--   Finance sees active_supplier_count (14); Sales only sees vendor_record_count (15).
--   Without BON they disagree; with BON both should answer 14.
--
-- After creating, DESCRIBE AGENT and confirm agent_spec contains
--   "EnableSnowscopeBusinessOntologySearch":true, "type":"snowscope_search", "corpus":"businessOntology"
-- (CREATE AGENT does not validate these values.)
-- BON search index refresh can take up to 6 hours after ontology edits or grants.
-- =====================================================================

CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.BARE_AGENT
  COMMENT = 'V2 benchmark arm A: 3 BARE domain semantic views, no Business Ontology'
  PROFILE = '{"display_name": "SAP Assistant (bare SVs)"}'
  FROM SPECIFICATION $$
models:
  orchestration: auto
orchestration:
  budget:
    seconds: 150
    tokens: 40000
instructions:
  response: |
    You are an enterprise analytics assistant for SAP supply chain data.
    Answer precisely. State the final answer as a clear number or list first,
    then briefly explain how it was computed and which data was used.
  orchestration: |
    Data lives in three domain tools. Each tool queries one domain only and
    cannot join to another domain, so for questions that span domains, query
    each relevant tool and combine the results yourself.
    - query_purchasing: vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials
    - query_finance: accounts payable postings, COGS, cost allocations by cost object
    - query_sales: sales orders, pricing conditions, discounts, customers
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_purchasing
      description: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_finance
      description: Finance domain data - accounts payable postings, cost of goods sold, cost allocations by cost object.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_sales
      description: Sales domain data - sales orders, pricing conditions, discounts, customers.
tool_resources:
  query_purchasing:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_BARE_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_finance:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_BARE_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_sales:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_BARE_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
$$;

CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.ENRICHED_AGENT
  COMMENT = 'V2 benchmark arm B: 3 ENRICHED domain semantic views, no Business Ontology'
  PROFILE = '{"display_name": "SAP Assistant (enriched SVs)"}'
  FROM SPECIFICATION $$
models:
  orchestration: auto
orchestration:
  budget:
    seconds: 150
    tokens: 40000
instructions:
  response: |
    You are an enterprise analytics assistant for SAP supply chain data.
    Answer precisely. State the final answer as a clear number or list first,
    then briefly explain how it was computed and which data was used.
  orchestration: |
    Data lives in three domain tools. Each tool queries one domain only and
    cannot join to another domain, so for questions that span domains, query
    each relevant tool and combine the results yourself.
    - query_purchasing: vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials
    - query_finance: accounts payable postings, COGS, cost allocations by cost object
    - query_sales: sales orders, pricing conditions, discounts, customers
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_purchasing
      description: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_finance
      description: Finance domain data - accounts payable postings, cost of goods sold, cost allocations by cost object.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_sales
      description: Sales domain data - sales orders, pricing conditions, discounts, customers.
tool_resources:
  query_purchasing:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_finance:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_sales:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
$$;

CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.BON_AGENT
  COMMENT = 'V2 benchmark arm C: 3 ENRICHED domain semantic views + native Business Ontology search'
  PROFILE = '{"display_name": "SAP Assistant (enriched SVs + Business Ontology)"}'
  FROM SPECIFICATION $$
models:
  orchestration: auto
experimental:
  EnableSnowscopeBusinessOntologySearch: true
orchestration:
  budget:
    seconds: 150
    tokens: 40000
instructions:
  response: |
    You are an enterprise analytics assistant for SAP supply chain data.
    Answer precisely. State the final answer as a clear number or list first,
    then briefly explain how it was computed and which data was used.
    When you used a governed Business Ontology definition, name the term and
    the semantic view metric that implements it.
  orchestration: |
    Data lives in three domain tools. Each tool queries one domain only and
    cannot join to another domain, so for questions that span domains, query
    each relevant tool and combine the results yourself.
    - query_purchasing: vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials
    - query_finance: accounts payable postings, COGS, cost allocations by cost object
    - query_sales: sales orders, pricing conditions, discounts, customers

    Before querying data, call business_ontology to look up the governed
    definition of each business term in the question. Prefer terms from the
    Procurement, Finance & Controlling, and Sales & Distribution domains. When
    the ontology names a canonical metric and the semantic view metric that
    implements it, use that metric rather than a similarly named variant, and
    follow any policy that applies to it. If the question only asks what
    something means, answer from the ontology without querying data.
tools:
  - tool_spec:
      type: snowscope_search
      name: business_ontology
      description: Governed business definitions - canonical metrics and their implementing semantic view metrics, scoped variants, business policies, code meanings, and how concepts relate across Procurement, Finance and Sales.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_purchasing
      description: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_finance
      description: Finance domain data - accounts payable postings, cost of goods sold, cost allocations by cost object.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_sales
      description: Sales domain data - sales orders, pricing conditions, discounts, customers.
tool_resources:
  business_ontology:
    corpus: businessOntology
  query_purchasing:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_finance:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_sales:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
$$;

-- ------------------------------------------------ Consistency pairs
CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_AGENT
  COMMENT = 'V2 consistency pair: Finance team agent (Finance + Purchasing enriched SVs), no BON'
  PROFILE = '{"display_name": "Finance Assistant"}'
  FROM SPECIFICATION $$
models:
  orchestration: auto
orchestration:
  budget:
    seconds: 150
    tokens: 40000
instructions:
  response: |
    You are an enterprise analytics assistant for SAP supply chain data.
    Answer precisely. State the final answer as a clear number or list first,
    then briefly explain how it was computed and which data was used.
  orchestration: |
    You support the Finance team. Data lives in the domain tools below. Each
    tool queries one domain only and cannot join to another domain, so for
    questions that span domains, query each relevant tool and combine the
    results yourself.
    - query_finance: Finance domain data - accounts payable postings, cost of goods sold, cost allocations by cost object.
    - query_purchasing: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_finance
      description: Finance domain data - accounts payable postings, cost of goods sold, cost allocations by cost object.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_purchasing
      description: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
tool_resources:
  query_finance:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_purchasing:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
$$;

CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_BON_AGENT
  COMMENT = 'V2 consistency pair: Finance team agent (Finance + Purchasing enriched SVs) + BON'
  PROFILE = '{"display_name": "Finance Assistant + BON"}'
  FROM SPECIFICATION $$
models:
  orchestration: auto
experimental:
  EnableSnowscopeBusinessOntologySearch: true
orchestration:
  budget:
    seconds: 150
    tokens: 40000
instructions:
  response: |
    You are an enterprise analytics assistant for SAP supply chain data.
    Answer precisely. State the final answer as a clear number or list first,
    then briefly explain how it was computed and which data was used.
    When you used a governed Business Ontology definition, name the term and
    the semantic view metric that implements it.
  orchestration: |
    You support the Finance team. Data lives in the domain tools below. Each
    tool queries one domain only and cannot join to another domain, so for
    questions that span domains, query each relevant tool and combine the
    results yourself.
    - query_finance: Finance domain data - accounts payable postings, cost of goods sold, cost allocations by cost object.
    - query_purchasing: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
    Before querying data, call business_ontology to look up the governed
    definition of each business term in the question. Prefer terms from the
    Procurement, Finance & Controlling, and Sales & Distribution domains. When
    the ontology names a canonical metric and the semantic view metric that
    implements it, use that metric rather than a similarly named variant, and
    follow any policy that applies to it. If the ontology names a semantic view
    metric this agent does not have, compute the same definition with the
    tools available. If the question only asks what something means, answer
    from the ontology without querying data.
tools:
  - tool_spec:
      type: snowscope_search
      name: business_ontology
      description: Governed business definitions - canonical metrics and their implementing semantic view metrics, scoped variants, business policies, code meanings, and how concepts relate across Procurement, Finance and Sales.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_finance
      description: Finance domain data - accounts payable postings, cost of goods sold, cost allocations by cost object.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_purchasing
      description: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
tool_resources:
  business_ontology:
    corpus: businessOntology
  query_finance:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_purchasing:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
$$;

CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_AGENT
  COMMENT = 'V2 consistency pair: Sales team agent (Sales + Purchasing enriched SVs), no BON'
  PROFILE = '{"display_name": "Sales Assistant"}'
  FROM SPECIFICATION $$
models:
  orchestration: auto
orchestration:
  budget:
    seconds: 150
    tokens: 40000
instructions:
  response: |
    You are an enterprise analytics assistant for SAP supply chain data.
    Answer precisely. State the final answer as a clear number or list first,
    then briefly explain how it was computed and which data was used.
  orchestration: |
    You support the Sales team. Data lives in the domain tools below. Each
    tool queries one domain only and cannot join to another domain, so for
    questions that span domains, query each relevant tool and combine the
    results yourself.
    - query_sales: Sales domain data - sales orders, pricing conditions, discounts, customers.
    - query_purchasing: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_sales
      description: Sales domain data - sales orders, pricing conditions, discounts, customers.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_purchasing
      description: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
tool_resources:
  query_sales:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_purchasing:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
$$;

CREATE OR REPLACE AGENT DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_BON_AGENT
  COMMENT = 'V2 consistency pair: Sales team agent (Sales + Purchasing enriched SVs) + BON'
  PROFILE = '{"display_name": "Sales Assistant + BON"}'
  FROM SPECIFICATION $$
models:
  orchestration: auto
experimental:
  EnableSnowscopeBusinessOntologySearch: true
orchestration:
  budget:
    seconds: 150
    tokens: 40000
instructions:
  response: |
    You are an enterprise analytics assistant for SAP supply chain data.
    Answer precisely. State the final answer as a clear number or list first,
    then briefly explain how it was computed and which data was used.
    When you used a governed Business Ontology definition, name the term and
    the semantic view metric that implements it.
  orchestration: |
    You support the Sales team. Data lives in the domain tools below. Each
    tool queries one domain only and cannot join to another domain, so for
    questions that span domains, query each relevant tool and combine the
    results yourself.
    - query_sales: Sales domain data - sales orders, pricing conditions, discounts, customers.
    - query_purchasing: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
    Before querying data, call business_ontology to look up the governed
    definition of each business term in the question. Prefer terms from the
    Procurement, Finance & Controlling, and Sales & Distribution domains. When
    the ontology names a canonical metric and the semantic view metric that
    implements it, use that metric rather than a similarly named variant, and
    follow any policy that applies to it. If the ontology names a semantic view
    metric this agent does not have, compute the same definition with the
    tools available. If the question only asks what something means, answer
    from the ontology without querying data.
tools:
  - tool_spec:
      type: snowscope_search
      name: business_ontology
      description: Governed business definitions - canonical metrics and their implementing semantic view metrics, scoped variants, business policies, code meanings, and how concepts relate across Procurement, Finance and Sales.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_sales
      description: Sales domain data - sales orders, pricing conditions, discounts, customers.
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: query_purchasing
      description: Procurement domain data - vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.
tool_resources:
  business_ontology:
    corpus: businessOntology
  query_sales:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
  query_purchasing:
    semantic_view: DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV
    execution_environment: {type: warehouse, warehouse: ONTOLOGY_WH, query_timeout: 120}
$$;
