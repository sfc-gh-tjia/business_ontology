-- =====================================================================
-- BON Demo V2 — 08: Live governance scenarios
-- These show value that a single benchmark run cannot: change management.
-- Each step that edits the ontology must wait for the BON search index refresh
-- (up to 6 hours). Check with:
--   cortex search object "<query>" --types=business-ontology
-- =====================================================================

-- ---------------------------------------------------------------------
-- S1  Change once, every agent follows
--     A steward changes the official supplier definition. No semantic view,
--     agent spec, or prompt is edited. Every BON-enabled agent follows;
--     agents without BON keep answering the old way.
-- ---------------------------------------------------------------------
-- Before: ask BON_AGENT, FINANCE_BON_AGENT, SALES_BON_AGENT "How many suppliers do we have?"  -> 14
SELECT SYSTEM$UPDATE_GLOSSARY_TERM('Procurement.Supplier Count', '{
  "description":"Official supplier count used in all reporting: strategic suppliers only, meaning vendors in account group ZSTR. Standard (ZSTD) and probationary (ZPRB) vendors are excluded under the 2027 supplier consolidation policy. Implemented by computing COUNT(DISTINCT vendor_id) where account_group = ZSTR in PURCHASING_ENRICHED_SV.",
  "formula":"COUNT(DISTINCT LIFNR) WHERE KTOKK = ZSTR",
  "exclusions":["KTOKK = ZSTD (standard)","KTOKK = ZPRB (probationary)"]}');
-- After index refresh: the three BON agents answer 4; ENRICHED_AGENT / FINANCE_AGENT / SALES_AGENT still answer 14 or 15.
-- Revert:
SELECT SYSTEM$UPDATE_GLOSSARY_TERM('Procurement.Supplier Count', '{
  "description":"Official supplier count used in all reporting: the number of active suppliers, meaning vendors in account group ZSTR (strategic) or ZSTD (standard). Probationary vendors (ZPRB) are excluded by procurement policy. Canonical implementation: FINANCE_ENRICHED_SV metric vendors.active_supplier_count. The Purchasing view metric vendor_record_count counts all vendor master records and is an operational variant, not the official count.",
  "formula":"COUNT(DISTINCT LIFNR) WHERE KTOKK IN (ZSTR, ZSTD)",
  "exclusions":["KTOKK = ZPRB (probationary)"]}');

-- ---------------------------------------------------------------------
-- S2  Drafts are never served
--     An unreviewed (DRAFT) definition is invisible to agents until a steward approves it.
-- ---------------------------------------------------------------------
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{"name":"Supplier Concentration Index","domainName":"Procurement","itemKind":"METRIC",
  "description":"DRAFT, not reviewed: share of procurement spend with the top 3 suppliers.","formula":"top-3 supplier spend / total spend"}');
-- After index refresh: BON_AGENT "What is the Supplier Concentration Index?" -> reports no governed definition.
-- cortex search object "supplier concentration index" --types=business-ontology  -> not returned
-- Approve, wait for refresh, ask again -> definition is returned:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('Procurement.Supplier Concentration Index');
-- Clean up: SELECT SYSTEM$UPDATE_GLOSSARY_TERM('Procurement.Supplier Concentration Index', '{"status":"DELETED"}');

-- ---------------------------------------------------------------------
-- S3  Semantic view rebuild: meaning survives, the broken binding is detectable
--     The Purchasing team renames a metric. The governed meaning stays put, and the
--     IMPLEMENTS binding can be checked for drift (rule A-05 stale binding).
-- ---------------------------------------------------------------------
-- 1. Inspect bindings for a canonical metric:
SELECT SYSTEM$GET_GLOSSARY_TERM_ASSETS('Procurement.BOM Cost Rollup');
-- 2. Rebuild PURCHASING_ENRICHED_SV with bom_material_cost renamed to unit_build_cost
--    (edit 04_enriched_svs.sql and re-run that CREATE).
-- 3. Detect drift: the bound sub-object no longer exists.
--    DESC SEMANTIC VIEW DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV;   -- BOM_MATERIAL_COST absent
--    Mark the binding stale and rebind (one place), instead of hunting through every agent prompt:
-- SELECT SYSTEM$UPDATE_GLOSSARY_ASSOCIATION('Procurement.BOM Cost Rollup',
--   '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"BOM","subObjectName":"BOM_MATERIAL_COST"}',
--   '{"validity":"TARGET_MISSING"}');
-- 4. Restore by re-running the original 04_enriched_svs.sql.
